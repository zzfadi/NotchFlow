# Apple Intelligence Studio - Native iOS/macOS App

## Executive Summary

A native Swift application for **iOS and macOS** that provides a comprehensive playground for Apple's Foundation Models framework and Apple Intelligence features. The app enables developers to explore, test, and prototype with Apple's on-device AI capabilities, including an experimental App Builder feature for generating SwiftUI code.

**Key Differentiator:** Deep integration with Apple's exclusive AI features — Foundation Models, Writing Tools, Image Playground, and Siri/Shortcuts.

---

## Project Overview

| Aspect | Details |
|--------|---------|
| **Platform** | iOS 26+ / iPadOS 26+ / macOS 26+ |
| **Language** | Swift 6 / SwiftUI |
| **AI Engine** | Apple Foundation Models (~3B on-device LLM) |
| **Cost** | **Free inference** (no API costs) |
| **Distribution** | App Store |
| **Target Users** | Apple developers, iOS/macOS app creators |

---

## 1. Apple Intelligence Capabilities

### What Apple Provides (iOS 26+)

| Feature | Description | Developer Access |
|---------|-------------|------------------|
| **Foundation Models** | ~3B parameter on-device LLM | `FoundationModels` framework |
| **Guided Generation** | Type-safe structured outputs | `@Generable` macro |
| **Tool Calling** | Function calling from LLM | Built-in support |
| **Writing Tools** | Proofread, rewrite, summarize | System integration |
| **Image Playground** | On-device image generation | `ImagePlayground` framework |
| **Private Cloud Compute** | Larger models for complex tasks | Automatic routing |
| **Siri Integration** | Voice-activated features | App Intents |

### Foundation Models Specifications

| Spec | Details |
|------|---------|
| **Model Size** | ~3 billion parameters |
| **Context Window** | 4,096 tokens (flexible split) |
| **Inference Cost** | Free (unlimited) |
| **Latency** | ~45ms typical response start |
| **Speed** | 20-30 tokens/second on-device |
| **Languages** | English, French, German, Italian, Portuguese, Spanish, Chinese, Japanese, Korean |

### Supported Devices

| Platform | Minimum Device |
|----------|----------------|
| **iPhone** | iPhone 15 Pro, iPhone 16 series |
| **iPad** | Any iPad with M1 or later |
| **Mac** | Any Mac with Apple Silicon (M1+) |

---

## 2. Technology Stack

### Core Technologies

```
┌─────────────────────────────────────────────────────────────────┐
│                    APPLE INTELLIGENCE STUDIO                     │
├─────────────────────────────────────────────────────────────────┤
│  UI Framework      │ SwiftUI (iOS 26+)                          │
│  Architecture      │ The Composable Architecture (TCA)          │
│  Language          │ Swift 6                                    │
│  Concurrency       │ Swift Concurrency (async/await)            │
├─────────────────────────────────────────────────────────────────┤
│  APPLE FRAMEWORKS                                                │
│  • FoundationModels - On-device LLM                             │
│  • AppIntents - Siri & Shortcuts                                │
│  • ImagePlayground - Image generation                           │
│  • WritingTools - Text transformation                           │
│  • NaturalLanguage - Text analysis                              │
├─────────────────────────────────────────────────────────────────┤
│  THIRD-PARTY                                                     │
│  • swift-composable-architecture (TCA)                          │
│  • swift-markdown-ui                                            │
│  • SwiftAI (optional multi-provider)                            │
└─────────────────────────────────────────────────────────────────┘
```

---

## 3. Core Features

### 3.1 Foundation Models Playground

The primary feature — an interactive environment for testing Apple's on-device LLM.

