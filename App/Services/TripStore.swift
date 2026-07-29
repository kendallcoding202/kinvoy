import Foundation
import Supabase
import SwiftUI

/// App-wide state: the current trip, its members, and create/join/leave flows.
@MainActor
final class TripStore: ObservableObject {
    @Published var trip: Trip?
    @Published var members: [Member] = []
    @Published var currentMember: Member?
    @Published var myTrips: [Trip] = []
    @Published var isLoading = true
    @Published var isDemo = false
    /// Invite code arriving via a kinvoy://join/CODE deep link.
    @Published var pendingJoinCode: JoinCode?

    struct JoinCode: Identifiable, Equatable {
        let code: String
        var id: String { code }
    }

    private let tripIdKey = "currentTripId"
    private var client: SupabaseClient { SupabaseService.shared.client }

    /// Decoded shape of the create_trip / join_trip RPC results.
    private struct TripBundle: Decodable {
        let trip: Trip
        let member: Member
    }

    func bootstrap() async {
        defer { isLoading = false }
        guard AppConfig.isConfigured else { return }
        do {
            try await SupabaseService.shared.ensureSignedIn()
            if let idString = UserDefaults.standard.string(forKey: tripIdKey),
               let id = UUID(uuidString: idString) {
                try await loadTrip(id: id)
            } else {
                // No remembered trip (fresh install/device) — rejoin the most recent one.
                await refreshMyTrips()
                if let recent = myTrips.first {
                    try await loadTrip(id: recent.id)
                }
            }
        } catch {
            // Stale trip reference or offline start — land on the welcome screen.
            print("Bootstrap failed: \(error)")
        }
    }

    func createTrip(name: String, destination: String, startsOn: Date, endsOn: Date, displayName: String, kind: TripKind = .vacation) async throws {
        try await SupabaseService.shared.ensureSignedIn()
        let params: [String: String] = [
            "p_name": name,
            "p_destination": destination,
            "p_starts_on": Trip.dayFormatter.string(from: startsOn),
            "p_ends_on": Trip.dayFormatter.string(from: endsOn),
            "p_display_name": displayName,
            "p_kind": kind.rawValue,
        ]
        let bundle: TripBundle = try await client
            .rpc("create_trip", params: params)
            .execute().value
        adopt(bundle)
    }

    func joinTrip(code: String, displayName: String) async throws {
        try await SupabaseService.shared.ensureSignedIn()
        let params: [String: String] = [
            "p_code": code.trimmingCharacters(in: .whitespaces).uppercased(),
            "p_display_name": displayName,
        ]
        let bundle: TripBundle = try await client
            .rpc("join_trip", params: params)
            .execute().value
        adopt(bundle)
    }

    private func adopt(_ bundle: TripBundle) {
        trip = bundle.trip
        currentMember = bundle.member
        UserDefaults.standard.set(bundle.trip.id.uuidString, forKey: tripIdKey)
        Task {
            await refreshMembers()
            await refreshMyTrips()
        }
    }

    /// All trips this user belongs to (row-level security already scopes the query).
    func refreshMyTrips() async {
        guard !isDemo else {
            myTrips = [DemoData.trip]
            return
        }
        do {
            let trips: [Trip] = try await client.from("trips").select().execute().value
            myTrips = trips.sorted { $0.startsOn > $1.startsOn }
        } catch {
            print("My trips refresh failed: \(error)")
        }
    }

    func switchTrip(to newTrip: Trip) async {
        guard newTrip.id != trip?.id, !isDemo else { return }
        do {
            try await loadTrip(id: newTrip.id)
        } catch {
            print("Trip switch failed: \(error)")
        }
    }

    func handleDeepLink(_ url: URL) {
        // kinvoy://join/ABC123
        guard url.scheme == "kinvoy" else { return }
        let code: String?
        if url.host()?.lowercased() == "join" {
            code = url.pathComponents.count > 1 ? url.pathComponents[1] : nil
        } else {
            code = nil
        }
        if let code, code.count == 6 {
            pendingJoinCode = JoinCode(code: code.uppercased())
        }
    }

    func loadTrip(id: UUID) async throws {
        let trip: Trip = try await client
            .from("trips").select()
            .eq("id", value: id.uuidString)
            .single()
            .execute().value
        self.trip = trip
        UserDefaults.standard.set(trip.id.uuidString, forKey: tripIdKey)
        await refreshMembers()
        currentMember = members.first { $0.userId == SupabaseService.shared.userId }
        await refreshMyTrips()
    }

    func refreshMembers() async {
        guard let trip else { return }
        if isDemo { return }
        do {
            members = try await client
                .from("members").select()
                .eq("trip_id", value: trip.id.uuidString)
                .order("joined_at")
                .execute().value
        } catch {
            print("Member refresh failed: \(error)")
        }
    }

    func leaveTrip() async {
        if isDemo {
            isDemo = false
            trip = nil
            members = []
            currentMember = nil
            return
        }
        if let member = currentMember {
            _ = try? await client.from("members").delete().eq("id", value: member.id.uuidString).execute()
        }
        UserDefaults.standard.removeObject(forKey: tripIdKey)
        let leftTripId = trip?.id
        trip = nil
        members = []
        currentMember = nil
        // Fall back to another trip the user still belongs to, if any.
        await refreshMyTrips()
        myTrips.removeAll { $0.id == leftTripId }
        if let next = myTrips.first {
            try? await loadTrip(id: next.id)
        }
    }

    func member(for id: UUID) -> Member? {
        members.first { $0.id == id }
    }

    func enterDemo() {
        isDemo = true
        trip = DemoData.trip
        members = DemoData.members
        currentMember = DemoData.members[0]
    }
}
