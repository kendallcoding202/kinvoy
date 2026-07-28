import Foundation
import Supabase

/// Thin wrapper around the Supabase client. All network access goes through here.
final class SupabaseService {
    static let shared = SupabaseService()

    let client: SupabaseClient

    private init() {
        // Falls back to a dummy URL when unconfigured; the app shows the
        // setup/demo screen in that case and never calls the network.
        let url = URL(string: AppConfig.isConfigured ? AppConfig.supabaseURL : "https://unconfigured.supabase.co")!
        client = SupabaseClient(supabaseURL: url, supabaseKey: AppConfig.supabaseAnonKey)
    }

    /// Every device gets an anonymous Supabase user the first time the app
    /// runs. Invite codes control which trip that user can see. Later, these
    /// anonymous users can be linked to email accounts for subscriptions.
    func ensureSignedIn() async throws {
        if client.auth.currentSession == nil {
            try await client.auth.signInAnonymously()
        }
    }

    var userId: UUID? {
        client.auth.currentSession?.user.id
    }
}
