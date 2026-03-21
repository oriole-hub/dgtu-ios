import SwiftUI

struct ScreenProtectionOverlay: View {
    let isVisible: Bool

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 12) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 42))
                Text("Protected Content")
                    .font(.headline)
            }
            .foregroundStyle(.white)
        }
        .opacity(isVisible ? 1 : 0)
        .allowsHitTesting(isVisible)
        .accessibilityHidden(!isVisible)
        .zIndex(10)
        .animation(.easeInOut(duration: 0.15), value: isVisible)
    }
}
