import Foundation
import SwiftUI

// MARK: - Prompt Template

struct PromptTemplate: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var description: String
    var content: String
    var category: Category
    var isBuiltIn: Bool
    var createdAt: Date
    var lastUsedAt: Date?
    var useCount: Int
    var successRate: Double?

    init(
        id: UUID = UUID(),
        name: String,
        description: String,
        content: String,
        category: Category,
        isBuiltIn: Bool = false,
        createdAt: Date = Date(),
        lastUsedAt: Date? = nil,
        useCount: Int = 0,
        successRate: Double? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.content = content
        self.category = category
        self.isBuiltIn = isBuiltIn
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt
        self.useCount = useCount
        self.successRate = successRate
    }

    enum Category: String, Codable, CaseIterable, Identifiable {
        case refactor
        case testing
        case bugfix
        case feature
        case documentation
        case performance
        case security
        case custom

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .refactor: return "Refactor"
            case .testing: return "Testing"
            case .bugfix: return "Bug Fix"
            case .feature: return "Feature"
            case .documentation: return "Documentation"
            case .performance: return "Performance"
            case .security: return "Security"
            case .custom: return "Custom"
            }
        }

        var icon: String {
            switch self {
            case .refactor: return "arrow.triangle.2.circlepath"
            case .testing: return "checkmark.shield"
            case .bugfix: return "ladybug"
            case .feature: return "star"
            case .documentation: return "doc.text"
            case .performance: return "gauge.with.dots.needle.67percent"
            case .security: return "lock.shield"
            case .custom: return "square.and.pencil"
            }
        }

        var color: Color {
            switch self {
            case .refactor: return .purple
            case .testing: return .green
            case .bugfix: return .red
            case .feature: return .blue
            case .documentation: return .orange
            case .performance: return .yellow
            case .security: return .pink
            case .custom: return .gray
            }
        }
    }

    var formattedSuccessRate: String {
        guard let rate = successRate else { return "—" }
        return String(format: "%.0f%%", rate * 100)
    }
}

// MARK: - Built-in Templates

