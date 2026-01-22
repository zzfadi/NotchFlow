import SwiftUI
import AppKit

/// A resizable two-pane layout with a discoverable resize handle
struct ResizableSidebar<Sidebar: View, Detail: View>: View {
    let sidebar: Sidebar
    let detail: Detail

    @State private var sidebarWidth: CGFloat = 200
    @State private var isHoveringDivider = false
    @State private var isDraggingDivider = false

    private let minSidebarWidth: CGFloat = 160
    private let maxSidebarWidth: CGFloat = 300
    private let dividerHitWidth: CGFloat = 8
    private let dividerVisualWidth: CGFloat = 1

    init(@ViewBuilder sidebar: () -> Sidebar, @ViewBuilder detail: () -> Detail) {
        self.sidebar = sidebar()
        self.detail = detail()
    }

    var body: some View {
        HStack(spacing: 0) {
            // Sidebar
            sidebar
                .frame(width: sidebarWidth)

            // Resizable divider
            ZStack {
                // Invisible hit area
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: dividerHitWidth)
                    .contentShape(Rectangle())

                // Visible divider line
                Rectangle()
                    .fill(Color(nsColor: .separatorColor))
                    .frame(width: isHoveringDivider || isDraggingDivider ? 3 : dividerVisualWidth)
                    .opacity(isHoveringDivider || isDraggingDivider ? 0.8 : 0.4)

                // Grip dots on hover
                if isHoveringDivider || isDraggingDivider {
                    VStack(spacing: 3) {
                        ForEach(0..<3, id: \.self) { _ in
                            Circle()
                                .fill(Color.secondary.opacity(0.6))
                                .frame(width: 4, height: 4)
                        }
                    }
                }
            }
            .frame(width: dividerHitWidth)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isDraggingDivider = true
                        let newWidth = sidebarWidth + value.translation.width
                        sidebarWidth = max(minSidebarWidth, min(maxSidebarWidth, newWidth))
                    }
                    .onEnded { _ in
                        isDraggingDivider = false
                    }
            )
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHoveringDivider = hovering
                }
                if hovering {
                    NSCursor.resizeLeftRight.push()
                } else {
                    NSCursor.pop()
                }
            }

            // Detail view
            detail
                .frame(maxWidth: .infinity)
        }
    }
}

#Preview {
    ResizableSidebar {
        List {
            Text("Item 1")
            Text("Item 2")
            Text("Item 3")
        }
    } detail: {
        Text("Detail View")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .frame(width: 600, height: 400)
}
