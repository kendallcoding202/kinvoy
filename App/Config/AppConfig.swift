import Foundation

/// Central place for backend configuration.
///
/// EDIT ME: after creating your Supabase project (see SETUP.md), paste the
/// project URL and anon (public) key below. The anon key is safe to ship in
/// the app binary — row-level security protects the data.
enum AppConfig {
    static let supabaseURL = "https://rrcgwnwvpfczcndxpozz.supabase.co"
    static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJyY2d3bnd2cGZjemNuZHhwb3p6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODUyNTg5ODEsImV4cCI6MjEwMDgzNDk4MX0.oCVUCzG3Pgp9aUN64VUGGmMuI8fuo56GETVO6fFZ-Es"

    /// True once real values have been pasted in above.
    static var isConfigured: Bool {
        !supabaseURL.contains("EDIT_ME") && !supabaseAnonKey.contains("EDIT_ME")
    }
}
