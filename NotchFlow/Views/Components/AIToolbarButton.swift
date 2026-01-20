import SwiftUI

/// A compact button for AI actions in toolbars
struct AIToolbarButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    @State private var isHovering: Bool = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                Text(label)
                    .font(.system(size: 10))
            }
            .foregroundColor(isHovering ? .indigo : .secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isHovering ? Color.indigo.opacity(0.1) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }
}

// MARK: - Preview

#Preview {
    HStack {
        AIToolbarButton(icon: "text.badge.minus", label: "Summarize") {}
        AIToolbarButton(icon: "text.badge.plus", label: "Expand") {}
        AIToolbarButton(icon: "sparkles", label: "Suggest") {}
    }
    .padding()
    .background(Color.black.opacity(0.8))
}