```
┌─────────────────────────────────────────────────────────────────┐
│  🧠 FOUNDATION MODELS PLAYGROUND                                 │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Task Type: [Free Text ▼]                                       │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │ Other options:                                               ││
│  │ • Summarization                                              ││
│  │ • Entity Extraction                                          ││
│  │ • Classification                                             ││
│  │ • Question Answering                                         ││
│  │ • Text Refinement                                            ││
│  │ • Creative Writing                                           ││
│  └─────────────────────────────────────────────────────────────┘│
│                                                                  │
│  Input:                                                          │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │ Summarize the key points of this article about climate      ││
│  │ change and its effects on global agriculture...             ││
│  │                                                              ││
│  └─────────────────────────────────────────────────────────────┘│
│                                                                  │
│  ☑ Use Guided Generation                                        │
│  Output Type: [Summary ▼]                                       │
│                                                                  │
│  [▶ Generate]                           [⚙️ Settings]            │
│                                                                  │
├─────────────────────────────────────────────────────────────────┤
│  📊 RESPONSE                                                     │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │ {                                                            ││
│  │   "mainPoints": [                                            ││
│  │     "Rising temperatures affect crop yields",                ││
│  │     "Water scarcity impacts irrigation",                     ││
│  │     "Shifting seasons disrupt planting cycles"               ││
│  │   ],                                                         ││
│  │   "sentiment": "concerned",                                  ││
│  │   "wordCount": 342                                           ││
│  │ }                                                            ││
│  │                                                              ││
│  │ ⚡ 38ms • On-Device • 156 tokens                             ││
│  └─────────────────────────────────────────────────────────────┘│
│                                                                  │
│  [📋 Copy] [📤 Share] [💾 Save to History]                       │
└─────────────────────────────────────────────────────────────────┘
```

**Features:**
- Free-form text generation
- Pre-built task templates (summarize, extract, classify, etc.)
- Guided generation with custom Swift types
- Streaming response display
- Performance metrics
- Response history
- Export/share results

### 3.2 Guided Generation Builder

Create custom `@Generable` types visually and test them.

```
┌─────────────────────────────────────────────────────────────────┐
│  🎯 GUIDED GENERATION BUILDER                                    │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Type Name: MovieReview                                         │
│                                                                  │
│  FIELDS                                                          │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │ + sentiment: String                                          ││
│  │   Guide: "Sentiment: positive, negative, or neutral"         ││
│  │                                                              ││
│  │ + rating: Int                                                ││
│  │   Guide: "Rating from 1 to 5 stars"                          ││
│  │                                                              ││
│  │ + summary: String                                            ││
│  │   Guide: "A brief 1-2 sentence summary"                      ││
│  │                                                              ││
│  │ [+ Add Field]                                                ││
│  └─────────────────────────────────────────────────────────────┘│
│                                                                  │
│  GENERATED SWIFT CODE                                            │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │ @Generable                                                   ││
│  │ struct MovieReview {                                         ││
│  │     @Guide(description: "Sentiment: positive...")            ││
│  │     var sentiment: String                                    ││
│  │                                                              ││
│  │     @Guide(description: "Rating from 1 to 5 stars")          ││
│  │     var rating: Int                                          ││
│  │                                                              ││
│  │     @Guide(description: "A brief 1-2 sentence summary")      ││
│  │     var summary: String                                      ││
│  │ }                                                            ││
│  └─────────────────────────────────────────────────────────────┘│
│                                                                  │
│  [📋 Copy Code] [🧪 Test Type] [💾 Save Template]                │
└─────────────────────────────────────────────────────────────────┘
```

**Features:**
- Visual type builder
- Live Swift code generation
- Test with sample inputs
- Save and reuse templates
- Export to Xcode

### 3.3 Tool Calling Playground

Test the LLM's ability to call functions and tools.

```
┌─────────────────────────────────────────────────────────────────┐
│  🔧 TOOL CALLING                                                 │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  AVAILABLE TOOLS                                                 │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │ ☑ getWeather(location: String) -> WeatherInfo               ││
│  │ ☑ searchWeb(query: String) -> [SearchResult]                ││
│  │ ☑ calculateMath(expression: String) -> Double               ││
│  │ ☐ sendEmail(to: String, subject: String, body: String)      ││
│  │                                                              ││
│  │ [+ Add Custom Tool]                                          ││
│  └─────────────────────────────────────────────────────────────┘│
│                                                                  │
│  USER PROMPT                                                     │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │ What's the weather like in San Francisco today?             ││
│  └─────────────────────────────────────────────────────────────┘│
│                                                                  │
│  [▶ Run]                                                         │
│                                                                  │
├─────────────────────────────────────────────────────────────────┤
│  EXECUTION LOG                                                   │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │ 1. LLM identified tool: getWeather                          ││
│  │ 2. Arguments: { location: "San Francisco" }                 ││
│  │ 3. Tool executed → { temp: 68, condition: "Partly Cloudy" } ││
│  │ 4. LLM response: "It's currently 68°F and partly cloudy..." ││
│  │                                                              ││
│  │ ⚡ Total: 125ms • 2 LLM calls                                ││
│  └─────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────┘
```

