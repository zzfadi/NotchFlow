import SwiftUI

struct RalphWiggumView: View {
    @StateObject private var loopManager = LoopManager.shared
    @ObservedObject private var settings = SettingsManager.shared
    @State private var showingNewLoopSheet = false
    @State private var showingTemplateGallery = false
    @State private var showingAchievements = false
    @State private var selectedLoop: RalphLoop?

    var body: some View {
        HSplitView {
            // Left: Loop list and Ralph character
            VStack(spacing: 0) {
                // Ralph character header
                RalphCharacterCard(state: loopManager.currentState)
                    .padding()

                Divider()

                // Loop list
                if loopManager.loops.isEmpty {
                    emptyStateView
                } else {
                    loopListView
                }

                Divider()

                // Bottom toolbar
                bottomToolbar
            }
            .frame(minWidth: 200, idealWidth: 280, maxWidth: 320)

            // Right: Selected loop detail or placeholder
            if let loop = selectedLoop ?? loopManager.loops.first {
                LoopDetailView(loop: binding(for: loop))
            } else {
                emptyDetailView
            }
        }
        .sheet(isPresented: $showingNewLoopSheet) {
            NewLoopSheet(isPresented: $showingNewLoopSheet)
        }
        .sheet(isPresented: $showingTemplateGallery) {
            TemplateGallerySheet(isPresented: $showingTemplateGallery)
        }
        .sheet(isPresented: $showingAchievements) {
            AchievementsSheet(isPresented: $showingAchievements)
        }
    }

    // MARK: - Subviews

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "repeat.circle")
                .font(.system(size: 40))
                .foregroundColor(.gray.opacity(0.5))
            Text("No Ralph Loops")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("Create a loop to start autonomous AI coding")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("Create Loop") {
                showingNewLoopSheet = true
            }
            .buttonStyle(.borderedProminent)
            .tint(settings.accentColor)
            Spacer()
        }
        .padding()
    }

    private var loopListView: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(loopManager.loops) { loop in
                    LoopRowView(
                        loop: loop,
                        isSelected: selectedLoop?.id == loop.id
                    )
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedLoop = loop
                        }
                    }
                    .contextMenu {
                        loopContextMenu(for: loop)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }

    private var emptyDetailView: some View {
        VStack(spacing: 16) {
            Image(systemName: "arrow.left.circle")
                .font(.system(size: 48))
                .foregroundColor(.gray.opacity(0.3))
            Text("Select a loop or create a new one")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var bottomToolbar: some View {
        HStack(spacing: 12) {
            Button {
                showingNewLoopSheet = true
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 16))
            }
            .buttonStyle(.plain)
            .foregroundColor(settings.accentColor)
            .help("New Loop")

            Button {
                showingTemplateGallery = true
            } label: {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 14))
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
            .help("Template Gallery")

            Spacer()

            // Stats
            if !loopManager.loops.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "number")
                        .font(.system(size: 10))
                    Text("\(loopManager.totalIterations)")
                        .font(.caption2)
                }
                .foregroundColor(.secondary)
            }

            Button {
                showingAchievements = true
            } label: {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 14))
            }
            .buttonStyle(.plain)
            .foregroundColor(.yellow)
            .help("Achievements")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func loopContextMenu(for loop: RalphLoop) -> some View {
        if loop.status == .running {
            Button {
                Task { await loopManager.pauseLoop(loop.id) }
            } label: {
                Label("Pause", systemImage: "pause.fill")
            }

            Button {
                Task { await loopManager.stopLoop(loop.id) }
            } label: {
                Label("Stop", systemImage: "stop.fill")
            }
        } else if loop.status == .paused {
            Button {
                Task { await loopManager.resumeLoop(loop.id) }
            } label: {
                Label("Resume", systemImage: "play.fill")
            }

            Button {
                Task { await loopManager.stopLoop(loop.id) }
            } label: {
                Label("Stop", systemImage: "stop.fill")
            }
        } else {
            Button {
                Task { await loopManager.startLoop(loop.id) }
            } label: {
                Label("Start", systemImage: "play.fill")
            }
        }

        Divider()

        Button {
            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: loop.projectPath.path)
        } label: {
            Label("Show in Finder", systemImage: "folder")
        }

        Button {
            NSWorkspace.shared.open(URL(string: "vscode://file\(loop.projectPath.path)")!)
        } label: {
            Label("Open in VS Code", systemImage: "chevron.left.forwardslash.chevron.right")
        }

        Divider()

        Button(role: .destructive) {
            loopManager.deleteLoop(loop.id)
            if selectedLoop?.id == loop.id {
                selectedLoop = nil
            }
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    // MARK: - Helpers

    private func binding(for loop: RalphLoop) -> Binding<RalphLoop> {
        Binding(
            get: { loopManager.loops.first { $0.id == loop.id } ?? loop },
            set: { loopManager.updateLoop($0) }
        )
    }
}

