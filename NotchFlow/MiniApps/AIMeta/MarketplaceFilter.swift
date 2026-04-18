import Foundation
import SwiftUI

/// Cross-view filter coordinator for the AI Meta marketplace sheet.
/// Owns search text and optional "focus" on a single plugin identity.
/// Both `AIConfigView` (tapping a provenance badge) and `MetaPluginCard`
/// (tapping "View on disk") publish focus changes through this object;
/// `AIMetaView` observes it to render filtered results.
///
/// Precedence rule: **`focusedIdentity` overrides `searchText` until
/// explicitly dismissed.** Setting focus clears the search text; typing
/// in search does NOT clear the focus. The intent is that once the user
/// navigates from AI Config → marketplace via a badge, the marketplace
/// stays scoped to that plugin until they dismiss focus (via an
/// explicit "back" affordance or closing the sheet).
@MainActor
final class MarketplaceFilter: ObservableObject {
    static let shared = MarketplaceFilter()

    @Published var focusedIdentity: PluginIdentity?
    @Published var searchText: String = ""

    enum FilterPredicate {
        case none
        case search(String)
        case focus(PluginIdentity)
    }

    /// Effective filter for the current sheet state. Focus wins.
    var activePredicate: FilterPredicate {
        if let id = focusedIdentity { return .focus(id) }
        if !searchText.isEmpty { return .search(searchText) }
        return .none
    }

    /// Enter focus mode. Clears search text (so the user doesn't see
    /// stale search state override the focus). The focus itself must be
    /// dismissed explicitly via `clearFocus()` — changing `searchText`
    /// afterwards is intentionally allowed (and effectless) so the user
    /// can see both "what's focused" and "what they're typing".
    func focus(_ id: PluginIdentity) {
        focusedIdentity = id
        searchText = ""
    }

    func clearFocus() {
        focusedIdentity = nil
    }

    /// Reset both state slots. Called when the marketplace sheet closes
    /// so the next open starts clean.
    func reset() {
        focusedIdentity = nil
        searchText = ""
    }
}
