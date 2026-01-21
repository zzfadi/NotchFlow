import SwiftUI

/// Modern settings window with resizable sidebar layout
struct ModernSettingsView: View {
    @State private var selectedSection: SettingsSection? = .general

    var body: some View {
        ResizableSidebar {
            SettingsSidebar(selection: $selectedSection)
                .background(VisualEffectBackground(material: .sidebar))
        } detail: {
            SettingsDetailView(section: selectedSection)
        }
        .frame(minWidth: 580, idealWidth: 720, minHeight: 400, idealHeight: 540)
        .ignoresSafeArea(.container, edges: .top)
    }
}

// MARK: - Preview

#Preview {
    ModernSettingsView()
        .frame(width: 680, height: 500)
}