// MARK: - Ralph Character Card

struct RalphCharacterCard: View {
    let state: RalphState
    @State private var currentQuote: String = ""
    @State private var quoteTimer: Timer?

    var body: some View {
        VStack(spacing: 8) {
            // Ralph character image with state indicator
            ZStack(alignment: .bottomTrailing) {
                Image("RalphFace", bundle: .module)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 70, height: 70)

                // State indicator badge
                ZStack {
                    Circle()
                        .fill(state.color)
                        .frame(width: 18, height: 18)
                    Image(systemName: state.icon)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                }
                .offset(x: 4, y: 4)
            }

            // Quote bubble with speech bubble background
            VStack(spacing: 2) {
                Text("\"\(currentQuote)\"")
                    .font(.caption)
                    .italic()
                    .foregroundColor(.primary.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.1))
                    )
            }
            .frame(height: 40)

            // Coding context
            HStack(spacing: 4) {
                Circle()
                    .fill(state.color)
                    .frame(width: 6, height: 6)

                Text(state.codingContext)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(state.color)
            }
        }
        .onAppear {
            currentQuote = state.randomQuote()
            startQuoteTimer()
        }
        .onDisappear {
            quoteTimer?.invalidate()
        }
        .onChange(of: state) { _, newState in
            currentQuote = newState.randomQuote()
        }
    }

    private func startQuoteTimer() {
        quoteTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                currentQuote = state.randomQuote()
            }
        }
    }
}

// MARK: - Loop Row View

struct LoopRowView: View {
    let loop: RalphLoop
    let isSelected: Bool
    @ObservedObject private var settings = SettingsManager.shared

    var body: some View {
        HStack(spacing: 10) {
            // Status indicator
            Image(systemName: loop.status.icon)
                .font(.system(size: 14))
                .foregroundColor(statusColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(loop.name)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text("Iteration \(loop.currentIteration)")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    if let max = loop.maxIterations {
                        Text("/ \(max)")
                            .font(.caption2)
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                }
            }

            Spacer()

            // Progress indicator for running loops
            if loop.status == .running {
                ProgressView()
                    .scaleEffect(0.6)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? settings.accentColor.opacity(0.2) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? settings.accentColor.opacity(0.5) : Color.clear, lineWidth: 1)
        )
    }

    private var statusColor: Color {
        switch loop.status {
        case .idle: return .gray
        case .running: return .green
        case .paused: return .orange
        case .completed: return .blue
        case .failed: return .red
        }
    }
}

// MARK: - New Loop Sheet

struct NewLoopSheet: View {
    @Binding var isPresented: Bool
    @StateObject private var loopManager = LoopManager.shared
    @ObservedObject private var settings = SettingsManager.shared

    // Mode selection
    @State private var mode: CreationMode = .demo

    // Custom mode fields
    @State private var name = ""
    @State private var projectPath = ""
    @State private var promptPath = ""
    @State private var copilotConfig = CopilotConfig.default
    @State private var maxIterations = 50
    @State private var showingProjectPicker = false
    @State private var showingPromptPicker = false

    // Demo mode fields
    @State private var selectedDemo: DemoProjectSetup.DemoProject = .todoApp
    @State private var isSettingUpDemo = false
    @State private var setupError: String?