### 3.4 Writing Tools Integration

Test Apple's Writing Tools API with custom text.

```
┌─────────────────────────────────────────────────────────────────┐
│  ✍️ WRITING TOOLS                                                │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  INPUT TEXT                                                      │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │ The product is really good and I think everyone should buy  ││
│  │ it because its amazing. Their are many reasons why this is  ││
│  │ the best product on the market and you wont regret it.      ││
│  └─────────────────────────────────────────────────────────────┘│
│                                                                  │
│  TRANSFORMATION                                                  │
│  [Proofread] [Rewrite] [Friendly] [Professional] [Concise]      │
│                                                                  │
├─────────────────────────────────────────────────────────────────┤
│  OUTPUT                                                          │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │ This product is excellent, and I highly recommend it.       ││
│  │ There are many compelling reasons why it stands out as      ││
│  │ the best option on the market—you won't be disappointed.    ││
│  │                                                              ││
│  │ Changes:                                                     ││
│  │ • Fixed "Their" → "There"                                   ││
│  │ • Fixed "its" → "it's" (contraction)                        ││
│  │ • Fixed "wont" → "won't"                                    ││
│  │ • Improved overall clarity and flow                         ││
│  └─────────────────────────────────────────────────────────────┘│
│                                                                  │
│  [📋 Copy] [↩️ Undo] [Compare Versions]                          │
└─────────────────────────────────────────────────────────────────┘
```

### 3.5 Image Playground

Test Apple's on-device image generation.

```
┌─────────────────────────────────────────────────────────────────┐
│  🎨 IMAGE PLAYGROUND                                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  PROMPT                                                          │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │ A cozy cabin in the mountains during autumn                 ││
│  └─────────────────────────────────────────────────────────────┘│
│                                                                  │
│  STYLE: [Animation ▼]  [Illustration]  [Sketch]                 │
│                                                                  │
│  [▶ Generate Image]                                              │
│                                                                  │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │                                                              ││
│  │              [Generated Image Preview]                       ││
│  │                                                              ││
│  │                                                              ││
│  └─────────────────────────────────────────────────────────────┘│
│                                                                  │
│  ⚡ Generated in 2.3s • On-Device                                │
│                                                                  │
│  [💾 Save] [📤 Share] [🔄 Regenerate] [✏️ Edit Prompt]            │
└─────────────────────────────────────────────────────────────────┘
```

### 3.6 App Builder (Experimental)

Generate SwiftUI code from natural language descriptions.

```
┌─────────────────────────────────────────────────────────────────┐
│  🛠️ APP BUILDER (Experimental)                                   │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  DESCRIBE YOUR APP                                               │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │ Create a todo list app with:                                ││
│  │ - A list of tasks with checkboxes                           ││
│  │ - An add button to create new tasks                         ││
│  │ - Swipe to delete functionality                             ││
│  │ - A simple header with the app name                         ││
│  └─────────────────────────────────────────────────────────────┘│
│                                                                  │
│  COMPONENT TYPE: [Full View ▼]                                   │
│  Other: Single Component | View Modifier | Data Model           │
│                                                                  │
│  [▶ Generate Code]                                               │
│                                                                  │
├─────────────────────────────────────────────────────────────────┤
│  GENERATED CODE                           LIVE PREVIEW          │
│  ┌──────────────────────────────┐ ┌────────────────────────────┐│
│  │ struct TodoListView: View {  │ │  ┌────────────────────┐   ││
│  │   @State private var tasks   │ │  │    My Todo List    │   ││
│  │     = [Task]()               │ │  ├────────────────────┤   ││
│  │                              │ │  │ ☑ Buy groceries    │   ││
│  │   var body: some View {      │ │  │ ☐ Call mom         │   ││
│  │     NavigationStack {        │ │  │ ☐ Finish project   │   ││
│  │       List {                 │ │  │                    │   ││
│  │         ForEach(tasks) {     │ │  │     [+ Add Task]   │   ││
│  │           TaskRow(task: $0)  │ │  └────────────────────┘   ││
│  │         }                    │ │                            ││
│  │         .onDelete(perform:   │ │  iPhone 16 Pro Preview    ││
│  │           deleteTask)        │ │                            ││
│  │       }                      │ └────────────────────────────┘│
│  │       ...                    │                               │
│  │     }                        │                               │
│  │   }                          │                               │
│  │ }                            │                               │
│  └──────────────────────────────┘                               │
│                                                                  │
│  [📋 Copy] [📁 Export to Xcode] [🔄 Iterate] [💬 Refine]          │
└─────────────────────────────────────────────────────────────────┘
```

