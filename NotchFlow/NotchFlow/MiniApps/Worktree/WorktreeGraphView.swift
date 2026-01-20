import SwiftUI

/// Visual representation of worktree relationships within a repository
struct WorktreeGraphView: View {
    let group: RepositoryGroup
    @State private var hoveredWorktree: Worktree?

    private let nodeSize: CGFloat = 10
    private let nodeSpacing: CGFloat = 60
    private let branchColors: [Color] = [.cyan, .green, .orange, .purple, .pink, .yellow]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "point.3.connected.trianglepath.dotted")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)

                Text("Worktree Map")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.gray)

                Spacer()

                Text("\(group.worktrees.count) worktree\(group.worktrees.count == 1 ? "" : "s")")
                    .font(.system(size: 10))
                    .foregroundColor(.gray.opacity(0.7))
            }

            // Graph visualization
            graphContent
        }
        .padding(12)
        .background(Color.white.opacity(0.03))
        .cornerRadius(8)
    }

    // MARK: - Graph Content

    private var graphContent: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let mainWorktree = group.mainWorktree
            let linkedWorktrees = group.linkedWorktrees

            ZStack {
                // Connection lines
                connectionLines(width: width, mainWorktree: mainWorktree, linkedWorktrees: linkedWorktrees)

                // Nodes
                worktreeNodes(width: width, mainWorktree: mainWorktree, linkedWorktrees: linkedWorktrees)
            }
        }
        .frame(height: calculateGraphHeight())
    }

    // MARK: - Connection Lines

    private func connectionLines(width: CGFloat, mainWorktree: Worktree?, linkedWorktrees: [Worktree]) -> some View {
        Canvas { context, _ in
            guard mainWorktree != nil else { return }

            let mainX = width / 2
            let mainY: CGFloat = 30

            // Draw lines from main to each linked worktree
            for index in linkedWorktrees.indices {
                let angle = calculateAngle(index: index, total: linkedWorktrees.count)
                let radius = min(width / 2 - 40, 100.0)
                let targetX = mainX + cos(angle) * radius
                let targetY = mainY + 50 + sin(angle) * radius * 0.5

                var path = Path()
                path.move(to: CGPoint(x: mainX, y: mainY))

                // Curved connection
                let controlY = mainY + 25
                path.addQuadCurve(
                    to: CGPoint(x: targetX, y: targetY),
                    control: CGPoint(x: (mainX + targetX) / 2, y: controlY)
                )

                let color = branchColors[index % branchColors.count]
                context.stroke(
                    path,
                    with: .color(color.opacity(0.4)),
                    lineWidth: 2
                )
            }
        }
    }

    // MARK: - Worktree Nodes

    private func worktreeNodes(width: CGFloat, mainWorktree: Worktree?, linkedWorktrees: [Worktree]) -> some View {
        ZStack {
            // Main worktree node (center top)
            if let main = mainWorktree {
                worktreeNode(
                    worktree: main,
                    color: .orange,
                    position: CGPoint(x: width / 2, y: 30)
                )
            }

            // Linked worktree nodes (spread around)
            ForEach(Array(linkedWorktrees.enumerated()), id: \.element.id) { index, worktree in
                let angle = calculateAngle(index: index, total: linkedWorktrees.count)
                let radius = min(width / 2 - 40, 100.0)
                let x = width / 2 + cos(angle) * radius
                let y: CGFloat = 80 + sin(angle) * radius * 0.5

                worktreeNode(
                    worktree: worktree,
                    color: branchColors[index % branchColors.count],
                    position: CGPoint(x: x, y: y)
                )
            }
        }
    }

    private func worktreeNode(worktree: Worktree, color: Color, position: CGPoint) -> some View {
        VStack(spacing: 4) {
            // Status indicator ring
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: nodeSize + 8, height: nodeSize + 8)

                Circle()
                    .fill(color)
                    .frame(width: nodeSize, height: nodeSize)

                // Status dot
                if let status = worktree.status {
                    Circle()
                        .fill(status.isClean ? Color.green : Color.orange)
                        .frame(width: 6, height: 6)
                        .offset(x: 8, y: -8)
                }
            }

            // Branch name
            Text(worktree.branch)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(1)
                .frame(maxWidth: 80)

            // Folder name
            Text(worktree.displayName)
                .font(.system(size: 8))
                .foregroundColor(.gray)
                .lineLimit(1)
                .frame(maxWidth: 80)

            // Remote status
            if let tracking = worktree.remoteTracking, !tracking.isSynced {
                HStack(spacing: 2) {
                    if tracking.ahead > 0 {
                        Text("↑\(tracking.ahead)")
                            .foregroundColor(.green)
                    }
                    if tracking.behind > 0 {
                        Text("↓\(tracking.behind)")
                            .foregroundColor(.orange)
                    }
                }
                .font(.system(size: 8, weight: .medium))
            }
        }
        .position(position)
        .onHover { isHovering in
            hoveredWorktree = isHovering ? worktree : nil
        }
    }

    // MARK: - Helper Methods

    private func calculateAngle(index: Int, total: Int) -> CGFloat {
        guard total > 0 else { return 0 }
        let baseAngle = CGFloat.pi / 2 // Start from bottom
        let spread = CGFloat.pi * 0.8 // Spread angle
        let step = total > 1 ? spread / CGFloat(total - 1) : 0
        return baseAngle - spread / 2 + step * CGFloat(index)
    }

    private func calculateGraphHeight() -> CGFloat {
        let linkedCount = group.linkedWorktrees.count
        if linkedCount == 0 { return 60 }
        return 140 + CGFloat(max(0, linkedCount - 4)) * 20
    }
}