    enum CreationMode: String, CaseIterable {
        case demo = "Quick Start Demo"
        case custom = "Custom Project"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "repeat.circle.fill")
                    .font(.title2)
                    .foregroundColor(settings.accentColor)
                Text("New Ralph Loop")
                    .font(.headline)
            }
            .padding(.top, 16)
            .padding(.bottom, 12)

            // Mode picker
            Picker("", selection: $mode) {
                ForEach(CreationMode.allCases, id: \.self) { m in
                    Text(m.rawValue).tag(m)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)
            .padding(.bottom, 16)

            // Content area (scrollable if needed)
            ScrollView {
                if mode == .demo {
                    demoModeContent
                } else {
                    customModeContent
                }
            }

            Divider()
                .padding(.top, 8)

            // Buttons - always visible at bottom
            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                if mode == .demo {
                    Button("Setup & Create Loop") {
                        setupDemoProject()
                    }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .tint(settings.accentColor)
                    .disabled(isSettingUpDemo)
                } else {
                    Button("Create Loop") {
                        createCustomLoop()
                    }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .tint(settings.accentColor)
                    .disabled(name.isEmpty || projectPath.isEmpty)
                }
            }
            .padding(16)
        }
        .frame(width: 500, height: 480)
    }

    // MARK: - Demo Mode

    private var demoModeContent: some View {
        VStack(spacing: 16) {
            Text("Choose a demo project to get started quickly")
                .font(.subheadline)
                .foregroundColor(.secondary)

            // Demo project cards
            VStack(spacing: 12) {
                ForEach(DemoProjectSetup.DemoProject.allCases) { demo in
                    DemoProjectCard(
                        demo: demo,
                        isSelected: selectedDemo == demo,
                        onSelect: { selectedDemo = demo }
                    )
                }
            }
            .padding(.horizontal)

            // Copilot config (simplified for demo)
            GroupBox("Copilot Settings") {
                VStack(alignment: .leading, spacing: 8) {
                    Picker("Model", selection: $copilotConfig.model) {
                        ForEach(CopilotConfig.CopilotModel.allCases) { model in
                            Text(model.displayName).tag(model)
                        }
                    }
                    .pickerStyle(.menu)

                    Text("Demo will be created in ~/RalphWiggumDemos/")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
            .padding(.horizontal)

            if let error = setupError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }

            if isSettingUpDemo {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Setting up demo project...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Custom Mode

    private var customModeContent: some View {
        Form {
            Section("Loop Configuration") {
                TextField("Name", text: $name)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    TextField("Project Path", text: $projectPath)
                        .textFieldStyle(.roundedBorder)
                    Button {
                        showingProjectPicker = true
                    } label: {
                        Image(systemName: "folder")
                    }
                    .fileImporter(
                        isPresented: $showingProjectPicker,
                        allowedContentTypes: [.folder]
                    ) { result in
                        if case .success(let url) = result {
                            projectPath = url.path
                        }
                    }
                }

                HStack {
                    TextField("Prompt File (PROMPT.md)", text: $promptPath)
                        .textFieldStyle(.roundedBorder)
                    Button {
                        showingPromptPicker = true
                    } label: {
                        Image(systemName: "doc.text")
                    }
                    .fileImporter(
                        isPresented: $showingPromptPicker,
                        allowedContentTypes: [.plainText]
                    ) { result in
                        if case .success(let url) = result {
                            promptPath = url.path
                        }
                    }
                }

                Stepper("Max Iterations: \(maxIterations)", value: $maxIterations, in: 1...500)
            }

            Section("Copilot Configuration") {
                Picker("Model", selection: $copilotConfig.model) {
                    ForEach(CopilotConfig.CopilotModel.allCases) { model in
                        Text(model.displayName).tag(model)
                    }
                }

                Toggle("Allow All Tools", isOn: $copilotConfig.allowAllTools)
                Toggle("Allow All Paths", isOn: $copilotConfig.allowAllPaths)
                Toggle("Autonomous Mode (no user prompts)", isOn: $copilotConfig.noAskUser)
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Actions

    private func setupDemoProject() {
        isSettingUpDemo = true
        setupError = nil

        Task {
            do {
                // Create demo directory if needed
                try FileManager.default.createDirectory(
                    at: DemoProjectSetup.defaultDemoDirectory,
                    withIntermediateDirectories: true
                )

                // Setup the demo project
                let projectURL = try DemoProjectSetup.setupDemoProject(
                    selectedDemo,
                    in: DemoProjectSetup.defaultDemoDirectory
                )

                // Create the loop
                let loop = RalphLoop(
                    name: "Demo: \(selectedDemo.displayName)",
                    projectPath: projectURL,
                    promptPath: projectURL.appendingPathComponent("PROMPT.md"),
                    cliTool: CLITool.copilot.command,
                    cliArguments: copilotConfig.commandArguments,
                    maxIterations: 10  // Lower for demo
                )

                await MainActor.run {
                    loopManager.addLoop(loop)
                    isSettingUpDemo = false
                    isPresented = false
                }
            } catch {
                await MainActor.run {
                    setupError = "Setup failed: \(error.localizedDescription)"
                    isSettingUpDemo = false
                }
            }
        }
    }

    private func createCustomLoop() {
        let projectURL = URL(fileURLWithPath: projectPath)

        let promptURL: URL
        if promptPath.isEmpty {
            promptURL = projectURL.appendingPathComponent("PROMPT.md")
        } else if promptPath.hasPrefix("/") {
            promptURL = URL(fileURLWithPath: promptPath)
        } else {
            promptURL = projectURL.appendingPathComponent(promptPath)
        }

        let loop = RalphLoop(
            name: name,
            projectPath: projectURL,
            promptPath: promptURL,
            cliTool: CLITool.copilot.command,
            cliArguments: copilotConfig.commandArguments,
            maxIterations: maxIterations
        )
        loopManager.addLoop(loop)
        isPresented = false
    }
}

// MARK: - Demo Project Card

struct DemoProjectCard: View {
    let demo: DemoProjectSetup.DemoProject
    let isSelected: Bool
    let onSelect: () -> Void
    @ObservedObject private var settings = SettingsManager.shared

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? settings.accentColor.opacity(0.2) : Color.gray.opacity(0.1))
                    .frame(width: 44, height: 44)

                Image(systemName: demo.icon)
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? settings.accentColor : .secondary)
            }

            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(demo.displayName)
                    .font(.system(size: 13, weight: .medium))

                Text(demo.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Selection indicator
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(settings.accentColor)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isSelected ? settings.accentColor.opacity(0.1) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? settings.accentColor : Color.gray.opacity(0.2), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
    }
}

struct TemplateGallerySheet: View {
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 16) {
            Text("Prompt Templates")
                .font(.headline)

            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 12) {
                    ForEach(PromptTemplate.builtInTemplates) { template in
                        TemplateCard(template: template)
                    }
                }
                .padding()
            }

            Button("Close") {
                isPresented = false
            }
        }
        .padding()
        .frame(width: 500, height: 400)
    }
}

