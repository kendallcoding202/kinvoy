import Foundation
import Supabase
import SwiftUI

/// App-wide state: the current trip, its members, and create/join/leave flows.
@MainActor
final class TripStore: ObservableObject {
    @Published var trip: Trip?
    @Published var members: [Member] = []
    @Published var currentMember: Member?
    @Published var isLoading = true
    @Published var isDemo = false

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
        Task { await refreshMembers() }
    }

    func loadTrip(id: UUID) async throws {
        let trip: Trip = try await client
            .from("trips").select()
            .eq("id", value: id.uuidString)
            .single()
            .execute().value
        self.trip = trip
        await refreshMembers()
        currentMember = members.first { $0.userId == SupabaseService.shared.userId }
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
        trip = nil
        members = []
        currentMember = nil
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
