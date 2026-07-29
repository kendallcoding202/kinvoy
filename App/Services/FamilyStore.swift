import Foundation
import Supabase
import SwiftUI

/// The persistent family group that lives above trips: standing chat,
/// shared calendar, and always-on opt-in location.
@MainActor
final class FamilyStore: ObservableObject {
    @Published var family: Family?
    @Published var members: [FamilyMember] = []
    @Published var currentMember: FamilyMember?
    @Published var isDemo = false

    private let familyIdKey = "currentFamilyId"
    private var client: SupabaseClient { SupabaseService.shared.client }

    private struct FamilyBundle: Decodable {
        let family: Family
        let member: FamilyMember
    }

    func bootstrap() async {
        guard AppConfig.isConfigured else { return }
        do {
            // Restore by remembered id, else rejoin the family this user belongs to.
            if let idString = UserDefaults.standard.string(forKey: familyIdKey),
               let id = UUID(uuidString: idString) {
                try await loadFamily(id: id)
            } else {
                let families: [Family] = try await client.from("families").select().execute().value
                if let first = families.first {
                    try await loadFamily(id: first.id)
                }
            }
        } catch {
            print("Family bootstrap failed: \(error)")
        }
    }

    func createFamily(name: String, displayName: String) async throws {
        try await SupabaseService.shared.ensureSignedIn()
        let bundle: FamilyBundle = try await client
            .rpc("create_family", params: ["p_name": name, "p_display_name": displayName])
            .execute().value
        adopt(bundle)
    }

    func joinFamily(code: String, displayName: String) async throws {
        try await SupabaseService.shared.ensureSignedIn()
        let params = [
            "p_code": code.trimmingCharacters(in: .whitespaces).uppercased(),
            "p_display_name": displayName,
        ]
        let bundle: FamilyBundle = try await client
            .rpc("join_family", params: params)
            .execute().value
        adopt(bundle)
    }

    private func adopt(_ bundle: FamilyBundle) {
        family = bundle.family
        currentMember = bundle.member
        UserDefaults.standard.set(bundle.family.id.uuidString, forKey: familyIdKey)
        Task { await refreshMembers() }
    }

    func loadFamily(id: UUID) async throws {
        let family: Family = try await client
            .from("families").select()
            .eq("id", value: id.uuidString)
            .single()
            .execute().value
        self.family = family
        UserDefaults.standard.set(family.id.uuidString, forKey: familyIdKey)
        await refreshMembers()
        currentMember = members.first { $0.userId == SupabaseService.shared.userId }
    }

    func refreshMembers() async {
        guard let family, !isDemo else { return }
        do {
            members = try await client
                .from("family_members").select()
                .eq("family_id", value: family.id.uuidString)
                .order("joined_at")
                .execute().value
        } catch {
            print("Family member refresh failed: \(error)")
        }
    }

    func leaveFamily() async {
        if let member = currentMember {
            _ = try? await client.from("family_members").delete()
                .eq("id", value: member.id.uuidString)
                .execute()
        }
        UserDefaults.standard.removeObject(forKey: familyIdKey)
        family = nil
        members = []
        currentMember = nil
    }

    func member(for id: UUID) -> FamilyMember? {
        members.first { $0.id == id }
    }

    func enterDemo() {
        isDemo = true
        family = DemoData.family
        members = DemoData.familyMembers
        currentMember = DemoData.familyMembers[0]
    }
}
