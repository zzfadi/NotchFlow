import XCTest
@testable import NotchFlow

final class ScannerSkipListTests: XCTestCase {
    /// The core reason this list exists — walking into these from a broader
    /// grant fires a TCC dialog per folder.
    func testSkipsTCCProtectedMediaFolders() {
        XCTAssertTrue(ScannerSkipList.shouldSkip(directoryName: "Music"))
        XCTAssertTrue(ScannerSkipList.shouldSkip(directoryName: "Movies"))
        XCTAssertTrue(ScannerSkipList.shouldSkip(directoryName: "Pictures"))
        XCTAssertTrue(ScannerSkipList.shouldSkip(directoryName: "Downloads"))
    }

    func testSkipsBuildOutputAndPackageCaches() {
        XCTAssertTrue(ScannerSkipList.shouldSkip(directoryName: "node_modules"))
        XCTAssertTrue(ScannerSkipList.shouldSkip(directoryName: "DerivedData"))
        XCTAssertTrue(ScannerSkipList.shouldSkip(directoryName: ".build"))
        XCTAssertTrue(ScannerSkipList.shouldSkip(directoryName: "Pods"))
    }

    func testDoesNotSkipOrdinaryProjectFolders() {
        XCTAssertFalse(ScannerSkipList.shouldSkip(directoryName: "src"))
        XCTAssertFalse(ScannerSkipList.shouldSkip(directoryName: "Sources"))
        XCTAssertFalse(ScannerSkipList.shouldSkip(directoryName: "Projects"))
        XCTAssertFalse(ScannerSkipList.shouldSkip(directoryName: "Developer"))
        XCTAssertFalse(ScannerSkipList.shouldSkip(directoryName: "my-repo"))
    }

    /// Matching is exact — "music" (lowercase) is a user directory, not the
    /// TCC-protected one.
    func testMatchIsCaseSensitive() {
        XCTAssertFalse(ScannerSkipList.shouldSkip(directoryName: "music"))
        XCTAssertFalse(ScannerSkipList.shouldSkip(directoryName: "downloads"))
    }
}
