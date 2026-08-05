import SwiftUI

/// Shown while the app restores your family and trips on cold launch.
struct LaunchView: View {
    @State private var glow = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.99, green: 0.72, blue: 0.35),
                    Color(red: 0.98, green: 0.45, blue: 0.25),
                    Color(red: 0.90, green: 0.30, blue: 0.32),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 22) {
                Spacer()

                Image("LaunchMark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 168, height: 168)
                    .clipShape(RoundedRectangle(cornerRadius: 38, style: .continuous))
                    .shadow(color: .black.opacity(0.22), radius: 18, y: 8)
                    .scaleEffect(glow ? 1.03 : 0.97)
                    .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: glow)

                VStack(spacing: 8) {
                    Text("Kinvoy")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Kinvoy is loading,\nyour next adventure awaits")
                        .font(.callout)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white.opacity(0.9))
                }

                Spacer()

                ProgressView()
                    .tint(.white)
                    .padding(.bottom, 60)
            }
            .padding()
        }
        .onAppear { glow = true }
    }
}
