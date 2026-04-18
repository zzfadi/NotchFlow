import XCTest
@testable import NotchFlow

final class AIConfigScannerTests: XCTestCase {

    var tempDir: TempDirectory!

    override func setUpWithError() throws {
        tempDir = try TempDirectory()
    }

    override func tearDown() {
        tempDir?.cleanup()
        tempDir = nil
    }

    // MARK: - Glob matching

    /// `*.prompt.md` should be detected as a prompt-file entry.
    func testPromptMdGlobMatches() async throws {
        try tempDir.writeFile("project/prompts/code-review.prompt.md", contents: "# prompt")
        try tempDir.writeFile("project/prompts/sparse-patch.prompt.md", contents: "# prompt")

        let items = await AIConfigScanner.performScan(
            projectPaths: [tempDir.url.appendingPathComponent("project").path]
        )

        let paths = items.map { $0.path.lastPathComponent }
        XCTAssertTrue(paths.contains("code-review.prompt.md"))
        XCTAssertTrue(paths.contains("sparse-patch.prompt.md"))
    }

    /// The glob for `*.instructions.md` explicitly excludes the filename
    /// `copilot-instructions.md` because the Copilot convention reserves
    /// that as a project-wide instruction file, not a per-topic one. If
    /// someone writes the file into a non-hidden directory, the `.instructionsMd`
    /// glob must still filter it out. Files are placed in a non-hidden
    /// subdirectory so `.skipsHiddenFiles` doesn't obscure the assertion.
    func testCopilotInstructionsFileIsExcludedFromInstructionsGlob() async throws {
        try tempDir.writeFile(
            "project/docs/copilot-instructions.md",
            contents: "# should be filtered by the glob"
        )
        try tempDir.writeFile(
            "project/docs/typescript.instructions.md",
            contents: "# should match"
        )

        let items = await AIConfigScanner.performScan(
            projectPaths: [tempDir.url.appendingPathComponent("project").path]
        )

        let instructionFiles = items
            .filter { $0.fileType == .instructionsMd }
            .map { $0.path.lastPathComponent }

        XCTAssertFalse(
            instructionFiles.contains("copilot-instructions.md"),
            "copilot-instructions.md should NOT be picked up by the .instructions.md glob"
        )
        XCTAssertTrue(
            instructionFiles.contains("typescript.instructions.md"),
            "Ordinary .instructions.md files should still match"
        )
    }

    // MARK: - Dedupe

    /// If two scan roots both contain the same child project, that project's
    /// files must not appear twice. The dedupe is keyed on `path.path`, so
    /// identical file URLs discovered via two parent roots should collapse
    /// to one item.
    ///
    /// Uses `AGENTS.md` so the fixture subdir is not hidden and gets walked
    /// from both roots. `resolvingSymlinksInPath()` is applied to the scan
    /// inputs because `NSTemporaryDirectory()` sits under `/var` which is a
    /// symlink to `/private/var` on macOS — without normalization the two
    /// walks produce different path strings for the same file and the test
    /// gets tripped up by a fixture-only artifact, not a real bug.
    func testDedupeAcrossOverlappingScanRoots() async throws {
        try tempDir.writeFile("outer/inner/AGENTS.md", contents: "# rules")

        let outer = tempDir.url
            .appendingPathComponent("outer")
            .resolvingSymlinksInPath()
            .path
        let inner = tempDir.url
            .appendingPathComponent("outer/inner")
            .resolvingSymlinksInPath()
            .path

        let items = await AIConfigScanner.performScan(projectPaths: [outer, inner])

        let agentsHits = items.filter { $0.path.lastPathComponent == "AGENTS.md" }
        XCTAssertEqual(
            agentsHits.count,
            1,
            "Overlapping roots must produce a single item per file. Got paths: \(agentsHits.map { $0.path.path })"
        )
    }

    // MARK: - Skip list enforcement

    /// Confirms the skip-list actually keeps the scanner out of media
    /// folders at walk time. We plant a `.claude/CLAUDE.md` inside a fake
    /// `Music/` subdirectory and expect it NOT to be discovered.
    func testSkipListPreventsMediaFolderDescent() async throws {
        try tempDir.writeFile(
            "project/Music/sub/.claude/CLAUDE.md",
            contents: "# should not be found"
        )
        try tempDir.writeFile(
            "project/normal/.claude/CLAUDE.md",
            contents: "# should be found"
        )

        let items = await AIConfigScanner.performScan(
            projectPaths: [tempDir.url.appendingPathComponent("project").path]
        )

        let foundProjectPaths = Set(items.map { $0.projectPath.path })
        XCTAssertTrue(
            foundProjectPaths.contains(where: { $0.hasSuffix("/normal") }),
            "Files under ordinary subfolders must still be discovered"
        )
        XCTAssertFalse(
            foundProjectPaths.contains(where: { $0.contains("/Music/") }),
            "ScannerSkipList must prevent descent into Music/"
        )
    }
}
