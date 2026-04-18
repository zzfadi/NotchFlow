import XCTest
@testable import NotchFlow

@MainActor
final class ErrorCenterTests: XCTestCase {

    override func setUp() async throws {
        // Each test starts with a clean center; we only observe our own
        // toasts. The center is a singleton, so reset its state between
        // tests so ordering assumptions hold.
        ErrorCenter.shared.dismissAll()
    }

    override func tearDown() async throws {
        ErrorCenter.shared.dismissAll()
    }

    /// Surfacing two messages with different sources should stack — each is
    /// a distinct failure the user should see.
    func testDifferentSourcesStack() {
        ErrorCenter.shared.surface("load failed", level: .error, source: "NoteStorage.load")
        ErrorCenter.shared.surface("save failed", level: .error, source: "NoteStorage.save")

        XCTAssertEqual(ErrorCenter.shared.toasts.count, 2)
    }

    /// The core invariant behind the `source:` parameter — repeated failures
    /// from the *same* source replace rather than stack up. Without this a
    /// flaky scan would fill the screen with duplicate toasts.
    func testSameSourceCoalesces() {
        ErrorCenter.shared.surface("attempt 1", level: .error, source: "Scanner")
        ErrorCenter.shared.surface("attempt 2", level: .error, source: "Scanner")
        ErrorCenter.shared.surface("attempt 3", level: .error, source: "Scanner")

        XCTAssertEqual(ErrorCenter.shared.toasts.count, 1)
        XCTAssertEqual(ErrorCenter.shared.toasts.first?.message, "attempt 3")
    }

    /// `nil`-source toasts aren't coalesced with each other — no identity
    /// to match on.
    func testNilSourceMessagesDoNotCoalesce() {
        ErrorCenter.shared.surface("one", level: .info, source: nil)
        ErrorCenter.shared.surface("two", level: .info, source: nil)

        XCTAssertEqual(ErrorCenter.shared.toasts.count, 2)
    }

    func testDismissRemovesToastById() {
        ErrorCenter.shared.surface("boom", level: .error, source: "X")
        guard let id = ErrorCenter.shared.toasts.first?.id else {
            return XCTFail("Expected at least one toast")
        }

        ErrorCenter.shared.dismiss(id: id)
        XCTAssertTrue(ErrorCenter.shared.toasts.isEmpty)
    }
}
