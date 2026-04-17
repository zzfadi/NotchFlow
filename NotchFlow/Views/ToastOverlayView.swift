import SwiftUI

/// Renders the active toasts from `ErrorCenter` as a stack at the bottom of
/// the expanded notch. Stays out of the way of normal tab content — only
/// shows when something needs surfacing.
struct ToastOverlayView: View {
    @ObservedObject private var center = ErrorCenter.shared

    var body: some View {
        VStack(spacing: 6) {
            ForEach(center.toasts) { toast in
                toastRow(toast)
                    .transition(
                        .move(edge: .bottom)
                            .combined(with: .opacity)
                    )
            }
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 8)
        .animation(.easeInOut(duration: 0.18), value: center.toasts)
    }

    private func toastRow(_ toast: Toast) -> some View {
        HStack(spacing: 8) {
            Image(systemName: toast.level.iconName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(toast.level.color)

            Text(toast.message)
                .font(.system(size: 11))
                .foregroundColor(.primary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            Button {
                center.dismiss(id: toast.id)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Dismiss")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.7))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(toast.level.color.opacity(0.4), lineWidth: 1)
                )
        )
    }
}

#Preview {
    ToastOverlayView()
        .frame(width: 420, height: 120)
        .background(Color.gray.opacity(0.2))
}
