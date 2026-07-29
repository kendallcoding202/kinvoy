import CoreLocation
import Foundation
import Supabase

/// Publishes this device's location to the family group — but only while the
/// user has sharing turned on AND today falls inside the trip's date range.
/// Turning sharing off (or the trip ending) deletes the location row entirely.
@MainActor
final class LocationService: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var isSharing = false
    /// Always-on family sharing — no date window, opt-in, off by default.
    @Published var isFamilySharing = false
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var lastError: String?

    private let manager = CLLocationManager()
    private var trip: Trip?
    private var memberId: UUID?
    private var familyId: UUID?
    private var familyMemberId: UUID?
    private var isDemo = false
    private var lastUpload: Date = .distantPast
    private var lastFamilyUpload: Date = .distantPast
    private let familySharingKey = "familySharingEnabled"

    private var client: SupabaseClient { SupabaseService.shared.client }

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = 30
        authorizationStatus = manager.authorizationStatus
    }

    func configure(trip: Trip, memberId: UUID, isDemo: Bool) {
        self.trip = trip
        self.memberId = memberId
        self.isDemo = isDemo
    }

    /// Called once the family group is known; restores the always-on toggle.
    func configureFamily(familyId: UUID, familyMemberId: UUID) {
        self.familyId = familyId
        self.familyMemberId = familyMemberId
        if UserDefaults.standard.bool(forKey: familySharingKey), !isFamilySharing {
            setFamilySharing(true)
        }
    }

    func setFamilySharing(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: familySharingKey)
        guard enabled else {
            isFamilySharing = false
            stopManagerIfIdle()
            guard !isDemo, let familyMemberId else { return }
            Task {
                _ = try? await client.from("family_locations").delete()
                    .eq("member_id", value: familyMemberId.uuidString)
                    .execute()
            }
            return
        }
        if isDemo {
            isFamilySharing = true
            return
        }
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
            isFamilySharing = true
        case .authorizedWhenInUse, .authorizedAlways:
            isFamilySharing = true
            manager.startUpdatingLocation()
        default:
            lastError = "Location permission is denied. Enable it in Settings to share your location."
            isFamilySharing = false
        }
    }

    private func stopManagerIfIdle() {
        if !isSharing && !isFamilySharing {
            manager.stopUpdatingLocation()
        }
    }

    var tripIsActive: Bool {
        trip?.isActiveToday ?? false
    }

    func setSharing(_ enabled: Bool) {
        guard enabled else {
            stopSharing()
            return
        }
        guard tripIsActive else {
            lastError = "Location sharing only works during the trip dates."
            isSharing = false
            return
        }
        if isDemo {
            isSharing = true
            return
        }
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
            // resumes in locationManagerDidChangeAuthorization
            isSharing = true
        case .authorizedWhenInUse, .authorizedAlways:
            isSharing = true
            manager.startUpdatingLocation()
        default:
            lastError = "Location permission is denied. Enable it in Settings to share your location."
            isSharing = false
        }
    }

    private func stopSharing() {
        isSharing = false
        stopManagerIfIdle()
        guard !isDemo, let memberId else { return }
        Task {
            _ = try? await client.from("locations").delete()
                .eq("member_id", value: memberId.uuidString)
                .execute()
        }
    }

    /// Called on app foreground and periodically: auto-stop once the trip ends.
    func enforceTripWindow() {
        if isSharing && !tripIsActive {
            stopSharing()
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.authorizationStatus = status
            if (self.isSharing || self.isFamilySharing), status == .authorizedWhenInUse || status == .authorizedAlways {
                manager.startUpdatingLocation()
            } else if status == .denied || status == .restricted {
                self.isSharing = false
                self.isFamilySharing = false
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last else { return }
        Task { @MainActor in
            await self.upload(latest)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Transient CoreLocation errors are common; ignore.
    }

    private func upload(_ location: CLLocation) async {
        await uploadFamily(location)
        guard isSharing, tripIsActive, !isDemo,
              let memberId, let trip,
              Date.now.timeIntervalSince(lastUpload) > 15 else { return }
        lastUpload = .now
        struct LocationUpsert: Encodable {
            let member_id: String
            let trip_id: String
            let latitude: Double
            let longitude: Double
            let updated_at: String
        }
        let row = LocationUpsert(
            member_id: memberId.uuidString,
            trip_id: trip.id.uuidString,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            updated_at: ISO8601DateFormatter().string(from: .now)
        )
        do {
            _ = try await client.from("locations")
                .upsert(row, onConflict: "member_id")
                .execute()
        } catch {
            print("Location upload failed: \(error)")
        }
    }

    private func uploadFamily(_ location: CLLocation) async {
        guard isFamilySharing, !isDemo,
              let familyId, let familyMemberId,
              Date.now.timeIntervalSince(lastFamilyUpload) > 15 else { return }
        lastFamilyUpload = .now
        struct FamilyLocationUpsert: Encodable {
            let member_id: String
            let family_id: String
            let latitude: Double
            let longitude: Double
            let updated_at: String
        }
        let row = FamilyLocationUpsert(
            member_id: familyMemberId.uuidString,
            family_id: familyId.uuidString,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            updated_at: ISO8601DateFormatter().string(from: .now)
        )
        do {
            _ = try await client.from("family_locations")
                .upsert(row, onConflict: "member_id")
                .execute()
        } catch {
            print("Family location upload failed: \(error)")
        }
    }
}