**Realistic Capabilities (3B Model):**
- Simple SwiftUI views and components ✅
- Basic CRUD interfaces ✅
- Standard UI patterns (lists, forms, navigation) ✅
- Simple data models ✅
- Basic animations ✅

**Limitations:**
- Complex business logic ⚠️
- Multi-screen navigation flows ⚠️
- Network/API integration code ⚠️
- Production-ready apps ❌

**Enhancement Options:**
- Use Private Cloud Compute for complex requests
- Integrate cloud LLMs (Claude, GPT-4) for advanced generation
- Template-based scaffolding for common patterns

### 3.7 Benchmarks & Diagnostics

```
┌─────────────────────────────────────────────────────────────────┐
│  📊 BENCHMARKS                                                   │
├─────────────────────────────────────────────────────────────────┤
│  DEVICE INFO                                                    │
│  • Device: iPhone 16 Pro                                        │
│  • Chip: A18 Pro                                                │
│  • RAM: 8 GB                                                    │
│  • iOS: 26.0                                                    │
│  • Apple Intelligence: Enabled ✓                                │
├─────────────────────────────────────────────────────────────────┤
│  FOUNDATION MODELS PERFORMANCE                                   │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │ Text Generation (100 tokens)                                ││
│  │ • First token latency: 42ms                                 ││
│  │ • Generation speed: 28 tok/s                                ││
│  │ • Total time: 3.6s                                          ││
│  │                                                              ││
│  │ Guided Generation (MovieReview)                             ││
│  │ • Parse + Generate: 156ms                                   ││
│  │ • Validation: Pass ✓                                        ││
│  │                                                              ││
│  │ Tool Calling (3 tools)                                      ││
│  │ • Tool selection: 38ms                                      ││
│  │ • Full round-trip: 245ms                                    ││
│  └─────────────────────────────────────────────────────────────┘│
├─────────────────────────────────────────────────────────────────┤
│  [Run All Benchmarks] [Export Report] [Compare Devices]         │
└─────────────────────────────────────────────────────────────────┘
```

---

## 4. App Architecture

### Directory Structure

