import SwiftUI

/// A simple content preview view without external dependencies.
/// Used for displaying configuration file content in AIConfigView.
struct SimpleContentPreview: View {
    let content: String
    var filename: String? = nil
    var maxLines: Int? = nil

    private var displayContent: String {
        guard let maxLines, maxLines > 0 else {
            return content
        }

        let lines = content.components(separatedBy: .newlines)
        if lines.count > maxLines {
            return lines.prefix(maxLines).joined(separator: "\n") + "\n..."
        }
        return content
    }

    var body: some View {
        Text(displayContent)
            .font(.system(size: 11, design: .monospaced))
            .foregroundColor(.white.opacity(0.85))
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    SimpleContentPreview(
        content: """
        {
          "mcpServers": {
            "filesystem": {
              "command": "npx"
            }
          }
        }
        """,
        filename: "config.json"
    )
    .padding()
    .background(Color.black)
}
