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
    /// Every group this user belongs to — their own family, in-laws, a
    /// friend group. One is active at a time.
    @Published var myFamilies: [Family] = []
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
            await refreshMyFamilies()
            if let idString = UserDefaults.standard.string(forKey: familyIdKey),
               let id = UUID(uuidString: idString),
               myFamilies.contains(where: { $0.id == id }) {
                try await loadFamily(id: id)
            } else if let first = myFamilies.first {
                try await loadFamily(id: first.id)
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
        Task {
            await refreshMembers()
            await refreshMyFamilies()
        }
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

    func refreshMyFamilies() async {
        guard !isDemo else {
            myFamilies = [DemoData.family]
            return
        }
        do {
            let families: [Family] = try await client.from("families").select().execute().value
            myFamilies = families.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        } catch {
            print("Group refresh failed: \(error)")
        }
    }

    func rename(to newName: String) async throws {
        guard let family else { return }
        let trimmed = newName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        if isDemo {
            self.family?.name = trimmed
            return
        }
        _ = try await client.from("families")
            .update(["name": trimmed])
            .eq("id", value: family.id.uuidString)
            .execute()
        self.family?.name = trimmed
        await refreshMyFamilies()
    }

    func switchFamily(to newFamily: Family) async {
        guard newFamily.id != family?.id, !isDemo else { return }
        do {
            try await loadFamily(id: newFamily.id)
        } catch {
            print("Group switch failed: \(error)")
        }
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
        let leftId = family?.id
        family = nil
        members = []
        currentMember = nil
        // Fall back to another group if this user is in more than one.
        await refreshMyFamilies()
        myFamilies.removeAll { $0.id == leftId }
        if let next = myFamilies.first {
            try? await loadFamily(id: next.id)
        }
    }

    func member(for id: UUID) -> FamilyMember? {
        members.first { $0.id == id }
    }

    func enterDemo() {
        isDemo = true
        family = DemoData.family
        members = DemoData.familyMembers
        currentMember = DemoData.familyMembers[0]
        myFamilies = [DemoData.family]
    }
}