```
AppleIntelligenceStudio/
├── Sources/
│   ├── App/
│   │   ├── AppleIntelligenceStudioApp.swift
│   │   ├── AppDelegate.swift
│   │   └── ContentView.swift
│   │
│   ├── Features/
│   │   ├── FoundationModels/
│   │   │   ├── FoundationModelsView.swift
│   │   │   ├── FoundationModelsFeature.swift  # TCA Reducer
│   │   │   ├── TaskTemplates/
│   │   │   │   ├── SummarizationTemplate.swift
│   │   │   │   ├── ExtractionTemplate.swift
│   │   │   │   └── ClassificationTemplate.swift
│   │   │   └── Components/
│   │   │       ├── PromptEditor.swift
│   │   │       ├── ResponseView.swift
│   │   │       └── MetricsView.swift
│   │   │
│   │   ├── GuidedGeneration/
│   │   │   ├── GuidedGenerationView.swift
│   │   │   ├── GuidedGenerationFeature.swift
│   │   │   ├── TypeBuilder/
│   │   │   │   ├── TypeBuilderView.swift
│   │   │   │   └── FieldEditor.swift
│   │   │   └── Models/
│   │   │       └── GenerableTypes.swift
│   │   │
│   │   ├── ToolCalling/
│   │   │   ├── ToolCallingView.swift
│   │   │   ├── ToolCallingFeature.swift
│   │   │   └── BuiltInTools/
│   │   │       ├── WeatherTool.swift
│   │   │       ├── CalculatorTool.swift
│   │   │       └── SearchTool.swift
│   │   │
│   │   ├── WritingTools/
│   │   │   ├── WritingToolsView.swift
│   │   │   ├── WritingToolsFeature.swift
│   │   │   └── Transformations.swift
│   │   │
│   │   ├── ImagePlayground/
│   │   │   ├── ImagePlaygroundView.swift
│   │   │   └── ImagePlaygroundFeature.swift
│   │   │
│   │   ├── AppBuilder/
│   │   │   ├── AppBuilderView.swift
│   │   │   ├── AppBuilderFeature.swift
│   │   │   ├── CodeGenerator/
│   │   │   │   ├── CodeGeneratorService.swift
│   │   │   │   ├── SwiftUITemplates.swift
│   │   │   │   └── CodeFormatter.swift
│   │   │   ├── Preview/
│   │   │   │   ├── LivePreviewView.swift
│   │   │   │   └── PreviewRenderer.swift
│   │   │   └── Export/
│   │   │       └── XcodeExporter.swift
│   │   │
│   │   ├── Benchmarks/
│   │   │   ├── BenchmarksView.swift
│   │   │   ├── BenchmarksFeature.swift
│   │   │   └── BenchmarkRunner.swift
│   │   │
│   │   └── Settings/
│   │       ├── SettingsView.swift
│   │       └── SettingsFeature.swift
│   │
│   ├── Core/
│   │   ├── Services/
│   │   │   ├── FoundationModelService.swift
│   │   │   ├── ImagePlaygroundService.swift
│   │   │   └── ExportService.swift
│   │   │
│   │   ├── Models/
│   │   │   ├── PromptHistory.swift
│   │   │   ├── BenchmarkResult.swift
│   │   │   └── GeneratedCode.swift
│   │   │
│   │   └── Extensions/
│   │       ├── LanguageModelSession+Extensions.swift
│   │       └── View+Extensions.swift
│   │
│   ├── AppIntents/
│   │   ├── SummarizeIntent.swift
│   │   ├── GenerateCodeIntent.swift
│   │   └── AppShortcuts.swift
│   │
│   └── Shared/
│       ├── Components/
│       │   ├── CodeEditor.swift
│       │   ├── MarkdownView.swift
│       │   └── LoadingIndicator.swift
│       └── Theme/
│           └── AppTheme.swift
│
├── Tests/
│   ├── FoundationModelsTests/
│   ├── AppBuilderTests/
│   └── BenchmarkTests/
│
├── Resources/
│   ├── Assets.xcassets
│   └── Localizable.strings
│
└── Package.swift
```

### TCA Architecture

```swift
// Example: FoundationModelsFeature.swift
import ComposableArchitecture
import FoundationModels

@Reducer
struct FoundationModelsFeature {
    @ObservableState
    struct State: Equatable {
        var prompt: String = ""
        var response: String = ""
        var isGenerating: Bool = false
        var selectedTask: TaskType = .freeText
        var metrics: GenerationMetrics?
        var error: String?
    }

    enum Action {
        case promptChanged(String)
        case taskTypeSelected(TaskType)
        case generateTapped
        case responseReceived(String)
        case metricsReceived(GenerationMetrics)
        case errorOccurred(String)
        case clearTapped
    }

    @Dependency(\.foundationModelService) var modelService

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .generateTapped:
                state.isGenerating = true
                state.response = ""
                let prompt = state.prompt

                return .run { send in
                    let startTime = Date()
                    do {
                        let response = try await modelService.generate(prompt: prompt)
                        await send(.responseReceived(response))

                        let metrics = GenerationMetrics(
                            latency: Date().timeIntervalSince(startTime),
                            tokenCount: response.split(separator: " ").count
                        )
                        await send(.metricsReceived(metrics))
                    } catch {
                        await send(.errorOccurred(error.localizedDescription))
                    }
                }

            case let .responseReceived(response):
                state.response = response
                state.isGenerating = false
                return .none

            // ... other cases
            }
        }
    }
}
```

---

## 5. Technical Implementation

### 5.1 Foundation Models Integration

