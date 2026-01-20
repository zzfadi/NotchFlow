import SwiftUI

/// A stylized cartoon character drawing inspired by the Ralph Wiggum aesthetic
/// Uses simple SwiftUI shapes to create a friendly, whimsical character
struct RalphCharacterDrawing: View {
    let state: RalphState
    @State private var isAnimating = false

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)

            ZStack {
                // Background glow based on state
                Circle()
                    .fill(state.color.opacity(0.15))
                    .scaleEffect(isAnimating ? 1.1 : 1.0)

                // Head (yellow circle)
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.yellow, Color.yellow.opacity(0.9)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: size * 0.8, height: size * 0.8)

                // Face features
                VStack(spacing: size * 0.02) {
                    // Eyes
                    HStack(spacing: size * 0.15) {
                        EyeView(state: state, size: size * 0.15)
                        EyeView(state: state, size: size * 0.15)
                    }
                    .offset(y: -size * 0.05)

                    // Nose (small oval)
                    Ellipse()
                        .fill(Color.orange.opacity(0.6))
                        .frame(width: size * 0.08, height: size * 0.05)

                    // Mouth based on state
                    MouthView(state: state, size: size)
                        .offset(y: size * 0.02)
                }

                // Hair spikes (simplified)
                HairView(size: size)
                    .offset(y: -size * 0.35)

                // State indicator badge
                stateIndicator(size: size)
                    .offset(x: size * 0.3, y: -size * 0.3)
            }
            .frame(width: size, height: size)
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }

    @ViewBuilder
    private func stateIndicator(size: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(state.color)
                .frame(width: size * 0.2, height: size * 0.2)

            Image(systemName: stateIcon)
                .font(.system(size: size * 0.1))
                .foregroundColor(.white)
        }
    }

    private var stateIcon: String {
        switch state {
        case .idle: return "moon.zzz"
        case .thinking: return "brain"
        case .working: return "hammer"
        case .confused: return "questionmark"
        case .error: return "exclamationmark.triangle"
        case .success: return "checkmark"
        case .compiling: return "gearshape"
        case .testing: return "testtube.2"
        case .committed: return "checkmark.seal"
        case .celebrating: return "star"
        }
    }
}

// MARK: - Eye Component

struct EyeView: View {
    let state: RalphState
    let size: CGFloat

    var body: some View {
        ZStack {
            // Eye white
            Ellipse()
                .fill(Color.white)
                .frame(width: size, height: size * 0.9)

            // Pupil
            Circle()
                .fill(Color.black)
                .frame(width: size * 0.4, height: size * 0.4)
                .offset(x: eyeOffset.x, y: eyeOffset.y)

            // Highlight
            Circle()
                .fill(Color.white)
                .frame(width: size * 0.15, height: size * 0.15)
                .offset(x: size * 0.1, y: -size * 0.1)
        }
    }

    private var eyeOffset: CGPoint {
        switch state {
        case .thinking: return CGPoint(x: 0, y: -2)  // Looking up
        case .confused: return CGPoint(x: 2, y: 2)   // Looking sideways
        case .error: return CGPoint(x: 0, y: 2)      // Looking down
        case .working, .compiling, .testing: return CGPoint(x: 0, y: 0)  // Focused
        default: return .zero
        }
    }
}

// MARK: - Mouth Component

struct MouthView: View {
    let state: RalphState
    let size: CGFloat

    var body: some View {
        switch state {
        case .idle, .thinking:
            // Neutral line
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.red.opacity(0.8))
                .frame(width: size * 0.2, height: size * 0.02)

        case .working, .compiling, .testing:
            // Focused "O" mouth
            Ellipse()
                .stroke(Color.red.opacity(0.8), lineWidth: 2)
                .frame(width: size * 0.1, height: size * 0.08)

        case .success, .celebrating, .committed:
            // Happy smile
            SmileShape()
                .stroke(Color.red.opacity(0.8), lineWidth: 3)
                .frame(width: size * 0.25, height: size * 0.1)

        case .confused:
            // Wavy confused mouth
            WavyMouthShape()
                .stroke(Color.red.opacity(0.8), lineWidth: 2)
                .frame(width: size * 0.2, height: size * 0.06)

        case .error:
            // Sad frown
            SmileShape()
                .stroke(Color.red.opacity(0.8), lineWidth: 3)
                .frame(width: size * 0.2, height: size * 0.08)
                .rotationEffect(.degrees(180))
        }
    }
}

// MARK: - Hair Component

struct HairView: View {
    let size: CGFloat

    var body: some View {
        HStack(spacing: size * 0.03) {
            ForEach(0..<5, id: \.self) { i in
                HairSpike(height: spikeHeight(for: i), width: size * 0.08)
                    .fill(Color.yellow.opacity(0.9))
            }
        }
    }

    private func spikeHeight(for index: Int) -> CGFloat {
        // Middle spikes are taller
        let heights: [CGFloat] = [0.08, 0.12, 0.15, 0.12, 0.08]
        return size * heights[index]
    }
}

// MARK: - Custom Shapes

struct HairSpike: Shape {
    let height: CGFloat
    let width: CGFloat

    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: 0, y: rect.maxY))
            path.addLine(to: CGPoint(x: width / 2, y: rect.maxY - height))
            path.addLine(to: CGPoint(x: width, y: rect.maxY))
            path.closeSubpath()
        }
    }
}

struct SmileShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: 0, y: 0))
            path.addQuadCurve(
                to: CGPoint(x: rect.width, y: 0),
                control: CGPoint(x: rect.midX, y: rect.height)
            )
        }
    }
}

struct WavyMouthShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: 0, y: rect.midY))
            path.addCurve(
                to: CGPoint(x: rect.width, y: rect.midY),
                control1: CGPoint(x: rect.width * 0.33, y: 0),
                control2: CGPoint(x: rect.width * 0.66, y: rect.height)
            )
        }
    }
}

// MARK: - Preview

#Preview("All States") {
    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))]) {
        ForEach(RalphState.allCases, id: \.self) { state in
            VStack {
                RalphCharacterDrawing(state: state)
                    .frame(width: 80, height: 80)
                Text(state.codingContext)
                    .font(.caption2)
            }
        }
    }
    .padding()
}

#Preview("Large Character") {
    RalphCharacterDrawing(state: .working)
        .frame(width: 200, height: 200)
}