struct TemplateCard: View {
    let template: PromptTemplate
    @ObservedObject private var settings = SettingsManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: template.category.icon)
                    .foregroundColor(template.category.color)
                Spacer()
            }

            Text(template.name)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)

            Text(template.description)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(2)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.1))
        )
    }
}

struct AchievementsSheet: View {
    @Binding var isPresented: Bool
    @StateObject private var loopManager = LoopManager.shared

    var body: some View {
        VStack(spacing: 16) {
            Text("Achievements")
                .font(.headline)

            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120))], spacing: 12) {
                    ForEach(RalphAchievement.allCases) { achievement in
                        AchievementCard(
                            achievement: achievement,
                            isUnlocked: loopManager.isAchievementUnlocked(achievement)
                        )
                    }
                }
                .padding()
            }

            Button("Close") {
                isPresented = false
            }
        }
        .padding()
        .frame(width: 500, height: 400)
    }
}

struct AchievementCard: View {
    let achievement: RalphAchievement
    let isUnlocked: Bool

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(isUnlocked ? achievement.color.opacity(0.2) : Color.gray.opacity(0.1))
                    .frame(width: 50, height: 50)

                Image(systemName: achievement.icon)
                    .font(.system(size: 24))
                    .foregroundColor(isUnlocked ? achievement.color : .gray.opacity(0.3))
            }

            Text(achievement.name)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(1)
                .foregroundColor(isUnlocked ? .primary : .secondary)

            Text(achievement.description)
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.05))
        )
        .opacity(isUnlocked ? 1.0 : 0.5)
    }
}