```swift
import FoundationModels

class FoundationModelService {
    private var session: LanguageModelSession?

    func createSession() async throws {
        guard SystemLanguageModel.isAvailable else {
            throw ModelError.notAvailable
        }
        session = LanguageModelSession()
    }

    // Simple text generation
    func generate(prompt: String) async throws -> String {
        guard let session else { throw ModelError.noSession }
        return try await session.respond(to: prompt)
    }

    // Streaming generation
    func generateStream(prompt: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                guard let session else {
                    continuation.finish(throwing: ModelError.noSession)
                    return
                }

                do {
                    for try await token in session.streamResponse(to: prompt) {
                        continuation.yield(token)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // Guided generation with type safety
    func generateStructured<T: Generable>(
        prompt: String,
        as type: T.Type
    ) async throws -> T {
        guard let session else { throw ModelError.noSession }
        return try await session.respond(to: prompt, as: type)
    }
}
```

### 5.2 Guided Generation Types

```swift
import FoundationModels

// Movie Review
@Generable
struct MovieReview {
    @Guide(description: "Sentiment: positive, negative, or neutral")
    var sentiment: String

    @Guide(description: "Rating from 1 to 5 stars")
    var rating: Int

    @Guide(description: "A brief 1-2 sentence summary of the review")
    var summary: String

    @Guide(description: "Key themes mentioned in the review")
    var themes: [String]
}

// Article Summary
@Generable
struct ArticleSummary {
    @Guide(description: "Main points of the article as bullet points")
    var mainPoints: [String]

    @Guide(description: "The overall tone: informative, persuasive, neutral, or critical")
    var tone: String

    @Guide(description: "Estimated reading time in minutes")
    var readingTime: Int

    @Guide(description: "Key entities mentioned (people, organizations, places)")
    var entities: [String]
}

// Code Generation Request
@Generable
struct SwiftUIComponent {
    @Guide(description: "The SwiftUI view code")
    var code: String

    @Guide(description: "Brief explanation of the component")
    var explanation: String

    @Guide(description: "Any required imports beyond SwiftUI")
    var additionalImports: [String]
}
```

### 5.3 Tool Calling Implementation

```swift
import FoundationModels

// Define tools
struct WeatherTool: Tool {
    static let definition = ToolDefinition(
        name: "getWeather",
        description: "Get the current weather for a location",
        parameters: [
            .init(name: "location", type: .string, description: "City name")
        ]
    )

    func execute(arguments: [String: Any]) async throws -> String {
        guard let location = arguments["location"] as? String else {
            throw ToolError.invalidArguments
        }
        // Simulate weather API call
        return """
        {
            "location": "\(location)",
            "temperature": 72,
            "condition": "Sunny",
            "humidity": 45
        }
        """
    }
}

// Tool calling session
class ToolCallingService {
    private var session: LanguageModelSession?
    private var tools: [any Tool] = []

    func registerTool(_ tool: any Tool) {
        tools.append(tool)
    }

    func processWithTools(prompt: String) async throws -> ToolCallingResult {
        guard let session else { throw ModelError.noSession }

        var result = ToolCallingResult()
        result.userPrompt = prompt

        // Get tool call from LLM
        let toolCall = try await session.respond(
            to: prompt,
            tools: tools.map(\.definition)
        )

        if let selectedTool = toolCall.toolName,
           let tool = tools.first(where: { $0.name == selectedTool }) {

            result.selectedTool = selectedTool
            result.arguments = toolCall.arguments

            // Execute tool
            let toolResult = try await tool.execute(arguments: toolCall.arguments)
            result.toolOutput = toolResult

            // Get final response with tool result
            let finalResponse = try await session.respond(
                to: "Tool result: \(toolResult). Please provide a natural response."
            )
            result.finalResponse = finalResponse
        }

        return result
    }
}
```

### 5.4 App Builder Code Generator

```swift
class CodeGeneratorService {
    private let modelService: FoundationModelService

    func generateSwiftUICode(from description: String) async throws -> GeneratedCode {
        let prompt = """
        Generate SwiftUI code for the following app description.
        Return only valid Swift code that compiles.

        Description: \(description)

        Requirements:
        - Use SwiftUI best practices
        - Include @State for any mutable data
        - Use NavigationStack for navigation
        - Add appropriate spacing and padding
        - Include comments explaining key parts
        """

        let result: SwiftUIComponent = try await modelService.generateStructured(
            prompt: prompt,
            as: SwiftUIComponent.self
        )

        return GeneratedCode(
            code: result.code,
            explanation: result.explanation,
            imports: result.additionalImports
        )
    }

    func iterateOnCode(
        currentCode: String,
        feedback: String
    ) async throws -> GeneratedCode {
        let prompt = """
        Modify this SwiftUI code based on the feedback.

        Current code:
        ```swift
        \(currentCode)
        ```

        Feedback: \(feedback)

        Return the updated code.
        """

        let result: SwiftUIComponent = try await modelService.generateStructured(
            prompt: prompt,
            as: SwiftUIComponent.self
        )

        return GeneratedCode(
            code: result.code,
            explanation: result.explanation,
            imports: result.additionalImports
        )
    }
}
```

