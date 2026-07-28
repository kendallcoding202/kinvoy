import SwiftUI

struct JoinTripView: View {
    @EnvironmentObject private var store: TripStore
    @Environment(\.dismiss) private var dismiss

    @State private var code = ""
    @State private var displayName = ""
    @State private var isWorking = false
    @State private var errorMessage: String?

    private var canSubmit: Bool {
        code.trimmingCharacters(in: .whitespaces).count >= 6
            && !displayName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Invite code") {
                    TextField("6-character code", text: $code)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .font(.system(.title2, design: .monospaced))
                }
                Section("You") {
                    TextField("Your name (what family sees)", text: $displayName)
                }
                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(.red).font(.callout)
                    }
                }
            }
            .navigationTitle("Join a trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isWorking {
                        ProgressView()
                    } else {
                        Button("Join") { submit() }
                            .disabled(!canSubmit)
                    }
                }
            }
        }
    }

    private func submit() {
        guard AppConfig.isConfigured else {
            errorMessage = "The backend isn't set up yet — see SETUP.md, or use the demo trip."
            return
        }
        isWorking = true
        errorMessage = nil
        Task {
            do {
                try await store.joinTrip(
                    code: code,
                    displayName: displayName.trimmingCharacters(in: .whitespaces)
                )
                dismiss()
            } catch {
                errorMessage = "Couldn't join — double-check the code and try again."
                isWorking = false
            }
        }
    }
}
