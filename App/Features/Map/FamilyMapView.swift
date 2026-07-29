import MapKit
import Supabase
import SwiftUI

@MainActor
final class FamilyMapViewModel: ObservableObject {
    @Published var locations: [MemberLocation] = []

    private var client: SupabaseClient { SupabaseService.shared.client }
    private var pollTask: Task<Void, Never>?

    private var activeTripId: UUID?

    func start(trip: Trip, isDemo: Bool) {
        if activeTripId != trip.id {
            stop()
            locations = []
        }
        activeTripId = trip.id
        guard pollTask == nil else { return }
        if isDemo {
            locations = DemoData.locations
            return
        }
        pollTask = Task {
            while !Task.isCancelled {
                await refresh(tripId: trip.id)
                try? await Task.sleep(for: .seconds(15))
            }
        }
    }

    func stop() {
        pollTask?.cancel()
        pollTask = nil
    }

    func refresh(tripId: UUID) async {
        do {
            locations = try await client
                .from("locations").select()
                .eq("trip_id", value: tripId.uuidString)
                .execute().value
        } catch {
            print("Locations refresh failed: \(error)")
        }
    }
}

struct TripMapView: View {
    @EnvironmentObject private var store: TripStore
    @EnvironmentObject private var locationService: LocationService
    @StateObject private var viewModel = FamilyMapViewModel()
    @State private var cameraPosition: MapCameraPosition = .automatic

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                map
                sharePanel
                    .padding()
            }
            .navigationTitle("Trip Map")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if let trip = store.trip {
                    viewModel.start(trip: trip, isDemo: store.isDemo)
                    locationService.enforceTripWindow()
                }
            }
            .onDisappear { viewModel.stop() }
        }
    }

    private var map: some View {
        Map(position: $cameraPosition) {
            ForEach(viewModel.locations) { location in
                Annotation(
                    store.member(for: location.memberId)?.displayName ?? "Family",
                    coordinate: CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)
                ) {
                    MemberPin(
                        name: store.member(for: location.memberId)?.displayName ?? "?",
                        isStale: Date.now.timeIntervalSince(location.updatedAt) > 600
                    )
                }
            }
            UserAnnotation()
        }
        .mapControls {
            MapUserLocationButton()
            MapCompass()
        }
    }

    private var sharePanel: some View {
        VStack(spacing: 8) {
            Toggle(isOn: Binding(
                get: { locationService.isSharing },
                set: { locationService.setSharing($0) }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Share my location on this trip")
                        .font(.subheadline.weight(.semibold))
                    Text(shareCaption)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .disabled(!locationService.tripIsActive && !locationService.isSharing)

            if let error = locationService.lastError {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var shareCaption: String {
        if locationService.tripIsActive {
            return "Visible to your family only, and only until the trip ends."
        } else if let trip = store.trip, Calendar.current.startOfDay(for: .now) < Calendar.current.startOfDay(for: trip.startDate) {
            return "Sharing unlocks when the trip starts on \(trip.startDate.formatted(.dateTime.month().day()))."
        } else {
            return "The trip has ended — location sharing is off for everyone."
        }
    }
}

struct MemberPin: View {
    let name: String
    let isStale: Bool

    var body: some View {
        VStack(spacing: 0) {
            Text(String(name.prefix(1)).uppercased())
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(isStale ? Color.gray : Color.accentColor, in: Circle())
                .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                .shadow(radius: 2)
            Triangle()
                .fill(isStale ? Color.gray : Color.accentColor)
                .frame(width: 12, height: 8)
        }
        .opacity(isStale ? 0.7 : 1)
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}
