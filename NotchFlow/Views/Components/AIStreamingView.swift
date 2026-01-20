import SwiftUI

/// Displays streaming AI-generated text with a typing indicator
struct AIStreamingView: View {
    let text: String
    let isStreaming: Bool
    var fontSize: CGFloat = 12
    var maxHeight: CGFloat? = nil

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    Text(text)
                        .font(.system(size: fontSize))
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)

                    if isStreaming {
                        typingIndicator
                            .id("bottom")
                    }
                }
                .padding(12)
            }
            .frame(maxHeight: maxHeight)
            .background(Color.primary.opacity(0.05))
            .cornerRadius(8)
            .onChange(of: text) { _, _ in
                if isStreaming {
                    withAnimation(.easeOut(duration: 0.1)) {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
            }
        }
    }

    private var typingIndicator: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Color.indigo)
                    .frame(width: 4, height: 4)
                    .scaleEffect(isStreaming ? 1.0 : 0.5)
                    .animation(
                        .easeInOut(duration: 0.4)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.15),
                        value: isStreaming
                    )
            }
        }
    }
}

// MARK: - AI Result Popover

/// A popover view for displaying AI generation results with action buttons
struct AIResultPopover: View {
    @Binding var result: String
    @Binding var isProcessing: Bool
    let onInsert: (String) -> Void
    let onReplace: (String) -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Label("AI Result", systemImage: "wand.and.stars")
                    .font(.headline)
                    .foregroundColor(.indigo)

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            // Content
            AIStreamingView(
                text: result.isEmpty ? "Generating..." : result,
                isStreaming: isProcessing,
                maxHeight: 200
            )

            // Actions (only show when done)
            if !isProcessing && !result.isEmpty {
                HStack(spacing: 12) {
                    Button(action: { onInsert(result) }) {
                        Label("Insert", systemImage: "plus.circle")
                    }
                    .buttonStyle(.bordered)

                    Button(action: { onReplace(result) }) {
                        Label("Replace", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    Button(action: copyToClipboard) {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                }
            }
        }
        .padding(16)
        .frame(width: 350)
    }

    private func copyToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(result, forType: .string)
    }
}

// MARK: - AI Error Banner

/// An inline error banner for AI-related errors
struct AIErrorBanner: View {
    let error: FoundationModelsError
    let onRetry: (() -> Void)?
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)

            Text(error.userMessage)
                .font(.system(size: 11))
                .foregroundColor(.primary)

            Spacer()

            if let retry = onRetry {
                Button("Retry", action: retry)
                    .font(.system(size: 10))
                    .buttonStyle(.plain)
                    .foregroundColor(.indigo)
            }

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(8)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(6)
    }
}

// MARK: - AI Processing Indicator

/// A small inline indicator showing AI processing status
struct AIProcessingIndicator: View {
    let isProcessing: Bool
    var label: String = "Processing"

    var body: some View {
        if isProcessing {
            HStack(spacing: 6) {
                ProgressView()
                    .scaleEffect(0.6)
                    .frame(width: 12, height: 12)

                Text(label)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Previews

#Preview("Streaming View") {
    VStack(spacing: 20) {
        AIStreamingView(
            text: "This is a sample AI-generated response that demonstrates the streaming text display with proper formatting and styling.",
            isStreaming: true,
            maxHeight: 150
        )

        AIStreamingView(
            text: "This response is complete.",
            isStreaming: false,
            maxHeight: 150
        )
    }
    .padding()
    .frame(width: 400)
}

#Preview("Error Banner") {
    VStack(spacing: 12) {
        AIErrorBanner(
            error: .notAvailable(.unavailableNotConfigured),
            onRetry: {},
            onDismiss: {}
        )

        AIErrorBanner(
            error: .generationFailed("Network error"),
            onRetry: nil,
            onDismiss: {}
        )
    }
    .padding()
    .frame(width: 350)
}
