import XCTest
@testable import NotchFlow

/// Tests the precedence rules on `MarketplaceFilter`. Focus overrides
/// search until explicitly dismissed; setting focus clears the search
/// text; typing in search does NOT clear focus.
@MainActor
final class MarketplaceFilterTests: XCTestCase {

    private func makeFilter() -> MarketplaceFilter {
        // Not using the shared singleton to keep tests isolated.
        MarketplaceFilter()
    }

    private let sampleIdentity = PluginIdentity(
        canonicalSource: "github:anthropic/security-audit",
        marketplaceId: "mk-1",
        pluginName: "security-audit"
    )

    // MARK: - Predicate resolution

    func testNoFilterWhenEmpty() {
        let f = makeFilter()
        if case .none = f.activePredicate { /* ok */ } else {
            XCTFail("Expected .none, got \(f.activePredicate)")
        }
    }

    func testSearchTextProducesSearchPredicate() {
        let f = makeFilter()
        f.searchText = "security"
        if case .search(let text) = f.activePredicate {
            XCTAssertEqual(text, "security")
        } else {
            XCTFail("Expected .search, got \(f.activePredicate)")
        }
    }

    func testFocusProducesFocusPredicate() {
        let f = makeFilter()
        f.focus(sampleIdentity)
        if case .focus(let id) = f.activePredicate {
            XCTAssertEqual(id, sampleIdentity)
        } else {
            XCTFail("Expected .focus, got \(f.activePredicate)")
        }
    }

    // MARK: - Precedence

    func testFocusClearsSearchText() {
        let f = makeFilter()
        f.searchText = "existing-query"
        f.focus(sampleIdentity)
        XCTAssertEqual(f.searchText, "", "focus() must clear searchText")
    }

    func testFocusOverridesSearchEvenIfUserTypesAfter() {
        let f = makeFilter()
        f.focus(sampleIdentity)
        f.searchText = "this should not take over"
        if case .focus(let id) = f.activePredicate {
            XCTAssertEqual(id, sampleIdentity,
                "Focus must beat search until explicitly cleared")
        } else {
            XCTFail("Expected .focus to remain active")
        }
    }

    func testClearFocusRestoresSearch() {
        let f = makeFilter()
        f.focus(sampleIdentity)
        f.searchText = "post-focus"
        f.clearFocus()
        if case .search(let t) = f.activePredicate {
            XCTAssertEqual(t, "post-focus")
        } else {
            XCTFail("Expected search to come back after clearFocus()")
        }
    }

    func testResetClearsBoth() {
        let f = makeFilter()
        f.searchText = "query"
        f.focus(sampleIdentity)
        f.reset()
        XCTAssertNil(f.focusedIdentity)
        XCTAssertEqual(f.searchText, "")
    }
}
