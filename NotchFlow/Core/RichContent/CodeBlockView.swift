import SwiftUI
import HighlightSwift

/// A SwiftUI view that renders syntax-highlighted code.
/// Supports 50+ languages including JSON, YAML, Swift, Python, etc.
///
/// Usage:
/// ```swift
/// CodeBlockView(code: jsonString, language: "json")
/// CodeBlockView(code: swiftCode)  // Auto-detect language
/// ```
struct CodeBlockView: View {
    let code: String
    var language: String? = nil
    var theme: RichContentTheme = .default

    @State private var attributedCode: AttributedString?

    private let highlight = Highlight()

    var body: some View {
        Group {
            if let attributedCode {
                Text(attributedCode)
                    .font(.system(size: theme.codeFontSize, design: .monospaced))
                    .textSelection(.enabled)
            } else {
                // Fallback while highlighting or on error
                Text(code)
                    .font(.system(size: theme.codeFontSize, design: .monospaced))
                    .foregroundColor(.white.opacity(0.85))
                    .textSelection(.enabled)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .task(id: code) {
            await highlightCode()
        }
    }

    private func highlightCode() async {
        do {
            // Use dark color scheme for notch UI
            let colors: HighlightColors = .dark(.atomOne)

            if let language {
                // Use language alias for flexibility
                attributedCode = try await highlight.attributedText(
                    code,
                    language: language,
                    colors: colors
                )
            } else {
                // Auto-detect language
                attributedCode = try await highlight.attributedText(
                    code,
                    colors: colors
                )
            }
        } catch {
            // On error, just show plain text
            attributedCode = nil
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 16) {
        Text("JSON:")
            .foregroundColor(.gray)

        CodeBlockView(
            code: """
            {
              "name": "NotchFlow",
              "version": "1.0.0",
              "features": ["markdown", "syntax-highlighting"]
            }
            """,
            language: "json"
        )
        .padding(8)
        .background(Color.black.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 4))

        Text("Swift:")
            .foregroundColor(.gray)

        CodeBlockView(
            code: """
            struct ContentView: View {
                var body: some View {
                    Text("Hello, World!")
                }
            }
            """,
            language: "swift"
        )
        .padding(8)
        .background(Color.black.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
    .padding()
    .frame(width: 400)
    .background(Color.black)
}
