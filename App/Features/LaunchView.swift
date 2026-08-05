import SwiftUI

/// Full-bleed launch screen: the Kinvoy sunset fills the entire display,
/// with the wordmark and loading line over it.
struct LaunchView: View {
    @State private var appeared = false

    var body: some View {
        ZStack {
            // Gradient underneath guarantees no letterboxing on any size.
            LinearGradient(
                colors: [
                    Color(red: 0.99, green: 0.76, blue: 0.40),
                    Color(red: 0.95, green: 0.38, blue: 0.28),
                    Color(red: 0.07, green: 0.20, blue: 0.36),
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            Image("LaunchMark")
                .resizable()
                .scaledToFill()
                .scaleEffect(appeared ? 1.0 : 1.06)
                .animation(.easeOut(duration: 2.4), value: appeared)

            // Darkens the top band so the type stays legible.
            LinearGradient(
                colors: [.black.opacity(0.42), .black.opacity(0.12), .clear],
                startPoint: .top,
                endPoint: .center
            )

            // Everything sits in the open sky at the top, where there's
            // nothing behind it to fight with.
            VStack(spacing: 14) {
                Text("Kinvoy")
                    .font(.system(size: 58, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.35), radius: 12, y: 3)

                Text("Kinvoy is loading,\nyour next adventure awaits")
                    .font(.headline.weight(.medium))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.4), radius: 8, y: 2)

                ProgressView()
                    .tint(.white)
                    .padding(.top, 6)

                Spacer()
            }
            .padding(.top, 90)
            .opacity(appeared ? 1 : 0)
            .animation(.easeIn(duration: 0.5), value: appeared)
        }
        .ignoresSafeArea()
        .onAppear { appeared = true }
    }
}