// MARK: - Loop Detail View

struct LoopDetailView: View {
    @Binding var loop: RalphLoop
    @StateObject private var loopManager = LoopManager.shared
    @ObservedObject private var settings = SettingsManager.shared
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            // Header
            loopHeader

            Divider()

            // Tab content
            TabView(selection: $selectedTab) {
                LoopStatusTab(loop: loop)
                    .tabItem { Label("Status", systemImage: "chart.bar") }
                    .tag(0)

                LoopConsoleTab(loopId: loop.id)
                    .tabItem { Label("Console", systemImage: "terminal") }
                    .tag(1)

                IterationHistoryTab(loopId: loop.id)
                    .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
                    .tag(2)

                PromptTab(loop: $loop)
                    .tabItem { Label("Prompt", systemImage: "doc.text") }
                    .tag(3)
            }
            .padding()
        }
    }

    private var loopHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(loop.name)
                    .font(.headline)

                Text(loop.displayPath)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Control buttons
            HStack(spacing: 8) {
                if loop.status == .running {
                    Button {
                        Task { await loopManager.pauseLoop(loop.id) }
                    } label: {
                        Image(systemName: "pause.fill")
                    }
                    .help("Pause")

                    Button {
                        Task { await loopManager.stopLoop(loop.id) }
                    } label: {
                        Image(systemName: "stop.fill")
                    }
                    .help("Stop")
                } else if loop.status == .paused {
                    Button {
                        Task { await loopManager.resumeLoop(loop.id) }
                    } label: {
                        Image(systemName: "play.fill")
                    }
                    .help("Resume")

                    Button {
                        Task { await loopManager.stopLoop(loop.id) }
                    } label: {
                        Image(systemName: "stop.fill")
                    }
                    .help("Stop")
                } else {
                    Button {
                        Task { await loopManager.startLoop(loop.id) }
                    } label: {
                        Image(systemName: "play.fill")
                            .foregroundColor(.green)
                    }
                    .help("Start Loop")
                }
            }
            .buttonStyle(.plain)
        }
        .padding()
    }
}

// MARK: - Tab Views

struct LoopStatusTab: View {
    let loop: RalphLoop

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Stats grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                StatCard(title: "Iterations", value: "\(loop.currentIteration)", icon: "number")
                StatCard(title: "Status", value: loop.status.displayName, icon: loop.status.icon)
                StatCard(title: "Duration", value: loop.formattedDuration, icon: "clock")
                StatCard(title: "Est. Cost", value: loop.formattedCost, icon: "dollarsign.circle")
            }

            // Progress bar if max iterations set
            if let max = loop.maxIterations, max > 0 {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Progress")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(loop.currentIteration) / \(max)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    ProgressView(value: Double(loop.currentIteration), total: Double(max))
                        .tint(SettingsManager.shared.accentColor)
                }
            }

            Spacer()
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.secondary)

            Text(value)
                .font(.system(size: 16, weight: .semibold))

            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.1))
        )
    }
}

// MARK: - Console Tab

struct LoopConsoleTab: View {
    let loopId: UUID
    @StateObject private var loopManager = LoopManager.shared
    @State private var autoScroll = true