### 5.5 Xcode Export

```swift
import Foundation

class XcodeExporter {
    func exportProject(
        name: String,
        code: GeneratedCode,
        to directory: URL
    ) throws {
        // Create project structure
        let projectDir = directory.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: projectDir, withIntermediateDirectories: true)

        // Create Swift file
        let swiftFile = projectDir.appendingPathComponent("\(name)View.swift")
        let fullCode = """
        import SwiftUI
        \(code.imports.map { "import \($0)" }.joined(separator: "\n"))

        \(code.code)

        #Preview {
            \(name)View()
        }
        """
        try fullCode.write(to: swiftFile, atomically: true, encoding: .utf8)

        // Create Package.swift for SPM
        let packageSwift = """
        // swift-tools-version: 5.9
        import PackageDescription

        let package = Package(
            name: "\(name)",
            platforms: [.iOS(.v17), .macOS(.v14)],
            products: [
                .library(name: "\(name)", targets: ["\(name)"]),
            ],
            targets: [
                .target(name: "\(name)"),
            ]
        )
        """
        try packageSwift.write(
            to: projectDir.appendingPathComponent("Package.swift"),
            atomically: true,
            encoding: .utf8
        )
    }
}
```

---

## 6. App Intents (Siri & Shortcuts)

```swift
import AppIntents

struct SummarizeTextIntent: AppIntent {
    static var title: LocalizedStringResource = "Summarize Text"
    static var description = IntentDescription("Summarizes the provided text using Apple Intelligence")

    @Parameter(title: "Text to Summarize")
    var text: String

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let service = FoundationModelService()
        try await service.createSession()

        let summary: ArticleSummary = try await service.generateStructured(
            prompt: "Summarize this text: \(text)",
            as: ArticleSummary.self
        )

        return .result(value: summary.mainPoints.joined(separator: "\n"))
    }
}

struct AppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: SummarizeTextIntent(),
            phrases: [
                "Summarize with \(.applicationName)",
                "Use \(.applicationName) to summarize"
            ],
            shortTitle: "Summarize",
            systemImageName: "text.alignleft"
        )
    }
}
```

---

## 7. Requirements

### Device Requirements

| Requirement | Minimum |
|-------------|---------|
| **iOS** | 26.0+ |
| **iPadOS** | 26.0+ |
| **macOS** | 26.0+ |
| **iPhone** | iPhone 15 Pro or later |
| **iPad** | Any iPad with M1 or later |
| **Mac** | Any Mac with Apple Silicon |
| **Apple Intelligence** | Must be enabled in Settings |

### Development Requirements

| Tool | Version |
|------|---------|
| **Xcode** | 26.0+ |
| **Swift** | 6.0+ |
| **macOS (dev)** | 26.0+ |

---

## 8. Dependencies

```swift
// Package.swift
import PackageDescription

let package = Package(
    name: "AppleIntelligenceStudio",
    platforms: [
        .iOS(.v26),
        .macOS(.v26)
    ],
    products: [
        .library(name: "AppleIntelligenceStudio", targets: ["AppleIntelligenceStudio"]),
    ],
    dependencies: [
        // Architecture
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", from: "1.15.0"),

        // UI
        .package(url: "https://github.com/gonzalezreal/swift-markdown-ui", from: "2.4.0"),

        // Syntax Highlighting
        .package(url: "https://github.com/raspu/Highlightr", from: "2.2.0"),

        // Optional: Multi-provider AI support
        .package(url: "https://github.com/mi12labs/SwiftAI", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "AppleIntelligenceStudio",
            dependencies: [
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "MarkdownUI", package: "swift-markdown-ui"),
                .product(name: "Highlightr", package: "Highlightr"),
            ]
        ),
        .testTarget(
            name: "AppleIntelligenceStudioTests",
            dependencies: ["AppleIntelligenceStudio"]
        ),
    ]
)
```