extension PromptTemplate {
    static let builtInTemplates: [PromptTemplate] = [
        PromptTemplate(
            name: "Refactor to Pattern",
            description: "Convert code to a specific design pattern",
            content: """
            # Task: Refactor to Design Pattern

            ## Objective
            Refactor the code in this project to use the [PATTERN_NAME] design pattern.

            ## Requirements
            - Identify code that would benefit from this pattern
            - Implement the pattern while maintaining existing functionality
            - Update tests to verify the refactoring works correctly
            - Ensure all existing tests pass

            ## Success Criteria
            - Code compiles without errors
            - All tests pass
            - The pattern is correctly implemented

            When you are done, output "RALPH_COMPLETE" on a new line.
            """,
            category: .refactor,
            isBuiltIn: true
        ),
        PromptTemplate(
            name: "Add Test Coverage",
            description: "Generate tests for untested code",
            content: """
            # Task: Add Test Coverage

            ## Objective
            Add comprehensive test coverage to the codebase.

            ## Requirements
            - Identify code paths without tests
            - Write unit tests for uncovered functions
            - Include edge cases and error conditions
            - Aim for at least 80% code coverage

            ## Success Criteria
            - All new tests pass
            - Coverage increased meaningfully
            - No regressions in existing tests

            When you are done, output "RALPH_COMPLETE" on a new line.
            """,
            category: .testing,
            isBuiltIn: true
        ),
        PromptTemplate(
            name: "Fix All Linting",
            description: "Run until zero lint errors",
            content: """
            # Task: Fix All Linting Issues

            ## Objective
            Fix all linting errors and warnings in the codebase.

            ## Requirements
            - Run the linter to identify all issues
            - Fix each issue while preserving functionality
            - Do not disable lint rules unless absolutely necessary
            - Document any intentional rule exceptions

            ## Success Criteria
            - Linter reports zero errors
            - Linter reports zero warnings (or justified exceptions)
            - All tests still pass

            When you are done, output "RALPH_COMPLETE" on a new line.
            """,
            category: .refactor,
            isBuiltIn: true
        ),
        PromptTemplate(
            name: "Implement Feature",
            description: "Build a feature from specification",
            content: """
            # Task: Implement Feature

            ## Objective
            Implement the following feature: [FEATURE_DESCRIPTION]

            ## Requirements
            - Follow existing code patterns and conventions
            - Add appropriate tests for the new functionality
            - Update documentation if necessary
            - Handle error cases gracefully

            ## Success Criteria
            - Feature works as specified
            - All new and existing tests pass
            - Code follows project conventions

            When you are done, output "RALPH_COMPLETE" on a new line.
            """,
            category: .feature,
            isBuiltIn: true
        ),
        PromptTemplate(
            name: "Documentation Pass",
            description: "Add or improve documentation",
            content: """
            # Task: Documentation Pass

            ## Objective
            Improve the documentation across the codebase.

            ## Requirements
            - Add docstrings to undocumented public APIs
            - Update outdated documentation
            - Add code comments for complex logic
            - Create or update README files as needed

            ## Success Criteria
            - All public APIs have documentation
            - Documentation is accurate and helpful
            - Complex code sections have explanatory comments

            When you are done, output "RALPH_COMPLETE" on a new line.
            """,
            category: .documentation,
            isBuiltIn: true
        ),
        PromptTemplate(
            name: "Performance Audit",
            description: "Profile and optimize performance",
            content: """
            # Task: Performance Audit

            ## Objective
            Identify and fix performance bottlenecks in the codebase.

            ## Requirements
            - Profile the code to identify slow operations
            - Optimize critical code paths
            - Add caching where appropriate
            - Ensure optimizations don't break functionality

            ## Success Criteria
            - Measurable performance improvement
            - All tests pass
            - No new bugs introduced

            When you are done, output "RALPH_COMPLETE" on a new line.
            """,
            category: .performance,
            isBuiltIn: true
        ),
        PromptTemplate(
            name: "Security Review",
            description: "Find and fix security vulnerabilities",
            content: """
            # Task: Security Review

            ## Objective
            Review the codebase for security vulnerabilities and fix them.

            ## Requirements
            - Check for common vulnerabilities (injection, XSS, etc.)
            - Review authentication and authorization code
            - Ensure sensitive data is handled properly
            - Add input validation where missing

            ## Success Criteria
            - No known vulnerabilities remain
            - Security best practices are followed
            - All tests pass

            When you are done, output "RALPH_COMPLETE" on a new line.
            """,
            category: .security,
            isBuiltIn: true
        ),
        PromptTemplate(
            name: "Bug Hunt",
            description: "Find and fix bugs systematically",
            content: """
            # Task: Bug Hunt

            ## Objective
            Systematically find and fix bugs in the codebase.

            ## Requirements
            - Run existing tests and fix any failures
            - Look for common bug patterns
            - Add tests to prevent regression
            - Document fixes in commit messages

            ## Success Criteria
            - All tests pass
            - No obvious bugs remain
            - New tests cover fixed bugs

            When you are done, output "RALPH_COMPLETE" on a new line.
            """,
            category: .bugfix,
            isBuiltIn: true
        )
    ]
}

// MARK: - Prompt Version (for history tracking)

struct PromptVersion: Identifiable, Codable {
    let id: UUID
    let templateId: UUID
    let content: String
    let createdAt: Date
    var totalRuns: Int
    var successfulRuns: Int

    init(
        id: UUID = UUID(),
        templateId: UUID,
        content: String,
        createdAt: Date = Date(),
        totalRuns: Int = 0,
        successfulRuns: Int = 0
    ) {
        self.id = id
        self.templateId = templateId
        self.content = content
        self.createdAt = createdAt
        self.totalRuns = totalRuns
        self.successfulRuns = successfulRuns
    }

    var successRate: Double? {
        guard totalRuns > 0 else { return nil }
        return Double(successfulRuns) / Double(totalRuns)
    }

    var formattedSuccessRate: String {
        guard let rate = successRate else { return "—" }
        return String(format: "%.0f%%", rate * 100)
    }
}
