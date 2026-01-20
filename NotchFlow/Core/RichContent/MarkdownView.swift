import SwiftUI
import MarkdownUI

/// A SwiftUI view that renders markdown content.
/// Configured for the dark notch UI with compact text sizes.
///
/// Usage:
/// ```swift
/// MarkdownView(content: "# Hello\n**bold** and *italic*")
/// ```
struct MarkdownView: View {
    let content: String
    var theme: RichContentTheme = .default

    var body: some View {
        Markdown(content)
            .markdownTheme(theme.markdownTheme)
    }
}

#Preview {
    ScrollView {
        MarkdownView(content: """
            # Heading 1
            ## Heading 2
            ### Heading 3

            This is **bold** and *italic* text with `inline code`.

            - List item 1
            - List item 2
              - Nested item

            > A blockquote with some wisdom

            ```swift
            func hello() {
                print("Hello, World!")
            }
            ```

            [A link](https://example.com)
            """)
        .padding()
    }
    .frame(width: 400, height: 300)
    .background(Color.black)
}
