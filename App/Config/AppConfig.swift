import Foundation

/// Central place for backend configuration.
///
/// EDIT ME: after creating your Supabase project (see SETUP.md), paste the
/// project URL and anon (public) key below. The anon key is safe to ship in
/// the app binary — row-level security protects the data.
enum AppConfig {
    static let supabaseURL = "EDIT_ME_SUPABASE_URL"      // e.g. https://abcdefgh.supabase.co
    static let supabaseAnonKey = "EDIT_ME_SUPABASE_ANON_KEY"

    /// True once real values have been pasted in above.
    static var isConfigured: Bool {
        !supabaseURL.contains("EDIT_ME") && !supabaseAnonKey.contains("EDIT_ME")
    }
}