    var body: some View {
        VStack(spacing: 0) {
            // Console header
            HStack {
                HStack(spacing: 4) {
                    Circle()
                        .fill(loopManager.loops.first { $0.id == loopId }?.status == .running ? Color.green : Color.gray)
                        .frame(width: 8, height: 8)
                    Text("Console Output")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Toggle("Auto-scroll", isOn: $autoScroll)
                    .toggleStyle(.checkbox)
                    .font(.caption)

                Button {
                    loopManager.clearOutputLog(for: loopId)
                } label: {
                    Image(systemName: "trash")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                .help("Clear console")
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)

            Divider()

            // Console output
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        let outputLines = loopManager.getOutputLog(for: loopId)

                        if outputLines.isEmpty {
                            VStack(spacing: 8) {
                                Spacer()
                                Text("No output yet")
                                    .foregroundColor(.secondary)
                                Text("Start the loop to see live output")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            .frame(maxWidth: .infinity, minHeight: 100)
                        } else {
                            ForEach(outputLines) { line in
                                ConsoleLineView(line: line)
                            }

                            // Invisible anchor for auto-scroll
                            Color.clear
                                .frame(height: 1)
                                .id("bottom")
                        }
                    }
                    .padding(8)
                }
                .background(Color.black.opacity(0.3))
                .cornerRadius(6)
                .onChange(of: loopManager.outputLogs[loopId]?.count) { _, _ in
                    if autoScroll {
                        withAnimation(.easeOut(duration: 0.1)) {
                            proxy.scrollTo("bottom", anchor: .bottom)
                        }
                    }
                }
            }
        }
    }
}

struct ConsoleLineView: View {
    let line: LoopManager.OutputLine

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: line.timestamp)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(timeString)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.secondary.opacity(0.6))
                .frame(width: 60, alignment: .leading)

            Text(line.text)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(line.isError ? .red : .primary.opacity(0.9))
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
        .padding(.vertical, 1)
    }
}

struct IterationHistoryTab: View {
    let loopId: UUID
    @StateObject private var loopManager = LoopManager.shared

    var body: some View {
        let iterations = loopManager.getIterations(for: loopId)

        if iterations.isEmpty {
            VStack {
                Spacer()
                Text("No iterations yet")
                    .foregroundColor(.secondary)
                Text("Start the loop to see history")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
        } else {
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(iterations.reversed()) { iteration in
                        IterationRow(iteration: iteration)
                    }
                }
            }
        }
    }
}

struct IterationRow: View {
    let iteration: LoopIteration

    var body: some View {
        HStack {
            // Iteration number
            Text("#\(iteration.iterationNumber)")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 40)

            // Status indicator
            Image(systemName: iteration.isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(iteration.isSuccess ? .green : .red)
                .font(.system(size: 12))

            // Summary
            VStack(alignment: .leading, spacing: 2) {
                if let summary = iteration.semanticSummary {
                    Text(summary)
                        .font(.caption)
                        .lineLimit(1)
                } else {
                    Text(iteration.isSuccess ? "Completed" : "Failed")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 8) {
                    Text(iteration.formattedDuration)
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    if !iteration.filesChanged.isEmpty {
                        Text("\(iteration.filesChanged.count) files")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            // Commit hash
            if let hash = iteration.shortCommitHash {
                Text(hash)
                    .font(.caption2)
                    .fontDesign(.monospaced)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.gray.opacity(0.05))
        )
    }
}

struct PromptTab: View {
    @Binding var loop: RalphLoop

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Prompt File")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                Button {
                    NSWorkspace.shared.open(loop.promptPath)
                } label: {
                    Image(systemName: "arrow.up.right.square")
                }
                .buttonStyle(.plain)
                .help("Open in Editor")
            }

            // Show prompt content preview
            if let content = try? String(contentsOf: loop.promptPath, encoding: .utf8) {
                ScrollView {
                    Text(content)
                        .font(.system(size: 11, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                }
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.black.opacity(0.3))
                )
            } else {
                VStack {
                    Spacer()
                    Text("Could not read prompt file")
                        .foregroundColor(.secondary)
                    Text(loop.promptPath.path)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
        }
    }
}

#Preview {
    RalphWiggumView()
        .frame(width: 600, height: 400)
        .environmentObject(NavigationState())
}
