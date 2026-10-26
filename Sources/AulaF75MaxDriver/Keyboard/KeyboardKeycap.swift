import SwiftUI

/// Standalone, non-interactive key using the Home keyboard's sculpted cap palette.
struct KeyboardKeycap: View {
    let label: String
    var isKnob = false

    var body: some View {
        ZStack {
            if isKnob {
                Circle()
                    .fill(.radialGradient(colors: [Color(white: 0.42), Color(white: 0.12)], center: .topLeading, startRadius: 0, endRadius: 48))
                    .overlay(Circle().strokeBorder(.white.opacity(0.22), lineWidth: 1))
                Image(systemName: "dial.low")
                    .foregroundStyle(.white)
                    .font(.system(size: 22))
            } else {
                RoundedRectangle(cornerRadius: 7)
                    .fill(.linearGradient(colors: [KeyboardKeycapPalette.skirtTop, KeyboardKeycapPalette.skirtBottom], startPoint: .top, endPoint: .bottom))
                RoundedRectangle(cornerRadius: 5)
                    .fill(.linearGradient(colors: [KeyboardKeycapPalette.faceTop, KeyboardKeycapPalette.faceBottom], startPoint: .top, endPoint: .bottom))
                    .padding(.horizontal, 5)
                    .padding(.top, 3)
                    .padding(.bottom, 9)
                Text(label)
                    .font(.system(size: 15, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color(white: 0.18))
                    .offset(y: -3)
            }
        }
        .frame(width: isKnob ? 48 : max(48, CGFloat(label.count) * 10 + 22), height: 48)
        .accessibilityLabel(label)
    }
}

/// Light cap colours shared with the Home keyboard artwork.
enum KeyboardKeycapPalette {
    static let faceTop = Color(white: 0.86)
    static let faceBottom = Color(white: 0.74)
    static let skirtTop = Color(white: 0.66)
    static let skirtBottom = Color(white: 0.5)
}
