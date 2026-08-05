import Foundation
import Supabase
import SwiftUI

/// Reporting and blocking. Blocked people's content is hidden everywhere in
/// the app for the person who blocked them.
@MainActor
final class ModerationService: ObservableObject {
    /// auth user ids this device's user has blocked.
    @Published private(set) var blockedUserIds: Set<UUID> = []

    private var client: SupabaseClient { SupabaseService.shared.client }

    enum ContentKind: String {
        case tripMessage = "trip_message"
        case familyMessage = "family_message"
        case poll, photo, event, member
    }

    private struct BlockRow: Decodable {
        let blocked_id: UUID
    }

    func refreshBlocks() async {
        guard AppConfig.isConfigured, SupabaseService.shared.userId != nil else { return }
        do {
            let rows: [BlockRow] = try await client.from("blocks").select("blocked_id").execute().value
            blockedUserIds = Set(rows.map(\.blocked_id))
        } catch {
            print("Block refresh failed: \(error)")
        }
    }

    func report(kind: ContentKind, contentId: UUID, reason: String) async throws {
        guard let userId = SupabaseService.shared.userId else { return }
        struct ReportInsert: Encodable {
            let reporter_id: String
            let content_kind: String
            let content_id: String
            let reason: String
        }
        _ = try await client.from("reports").insert(ReportInsert(
            reporter_id: userId.uuidString,
            content_kind: kind.rawValue,
            content_id: contentId.uuidString,
            reason: String(reason.prefix(500))
        )).execute()
    }

    /// Resolves a member id to its user id, then blocks that user.
    func block(memberId: UUID, scope: Scope) async throws {
        guard let me = SupabaseService.shared.userId else { return }
        let params = ["p_member_id": memberId.uuidString, "p_scope": scope.rawValue]
        let target: UUID? = try await client.rpc("user_id_for_member", params: params).execute().value
        guard let target, target != me else { return }

        struct BlockInsert: Encodable {
            let blocker_id: String
            let blocked_id: String
        }
        _ = try await client.from("blocks")
            .insert(BlockInsert(blocker_id: me.uuidString, blocked_id: target.uuidString))
            .execute()
        blockedUserIds.insert(target)
    }

    func unblock(userId: UUID) async {
        _ = try? await client.from("blocks").delete()
            .eq("blocked_id", value: userId.uuidString)
            .execute()
        blockedUserIds.remove(userId)
    }

    enum Scope: String {
        case trip, family
    }

    func isBlocked(userId: UUID?) -> Bool {
        guard let userId else { return false }
        return blockedUserIds.contains(userId)
    }

    /// Permanently deletes this user's account and everything they own.
    func deleteAccount() async throws {
        _ = try await client.rpc("delete_my_account").execute()
        try? await client.auth.signOut()
        UserDefaults.standard.removeObject(forKey: "currentTripId")
        UserDefaults.standard.removeObject(forKey: "currentFamilyId")
        UserDefaults.standard.removeObject(forKey: "familySharingEnabled")
    }
}

/// Identifies the thing a report sheet is about.
struct ReportTarget: Identifiable {
    let kind: ModerationService.ContentKind
    let contentId: UUID
    let authorMemberId: UUID?
    var id: UUID { contentId }
}

/// Report sheet shared by chat, photos, and polls.
struct ReportSheet: View {
    let kind: ModerationService.ContentKind
    let contentId: UUID
    let authorMemberId: UUID?
    let scope: ModerationService.Scope

    @EnvironmentObject private var moderation: ModerationService
    @Environment(\.dismiss) private var dismiss
    @State private var reason = ""
    @State private var alsoBlock = false
    @State private var isWorking = false
    @State private var errorMessage: String?

    private let reasons = [
        "Offensive or abusive",
        "Harassment or bullying",
        "Spam",
        "Inappropriate images",
        "Something else",
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("What's wrong with this?") {
                    ForEach(reasons, id: \.self) { option in
                        Button {
                            reason = option
                        } label: {
                            HStack {
                                Text(option).foregroundStyle(.primary)
                                Spacer()
                                if reason == option {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.accentColor)
                                }
                            }
                        }
                    }
                }
                if authorMemberId != nil {
                    Section {
                        Toggle("Also block this person", isOn: $alsoBlock)
                    } footer: {
                        Text("You won't see their messages, photos, or polls anywhere in Kinvoy.")
                    }
                }
                Section {
                    Text("Reports go to the Kinvoy team for review. We remove objectionable content and can remove people who post it.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red).font(.callout)
                }
            }
            .navigationTitle("Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isWorking {
                        ProgressView()
                    } else {
                        Button("Submit") { submit() }
                            .disabled(reason.isEmpty)
                    }
                }
            }
        }
    }

    private func submit() {
        isWorking = true
        Task {
            do {
                try await moderation.report(kind: kind, contentId: contentId, reason: reason)
                if alsoBlock, let authorMemberId {
                    try await moderation.block(memberId: authorMemberId, scope: scope)
                }
                dismiss()
            } catch {
                errorMessage = "Couldn't submit the report. Try again."
                isWorking = false
            }
        }
    }
}
