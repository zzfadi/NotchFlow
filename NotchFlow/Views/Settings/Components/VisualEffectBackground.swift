import SwiftUI
import AppKit

/// NSVisualEffectView wrapper for vibrancy/translucency effects
struct VisualEffectBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode
    var isEmphasized: Bool

    init(
        material: NSVisualEffectView.Material = .sidebar,
        blendingMode: NSVisualEffectView.BlendingMode = .behindWindow,
        isEmphasized: Bool = true
    ) {
        self.material = material
        self.blendingMode = blendingMode
        self.isEmphasized = isEmphasized
    }

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        view.isEmphasized = isEmphasized
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.isEmphasized = isEmphasized
    }
}

// MARK: - Convenience Modifiers

extension View {
    /// Applies a sidebar vibrancy background
    func sidebarBackground() -> some View {
        self.background(VisualEffectBackground(material: .sidebar))
    }

    /// Applies a content area vibrancy background
    func contentBackground() -> some View {
        self.background(VisualEffectBackground(material: .contentBackground))
    }

    /// Applies an ultra thin material background
    func ultraThinBackground() -> some View {
        self.background(VisualEffectBackground(material: .hudWindow))
    }
}