// MARK: - Compact Graph (for list view)

struct CompactWorktreeGraph: View {
    let worktrees: [Worktree]

    var body: some View {
        HStack(spacing: -4) {
            ForEach(Array(worktrees.prefix(5).enumerated()), id: \.element.id) { index, worktree in
                ZStack {
                    Circle()
                        .fill(worktree.isMainWorktree ? Color.orange : Color.cyan)
                        .frame(width: 16, height: 16)

                    if let status = worktree.status, !status.isClean {
                        Circle()
                            .stroke(Color.orange, lineWidth: 2)
                            .frame(width: 18, height: 18)
                    }
                }
                .zIndex(Double(worktrees.count - index))
            }

            if worktrees.count > 5 {
                Text("+\(worktrees.count - 5)")
                    .font(.system(size: 9))
                    .foregroundColor(.gray)
                    .padding(.leading, 8)
            }
        }
    }
}

// MARK: - Branch Line View (simple horizontal representation)

struct BranchLineView: View {
    let worktree: Worktree
    let isFirst: Bool
    let isLast: Bool

    var body: some View {
        HStack(spacing: 0) {
            // Connecting line
            if !isFirst {
                Rectangle()
                    .fill(Color.cyan.opacity(0.3))
                    .frame(width: 20, height: 2)
            }

            // Node
            ZStack {
                Circle()
                    .fill(worktree.isMainWorktree ? Color.orange : Color.cyan)
                    .frame(width: 12, height: 12)

                if worktree.status?.isClean == false {
                    Circle()
                        .stroke(Color.orange, lineWidth: 2)
                        .frame(width: 14, height: 14)
                }
            }

            // Trailing line
            if !isLast {
                Rectangle()
                    .fill(Color.cyan.opacity(0.3))
                    .frame(height: 2)
            }
        }
    }
}

#Preview {
    VStack {
        WorktreeGraphView(
            group: RepositoryGroup(
                repoPath: URL(fileURLWithPath: "/Users/demo/Code/project"),
                worktrees: [
                    Worktree(
                        path: URL(fileURLWithPath: "/Users/demo/Code/project"),
                        branch: "main",
                        lastModified: Date(),
                        parentRepo: URL(fileURLWithPath: "/Users/demo/Code/project"),
                        isMainWorktree: true,
                        status: GitStatusSummary()
                    ),
                    Worktree(
                        path: URL(fileURLWithPath: "/Users/demo/.worktrees/feature-a"),
                        branch: "feature-a",
                        lastModified: Date(),
                        parentRepo: URL(fileURLWithPath: "/Users/demo/Code/project"),
                        status: GitStatusSummary(modified: 3)
                    ),
                    Worktree(
                        path: URL(fileURLWithPath: "/Users/demo/.worktrees/feature-b"),
                        branch: "feature-b",
                        lastModified: Date(),
                        parentRepo: URL(fileURLWithPath: "/Users/demo/Code/project"),
                        status: GitStatusSummary()
                    )
                ]
            )
        )
        .frame(width: 300)
    }
    .padding()
    .background(Color.black)
}
