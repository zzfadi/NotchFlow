import XCTest
@testable import NotchFlow

final class WorktreeScannerTests: XCTestCase {

    var tempDir: TempDirectory!

    override func setUpWithError() throws {
        tempDir = try TempDirectory()
    }

    override func tearDown() {
        tempDir?.cleanup()
        tempDir = nil
    }

    // MARK: - HEAD parsing

    /// Normal branch ref: `ref: refs/heads/<branch>` → branch name, not
    /// detached, no commit hash.
    func testParseHEADOnBranchRef() throws {
        let head = try tempDir.writeFile("HEAD", contents: "ref: refs/heads/main\n")

        let (branch, isDetached, hash) = WorktreeScanner.parseHEAD(head)
        XCTAssertEqual(branch, "main")
        XCTAssertFalse(isDetached)
        XCTAssertNil(hash)
    }

    /// Detached HEAD: file contains a raw commit hash. We surface it as
    /// `"HEAD"` branch + isDetached=true + hash populated.
    func testParseHEADDetached() throws {
        let sha = "abc1234567890abcdef1234567890abcdef12345"
        let head = try tempDir.writeFile("HEAD", contents: "\(sha)\n")

        let (branch, isDetached, hash) = WorktreeScanner.parseHEAD(head)
        XCTAssertEqual(branch, "HEAD")
        XCTAssertTrue(isDetached)
        XCTAssertEqual(hash, sha)
    }

    /// Missing HEAD file → sentinel values. The scanner should never throw;
    /// a repo in a weird state just gets "unknown" and moves on.
    func testParseHEADMissingFile() {
        let missing = tempDir.url.appendingPathComponent("does-not-exist")

        let (branch, isDetached, hash) = WorktreeScanner.parseHEAD(missing)
        XCTAssertEqual(branch, "unknown")
        XCTAssertFalse(isDetached)
        XCTAssertNil(hash)
    }

    /// Branch name containing slashes (a common convention — `feature/xyz`).
    /// The prefix stripping is by length, not by last slash, so these must
    /// round-trip intact.
    func testParseHEADBranchWithSlash() throws {
        let head = try tempDir.writeFile(
            "HEAD",
            contents: "ref: refs/heads/feature/add-tests\n"
        )

        let (branch, _, _) = WorktreeScanner.parseHEAD(head)
        XCTAssertEqual(branch, "feature/add-tests")
    }

    // MARK: - Main worktree

    /// A bare directory with a `.git/HEAD` pointing at a branch should be
    /// recognized as a main worktree (`isMainWorktree=true`, parentRepo ==
    /// self).
    func testParseMainWorktree() throws {
        let repoRoot = try tempDir.makeSubdirectory("my-repo")
        try tempDir.writeFile("my-repo/.git/HEAD", contents: "ref: refs/heads/main\n")

        let worktree = WorktreeScanner.parseMainWorktree(repoRoot)
        XCTAssertNotNil(worktree)
        XCTAssertEqual(worktree?.branch, "main")
        XCTAssertEqual(worktree?.isMainWorktree, true)
        XCTAssertEqual(worktree?.parentRepo.lastPathComponent, "my-repo")
    }

    func testParseMainWorktreeReturnsNilWhenNotARepo() throws {
        let dir = try tempDir.makeSubdirectory("not-a-repo")

        XCTAssertNil(WorktreeScanner.parseMainWorktree(dir))
    }
}
