import SwiftUI

/// App Store Guideline 1.2 requires people to agree to terms with a
/// zero-tolerance policy for objectionable content before they can post.
/// Shown once, before anything else.
struct TermsGate: View {
    @AppStorage("acceptedTermsVersion") private var acceptedVersion = 0
    static let currentVersion = 1

    static var hasAccepted: Bool {
        UserDefaults.standard.integer(forKey: "acceptedTermsVersion") >= currentVersion
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 18) {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.accentColor)

                Text("Before you start")
                    .font(.title.bold())

                Text("Kinvoy is a private space for your people. Everyone here agrees to keep it that way.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                VStack(alignment: .leading, spacing: 14) {
                    rule(
                        icon: "xmark.octagon.fill",
                        title: "No objectionable content",
                        detail: "Harassment, hate, explicit images, and abuse are not allowed — zero tolerance."
                    )
                    rule(
                        icon: "flag.fill",
                        title: "Report anything that crosses the line",
                        detail: "Press and hold any message or photo to report it. We review reports within 24 hours and remove offenders."
                    )
                    rule(
                        icon: "location.fill",
                        title: "Location is always your choice",
                        detail: "Sharing is opt-in, and turning it off deletes your location."
                    )
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 28)

            Spacer()

            VStack(spacing: 12) {
                Button {
                    acceptedVersion = Self.currentVersion
                } label: {
                    Text("I agree")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)

                HStack(spacing: 16) {
                    Link("Terms of Use", destination: URL(string: "https://kendallcoding202.github.io/kinvoy/terms.html")!)
                    Link("Privacy Policy", destination: URL(string: "https://kendallcoding202.github.io/kinvoy/privacy.html")!)
                }
                .font(.footnote)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 34)
        }
        .frame(maxWidth: 480)
        .frame(maxWidth: .infinity)
    }

    private func rule(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(Color.accentColor)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
