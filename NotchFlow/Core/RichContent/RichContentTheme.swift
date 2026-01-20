import SwiftUI
import MarkdownUI
import HighlightSwift

/// Theme configuration for rich content rendering in the notch UI.
/// Optimized for dark backgrounds with compact text sizes.
@MainActor
enum RichContentTheme {
    case `default`
    case github
    case minimal

    /// Font size for body text (compact for notch UI)
    var bodyFontSize: CGFloat {
        switch self {
        case .default, .github: return 11
        case .minimal: return 10
        }
    }

    /// Font size for code blocks
    var codeFontSize: CGFloat {
        switch self {
        case .default, .github: return 10
        case .minimal: return 9
        }
    }

    /// MarkdownUI theme configured for dark notch background
    var markdownTheme: MarkdownUI.Theme {
        switch self {
        case .default, .minimal:
            return .basic
                .text {
                    ForegroundColor(.white.opacity(0.9))
                    FontSize(bodyFontSize)
                }
                .code {
                    FontFamilyVariant(.monospaced)
                    FontSize(.em(0.9))
                    ForegroundColor(.cyan.opacity(0.9))
                }
                .strong {
                    FontWeight(.semibold)
                }
                .link {
                    ForegroundColor(.blue)
                }
                .heading1 { configuration in
                    configuration.label
                        .markdownTextStyle {
                            FontWeight(.bold)
                            FontSize(16)
                            ForegroundColor(.white)
                        }
                        .markdownMargin(top: 12, bottom: 6)
                }
                .heading2 { configuration in
                    configuration.label
                        .markdownTextStyle {
                            FontWeight(.bold)
                            FontSize(14)
                            ForegroundColor(.white)
                        }
                        .markdownMargin(top: 10, bottom: 4)
                }
                .heading3 { configuration in
                    configuration.label
                        .markdownTextStyle {
                            FontWeight(.semibold)
                            FontSize(12)
                            ForegroundColor(.white)
                        }
                        .markdownMargin(top: 8, bottom: 4)
                }
                .codeBlock { configuration in
                    configuration.label
                        .markdownTextStyle {
                            FontFamilyVariant(.monospaced)
                            FontSize(codeFontSize)
                            ForegroundColor(.white.opacity(0.85))
                        }
                        .padding(8)
                        .background(Color.black.opacity(0.4))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .markdownMargin(top: 4, bottom: 4)
                }
                .blockquote { configuration in
                    HStack(spacing: 0) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.5))
                            .frame(width: 3)
                        configuration.label
                            .markdownTextStyle {
                                ForegroundColor(.gray)
                                FontSize(bodyFontSize)
                            }
                            .padding(.leading, 8)
                    }
                    .markdownMargin(top: 4, bottom: 4)
                }
                .listItem { configuration in
                    configuration.label
                        .markdownMargin(top: 2, bottom: 2)
                }

        case .github:
            return .gitHub
                .text {
                    ForegroundColor(.white.opacity(0.9))
                    FontSize(bodyFontSize)
                }
        }
    }

    /// HighlightSwift color scheme for syntax highlighting
    var highlightColorScheme: ColorScheme {
        .dark
    }
}
