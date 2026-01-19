import SwiftUI

/// Bottom close bar - click or swipe up to close
struct NotchCloseBar: View {
    @State private var isHovering = false
    @State private var isDragging = false
    @State private var didTriggerHaptic = false  // Prevent repeated haptic feedback
    
    private let closeThreshold: CGFloat = -30 // Swipe up 30pt to close
    
    var body: some View {
        HStack {
            Spacer()
            
            // Center grip bar for closing
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.white.opacity(isDragging ? 0.5 : (isHovering ? 0.4 : 0.25)))
                .frame(width: 40, height: 4)
                .contentShape(Rectangle().size(width: 60, height: 20))
            
            Spacer()
        }
        .frame(height: 16)
        .contentShape(Rectangle())
        .onTapGesture {
            // Single tap to close
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
            NotificationCenter.default.post(name: .hideNotch, object: nil)
        }
        .gesture(
            DragGesture(minimumDistance: 5)
                .onChanged { value in
                    isDragging = true
                    // Haptic feedback only once when close threshold is first crossed
                    if value.translation.height < closeThreshold && !didTriggerHaptic {
                        didTriggerHaptic = true
                        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
                    } else if value.translation.height >= closeThreshold {
                        didTriggerHaptic = false  // Reset when dragged back
                    }
                }
                .onEnded { value in
                    isDragging = false
                    didTriggerHaptic = false
                    if value.translation.height < closeThreshold {
                        NotificationCenter.default.post(name: .hideNotch, object: nil)
                    }
                }
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}

/// Corner resize handle - drag to resize
struct NotchResizeHandle: View {
    let currentApp: MiniApp
    @StateObject private var settings = SettingsManager.shared
    
    @State private var isDragging = false
    @State private var isHovering = false
    @State private var dragStartSize: CGSize = .zero
    @State private var currentDragSize: CGSize = .zero  // Track size during drag without saving
    
    var body: some View {
        // Diagonal resize indicator in corner
        ZStack {
            // Small diagonal lines pattern
            Path { path in
                // Draw 3 diagonal lines
                for i in 0..<3 {
                    let offset = CGFloat(i) * 4
                    path.move(to: CGPoint(x: 12 - offset, y: 12))
                    path.addLine(to: CGPoint(x: 12, y: 12 - offset))
                }
            }
            .stroke(Color.white.opacity(isDragging ? 0.6 : (isHovering ? 0.5 : 0.3)), lineWidth: 1.5)
        }
        .frame(width: 16, height: 16)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 1)
                .onChanged { value in
                    if !isDragging {
                        isDragging = true
                        dragStartSize = settings.sizeForApp(currentApp)
                    }
                    
                    let newWidth = dragStartSize.width + value.translation.width
                    let newHeight = dragStartSize.height + value.translation.height
                    
                    currentDragSize = CGSize(
                        width: max(SettingsManager.minNotchWidth, min(SettingsManager.maxNotchWidth, newWidth)),
                        height: max(SettingsManager.minNotchHeight, min(SettingsManager.maxNotchHeight, newHeight))
                    )
                    
                    // Update UI immediately without persisting to disk
                    settings.updateSizeWithoutSaving(currentDragSize, for: currentApp)
                }
                .onEnded { _ in
                    isDragging = false
                    // Persist to disk only when drag ends
                    settings.setSize(currentDragSize, for: currentApp)
                }
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
            if hovering {
                NSCursor.crosshair.push()  // Best available diagonal-like cursor in macOS
            } else {
                NSCursor.pop()
            }
        }
    }
}

/// Combined bottom bar with close center and resize corner
struct NotchBottomBar: View {
    let currentApp: MiniApp
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // Close bar in center
            NotchCloseBar()
            
            // Resize handle in bottom-right corner
            NotchResizeHandle(currentApp: currentApp)
                .padding(.trailing, 4)
                .padding(.bottom, 2)
        }
        .frame(height: 18)
    }
}

#Preview {
    ZStack {
        Color.black
        VStack {
            Spacer()
            NotchBottomBar(currentApp: .fogNote)
        }
    }
    .frame(width: 300, height: 150)
}
