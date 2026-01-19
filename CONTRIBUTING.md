# Contributing to NotchFlow

Thank you for your interest in contributing to NotchFlow! This document provides guidelines and instructions for contributing.

## Community Guidelines

Please be respectful, inclusive, and constructive in all interactions when contributing to NotchFlow.

## How to Contribute

### Reporting Bugs

1. Check existing [issues](https://github.com/zzfadi/NotchFlow/issues) to avoid duplicates
2. Use the bug report template when creating a new issue
3. Include:
   - macOS version
   - Steps to reproduce
   - Expected vs actual behavior
   - Screenshots if applicable

### Suggesting Features

1. Check existing issues and discussions first
2. Use the feature request template
3. Explain the problem your feature would solve
4. Describe your proposed solution

### Pull Requests

1. Fork the repository
2. Create a feature branch from `main`:
   ```bash
   git checkout -b feature/your-feature-name
   ```
3. Make your changes
4. Run the build and ensure it passes:
   ```bash
   cd NotchFlow
   swift build
   ```
5. Run SwiftLint and fix any issues:
   ```bash
   swiftlint lint
   ```
6. Commit your changes with a clear message
7. Push to your fork and submit a pull request

## Development Setup

### Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 15.0 or later
- Swift 5.9+

### Building

**Option 1: Xcode**
```bash
open NotchFlow/NotchFlow.xcodeproj
# Build with Cmd+B, Run with Cmd+R
```

**Option 2: Swift Package Manager**
```bash
cd NotchFlow
swift build
swift run
```

### Project Structure

```
NotchFlow/
├── App/           # App entry point and delegate
├── Core/          # Shared managers and state
├── Views/         # Main UI views
├── MiniApps/      # Individual mini-app modules
│   ├── FogNote/   # Note-taking
│   ├── Worktree/  # Git worktree browser
│   └── AIConfig/  # AI config file finder
└── Resources/     # Assets and configuration
```

## Code Style

- Follow Swift API Design Guidelines
- Use SwiftLint (configuration in `.swiftlint.yml`)
- Keep functions focused and small
- Use meaningful variable and function names
- Add comments for complex logic only

### Naming Conventions

- Types: `UpperCamelCase`
- Functions/variables: `lowerCamelCase`
- Constants: `lowerCamelCase`
- Protocols: `UpperCamelCase` (noun or adjective)

## Commit Messages

Use clear, descriptive commit messages:

```
feat: Add keyboard shortcut for quick note access
fix: Resolve worktree scanning on external drives
docs: Update installation instructions
refactor: Simplify navigation state management
```

Prefixes:
- `feat:` New feature
- `fix:` Bug fix
- `docs:` Documentation only
- `refactor:` Code change that neither fixes a bug nor adds a feature
- `test:` Adding or updating tests
- `chore:` Maintenance tasks

## Questions?

Feel free to open a discussion or issue if you have questions about contributing.
