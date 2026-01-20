import SwiftUI

/// Content type detected from filename or content inspection.
enum RichContentType {
    case markdown
    case json
    case yaml
    case toml
    case swift
    case python
    case javascript
    case typescript
    case shell
    case plainText

    /// The language identifier for syntax highlighting
    var highlightLanguage: String? {
        switch self {
        case .markdown, .plainText: return nil
        case .json: return "json"
        case .yaml: return "yaml"
        case .toml: return "toml"
        case .swift: return "swift"
        case .python: return "python"
        case .javascript: return "javascript"
        case .typescript: return "typescript"
        case .shell: return "bash"
        }
    }

    /// Whether this content type should be rendered as markdown
    var isMarkdown: Bool {
        self == .markdown
    }

    /// Detect content type from filename extension
    static func detect(from filename: String?) -> RichContentType {
        guard let filename = filename?.lowercased() else {
            return .plainText
        }

        let ext = (filename as NSString).pathExtension

        switch ext {
        case "md", "markdown":
            return .markdown
        case "json":
            return .json
        case "yaml", "yml":
            return .yaml
        case "toml":
            return .toml
        case "swift":
            return .swift
        case "py":
            return .python
        case "js", "jsx":
            return .javascript
        case "ts", "tsx":
            return .typescript
        case "sh", "bash", "zsh":
            return .shell
        default:
            // Check for dotfiles that are typically markdown
            if filename.hasSuffix("rules") || filename == "claude.md" {
                return .markdown
            }
            return .plainText
        }
    }
}

/// A unified view that auto-detects content type and renders appropriately.
/// Renders markdown files as formatted markdown, code files with syntax highlighting.
///
/// Usage:
/// ```swift
/// RichContentPreview(content: fileContent, filename: "README.md")
/// RichContentPreview(content: jsonString, filename: "config.json")
/// ```
struct RichContentPreview: View {
    let content: String
    var filename: String? = nil
    var theme: RichContentTheme = .default
    var maxLines: Int? = nil

    private var contentType: RichContentType {
        RichContentType.detect(from: filename)
    }

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
        Group {
            if contentType.isMarkdown {
                MarkdownView(content: displayContent, theme: theme)
            } else if let language = contentType.highlightLanguage {
                CodeBlockView(code: displayContent, language: language, theme: theme)
                    .padding(8)
                    .background(Color.black.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                // Plain text fallback
                Text(displayContent)
                    .font(.system(size: theme.codeFontSize, design: .monospaced))
                    .foregroundColor(.white.opacity(0.85))
                    .textSelection(.enabled)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview("Markdown") {
    ScrollView {
        RichContentPreview(
            content: """
            # CLAUDE.md

            This is a **configuration file** for Claude Code.

            ## Guidelines

            - Use Swift for all code
            - Follow clean architecture

            ```swift
            print("Hello")
            ```
            """,
            filename: "CLAUDE.md"
        )
        .padding()
    }
    .frame(width: 400, height: 300)
    .background(Color.black)
}

#Preview("JSON") {
    ScrollView {
        RichContentPreview(
            content: """
            {
              "mcpServers": {
                "filesystem": {
                  "command": "npx",
                  "args": ["-y", "@modelcontextprotocol/server-filesystem"]
                }
              }
            }
            """,
            filename: "mcp.json"
        )
        .padding()
    }
    .frame(width: 400, height: 300)
    .background(Color.black)
}