---

## 9. Implementation Phases

### Phase 1: Foundation (2-3 weeks)
- [ ] Project setup with TCA architecture
- [ ] Basic app navigation (TabView)
- [ ] Foundation Models service wrapper
- [ ] Simple text generation UI
- [ ] Response streaming display
- [ ] Basic error handling

### Phase 2: Guided Generation (2-3 weeks)
- [ ] Visual type builder UI
- [ ] Pre-built @Generable templates
- [ ] Swift code generation display
- [ ] Test with sample inputs
- [ ] Save/load custom types
- [ ] Copy code functionality

### Phase 3: Tool Calling & Writing Tools (2-3 weeks)
- [ ] Tool calling playground
- [ ] Built-in demo tools (weather, calculator, search)
- [ ] Custom tool definition UI
- [ ] Execution log display
- [ ] Writing Tools integration
- [ ] Text transformation UI

### Phase 4: App Builder (4-6 weeks)
- [ ] Natural language input for app descriptions
- [ ] Code generation with Foundation Models
- [ ] Live SwiftUI preview
- [ ] Iteration/refinement workflow
- [ ] Xcode project export
- [ ] Template library for common patterns

### Phase 5: Polish & Advanced (3-4 weeks)
- [ ] Image Playground integration
- [ ] Comprehensive benchmarking
- [ ] App Intents / Siri Shortcuts
- [ ] Settings and preferences
- [ ] History and favorites
- [ ] App Store preparation

---

## 10. Error Handling

```swift
enum AppleIntelligenceError: LocalizedError {
    case deviceNotSupported
    case appleIntelligenceDisabled
    case modelNotReady
    case generationFailed(underlying: Error)
    case invalidResponse
    case exportFailed(reason: String)

    var errorDescription: String? {
        switch self {
        case .deviceNotSupported:
            return "This device doesn't support Apple Intelligence. Requires iPhone 15 Pro or later, iPad with M1, or Mac with Apple Silicon."
        case .appleIntelligenceDisabled:
            return "Apple Intelligence is not enabled. Please enable it in Settings > Apple Intelligence & Siri."
        case .modelNotReady:
            return "The language model is still downloading. Please wait and try again."
        case .generationFailed(let error):
            return "Generation failed: \(error.localizedDescription)"
        case .invalidResponse:
            return "Received an invalid response from the model."
        case .exportFailed(let reason):
            return "Export failed: \(reason)"
        }
    }
}
```

---

## 11. Privacy & Security

- **100% on-device processing** for Foundation Models
- No user data sent to external servers
- Private Cloud Compute (when used) has end-to-end encryption
- No API keys required
- No analytics or tracking
- Generated code stays local unless explicitly exported

---

## References

### Official Apple Documentation
- [Apple Intelligence Developer Portal](https://developer.apple.com/apple-intelligence/)
- [Foundation Models Documentation](https://developer.apple.com/documentation/foundationmodels)
- [Meet the Foundation Models Framework (WWDC25)](https://developer.apple.com/videos/play/wwdc2025/286/)
- [Code-along: Foundation Models (WWDC25)](https://developer.apple.com/videos/play/wwdc2025/259/)
- [Acceptable Use Requirements](https://developer.apple.com/apple-intelligence/acceptable-use-requirements-for-the-foundation-models-framework/)

### Research & Technical Details
- [Apple Foundation Models Research](https://machinelearning.apple.com/research/introducing-apple-foundation-models)
- [Foundation Models Tech Report 2025](https://machinelearning.apple.com/research/apple-foundation-models-tech-report-2025)
- [Private Cloud Compute Security](https://security.apple.com/blog/private-cloud-compute/)

### Community Resources
- [Exploring Foundation Models Framework](https://www.createwithswift.com/exploring-the-foundation-models-framework/)
- [Foundation Models Tutorial](https://www.iphonedevelopers.co.uk/2025/07/apple-foundation-models-ios-tutorial.html)
- [SwiftAI Multi-Provider Library](https://github.com/mi12labs/SwiftAI)

### Third-Party Libraries
- [The Composable Architecture](https://github.com/pointfreeco/swift-composable-architecture)
- [MarkdownUI](https://github.com/gonzalezreal/swift-markdown-ui)
- [Highlightr](https://github.com/raspu/Highlightr)
