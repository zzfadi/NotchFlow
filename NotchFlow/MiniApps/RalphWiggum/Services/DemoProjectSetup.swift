import Foundation

/// Sets up demo projects for testing Ralph Wiggum loops
struct DemoProjectSetup {

    // MARK: - Demo Project Types

    enum DemoProject: String, CaseIterable, Identifiable {
        case todoApp = "todo-app"
        case calculator = "calculator"
        case weatherWidget = "weather-widget"

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .todoApp: return "Todo App"
            case .calculator: return "Calculator"
            case .weatherWidget: return "Weather Widget"
            }
        }

        var description: String {
            switch self {
            case .todoApp: return "Build a simple SwiftUI todo list app"
            case .calculator: return "Create a basic calculator with history"
            case .weatherWidget: return "Build a weather display widget"
            }
        }

        var icon: String {
            switch self {
            case .todoApp: return "checklist"
            case .calculator: return "plus.forwardslash.minus"
            case .weatherWidget: return "cloud.sun"
            }
        }

        var promptContent: String {
            switch self {
            case .todoApp:
                return DemoProjectSetup.todoAppPrompt
            case .calculator:
                return DemoProjectSetup.calculatorPrompt
            case .weatherWidget:
                return DemoProjectSetup.weatherWidgetPrompt
            }
        }

        var starterFiles: [String: String] {
            switch self {
            case .todoApp:
                return DemoProjectSetup.todoAppStarterFiles
            case .calculator:
                return DemoProjectSetup.calculatorStarterFiles
            case .weatherWidget:
                return DemoProjectSetup.weatherWidgetStarterFiles
            }
        }
    }

    // MARK: - Setup Methods

    /// Creates a demo project in the specified directory
    static func setupDemoProject(_ project: DemoProject, in baseDirectory: URL) throws -> URL {
        let projectDir = baseDirectory.appendingPathComponent("RalphDemo-\(project.rawValue)")

        // Create directory
        try FileManager.default.createDirectory(at: projectDir, withIntermediateDirectories: true)

        // Write PROMPT.md
        let promptPath = projectDir.appendingPathComponent("PROMPT.md")
        try project.promptContent.write(to: promptPath, atomically: true, encoding: .utf8)

        // Write starter files
        for (filename, content) in project.starterFiles {
            let filePath = projectDir.appendingPathComponent(filename)

            // Create subdirectories if needed
            let parentDir = filePath.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)

            try content.write(to: filePath, atomically: true, encoding: .utf8)
        }

        // Initialize git repo
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["init"]
        process.currentDirectoryURL = projectDir
        try process.run()
        process.waitUntilExit()

        // Initial commit
        let addProcess = Process()
        addProcess.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        addProcess.arguments = ["add", "."]
        addProcess.currentDirectoryURL = projectDir
        try addProcess.run()
        addProcess.waitUntilExit()

        let commitProcess = Process()
        commitProcess.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        commitProcess.arguments = ["commit", "-m", "Initial demo setup"]
        commitProcess.currentDirectoryURL = projectDir
        try commitProcess.run()
        commitProcess.waitUntilExit()

        return projectDir
    }

    /// Returns the default demo directory
    static var defaultDemoDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("RalphWiggumDemos")
    }

    // MARK: - Todo App Demo

    private static let todoAppPrompt = """
    # Todo App Development Task

    You are building a simple SwiftUI todo list application. The app should have:

    ## Requirements
    1. A list view showing all todos
    2. Ability to add new todos with a text field
    3. Ability to mark todos as complete (strikethrough)
    4. Ability to delete todos (swipe to delete)
    5. Persist todos using UserDefaults or a JSON file

    ## Current State
    - Basic project structure exists in `Sources/`
    - `TodoItem.swift` has the model defined
    - `ContentView.swift` needs the main UI

    ## Your Task
    Implement the todo list UI in ContentView.swift. Make it functional with:
    - @State for managing the todo list
    - A TextField for adding new items
    - A List with ForEach for displaying items
    - Swipe actions for delete
    - Tap to toggle completion

    When you're done and the app compiles without errors, output "RALPH_COMPLETE" to signal completion.

    Focus on clean, idiomatic SwiftUI code. Keep it simple but functional.
    """

    private static let todoAppStarterFiles: [String: String] = [
        "Sources/TodoItem.swift": """
        import Foundation

        struct TodoItem: Identifiable, Codable, Equatable {
            let id: UUID
            var title: String
            var isCompleted: Bool

            init(id: UUID = UUID(), title: String, isCompleted: Bool = false) {
                self.id = id
                self.title = title
                self.isCompleted = isCompleted
            }
        }
        """,

        "Sources/ContentView.swift": """
        import SwiftUI

        struct ContentView: View {
            // TODO: Add @State for todos and newTodoText

            var body: some View {
                VStack {
                    Text("Todo App")
                        .font(.largeTitle)

                    // TODO: Add TextField for new todos

                    // TODO: Add List of todos

                    Spacer()
                }
                .padding()
            }
        }

        #Preview {
            ContentView()
        }
        """,

        "Package.swift": """
        // swift-tools-version: 5.9
        import PackageDescription

        let package = Package(
            name: "TodoApp",
            platforms: [.macOS(.v14)],
            targets: [
                .executableTarget(name: "TodoApp", path: "Sources")
            ]
        )
        """
    ]

    // MARK: - Calculator Demo

    private static let calculatorPrompt = """
    # Calculator App Development Task

    You are building a simple calculator application. The calculator should have:

    ## Requirements
    1. Basic operations: +, -, ×, ÷
    2. Clear button (C)
    3. Display showing current number and result
    4. History of recent calculations

    ## Current State
    - Basic project structure exists
    - `Calculator.swift` has the logic skeleton
    - `CalculatorView.swift` needs the UI

    ## Your Task
    1. Implement the calculator logic in Calculator.swift
    2. Build the UI in CalculatorView.swift with a grid of buttons
    3. Connect the logic to the UI

    When you're done and everything works, output "RALPH_COMPLETE".

    Keep the code clean and well-organized.
    """

    private static let calculatorStarterFiles: [String: String] = [
        "Sources/Calculator.swift": """
        import Foundation

        class Calculator: ObservableObject {
            @Published var display: String = "0"
            @Published var history: [String] = []

            private var currentNumber: Double = 0
            private var previousNumber: Double = 0
            private var operation: String? = nil
            private var shouldResetDisplay = false

            // TODO: Implement these methods

            func inputDigit(_ digit: String) {
                // Add digit to display
            }

            func inputOperation(_ op: String) {
                // Handle +, -, ×, ÷
            }

            func calculate() {
                // Perform the calculation
            }

            func clear() {
                display = "0"
                currentNumber = 0
                previousNumber = 0
                operation = nil
            }
        }
        """,

        "Sources/CalculatorView.swift": """
        import SwiftUI

        struct CalculatorView: View {
            @StateObject private var calculator = Calculator()

            var body: some View {
                VStack {
                    Text("Calculator")
                        .font(.title)

                    // TODO: Add display

                    // TODO: Add button grid

                    // TODO: Add history

                    Spacer()
                }
                .padding()
            }
        }

        #Preview {
            CalculatorView()
        }
        """,

        "Package.swift": """
        // swift-tools-version: 5.9
        import PackageDescription

        let package = Package(
            name: "Calculator",
            platforms: [.macOS(.v14)],
            targets: [
                .executableTarget(name: "Calculator", path: "Sources")
            ]
        )
        """
    ]

    // MARK: - Weather Widget Demo

    private static let weatherWidgetPrompt = """
    # Weather Widget Development Task

    You are building a weather display widget. It should show:

    ## Requirements
    1. Current temperature display (mock data is fine)
    2. Weather condition icon (sun, cloud, rain)
    3. Location name
    4. High/Low temperatures
    5. Simple, clean design

    ## Current State
    - `WeatherData.swift` has the model
    - `WeatherView.swift` needs the UI

    ## Your Task
    Build a visually appealing weather widget UI. Use SF Symbols for weather icons.
    Use mock data for now - no API calls needed.

    When you're done, output "RALPH_COMPLETE".

    Make it look nice! Use gradients, proper spacing, and good typography.
    """

    private static let weatherWidgetStarterFiles: [String: String] = [
        "Sources/WeatherData.swift": """
        import Foundation

        struct WeatherData {
            let location: String
            let temperature: Int
            let highTemp: Int
            let lowTemp: Int
            let condition: WeatherCondition

            enum WeatherCondition: String {
                case sunny = "sun.max.fill"
                case cloudy = "cloud.fill"
                case rainy = "cloud.rain.fill"
                case stormy = "cloud.bolt.fill"
                case snowy = "cloud.snow.fill"
            }

            static let mock = WeatherData(
                location: "San Francisco",
                temperature: 68,
                highTemp: 72,
                lowTemp: 58,
                condition: .sunny
            )
        }
        """,

        "Sources/WeatherView.swift": """
        import SwiftUI

        struct WeatherView: View {
            let weather = WeatherData.mock

            var body: some View {
                VStack {
                    Text("Weather Widget")
                        .font(.title)

                    // TODO: Build the weather display

                    Spacer()
                }
                .padding()
            }
        }

        #Preview {
            WeatherView()
                .frame(width: 300, height: 400)
        }
        """,

        "Package.swift": """
        // swift-tools-version: 5.9
        import PackageDescription

        let package = Package(
            name: "WeatherWidget",
            platforms: [.macOS(.v14)],
            targets: [
                .executableTarget(name: "WeatherWidget", path: "Sources")
            ]
        )
        """
    ]
}
