# NotchFlow Architecture Roadmap

This doc captures the architectural improvement plan that followed the
first public-polish round. All four waves have shipped; this file is
kept as a reference for the intent behind the structural choices and
the "why" behind each change.

See also:
- PR #33 — off-main-actor fix for `AIConfigScanner` (Wave 1 seed)
- PR #34 — Wave 1: prewarm + persistent tabs + off-main `WorktreeScanner`
- PR #35 — Wave 2: `ErrorCenter` toast system + scan-token cancellation
- Waves 3 + 4 (single PR series):
  - `Core/DefaultsKeys.swift` + `Defaults` helper (Wave 3c)
  - `Core/ScannerDependencies.swift` with `SettingsProviding` /
    `PermissionsProviding` protocols (Wave 3a)
  - `NotchFlowTests/` XCTest target with ~19 tests (Wave 4a)
  - `MiniApps/MiniAppRegistry.swift` replacing the `MiniApp` enum (Wave 3b)
  - `AppDelegate` lifecycle cleanup — `NSWindowDelegate` callbacks
    replace the prior `asyncAfter`/`Task.sleep` hacks (Wave 4b)

The dedupe-test from Wave 4a also uncovered and fixed a real production
bug: path dedupe in both scanners now uses `resolvingSymlinksInPath()`
so `/var` and `/private/var` variants of the same file collapse.

## Recap — what Waves 1 and 2 already fixed

**Wave 1** moved every scanner's disk-walk off the main actor, hoisted
view-owned scanners into shared singletons, fired a prewarm at launch,
and switched `ExpandedView` to a `ZStack` of always-mounted tab views.
Net effect: clicking a tab for the first time is instant; state
survives tab switches.

**Wave 2** introduced `ErrorCenter` — a singleton that takes `.surface()`
calls and publishes them to a `ToastOverlayView` stacked on top of the
notch content. Replaced the `try?` swallow pattern in `NoteStorage`
load/save so the user actually sees when disk I/O fails. Added a
monotonic scan-token pattern in `AIConfigScanner` and `WorktreeScanner`
so the `isScanning` flag can't be left `true` by a cancelled scan.

## Wave 3 — Dependency injection, protocols, defaults registry

The remaining structural debt. All of these make the codebase **testable**,
which is the real unlock — Wave 4 hangs off it.

### 3a. Protocol-inject the manager singletons

`SettingsManager.shared` and `PermissionManager.shared` are touched from
every scanner's init via `SettingsManager.shared` / `PermissionManager.shared`.
This is fine at runtime but makes unit testing impossible — you can't swap
in a fake.

**Approach:**
```swift
protocol SettingsProviding: AnyObject {
    var aiConfigScanPaths: [String] { get }
    var worktreeScanPaths: [String] { get }
    // …only what scanners actually read
}

protocol PermissionsProviding: AnyObject {
    var grantedFolders: [GrantedFolder] { get }
}

extension SettingsManager: SettingsProviding {}
extension PermissionManager: PermissionsProviding {}
```

Scanners take `SettingsProviding` / `PermissionsProviding` in their init,
defaulting to `.shared`:
```swift
init(
    settings: SettingsProviding = SettingsManager.shared,
    permissions: PermissionsProviding = PermissionManager.shared
) { … }
```

Runtime behavior unchanged. Tests inject a fake. Low risk, high testability
payoff.

### 3b. `MiniApp` protocol for tab registration

Adding a new mini-app today requires editing three files:
1. Create `NotchFlow/MiniApps/<Name>/<Name>View.swift`
2. Edit `MiniApp` enum in `NavigationState.swift`
3. Edit the switch in `ExpandedView.swift` (or the `ZStack` now)

**Approach:** turn `MiniApp` into a protocol, collect instances in a registry.
```swift
protocol MiniApp {
    var id: String { get }
    var title: String { get }
    var icon: String { get }
    var description: String { get }
    func view() -> AnyView
    func prewarm()
}

enum MiniAppRegistry {
    static let all: [MiniApp] = [
        WorktreeMiniApp(),
        AIMetaMiniApp(),
        FogNoteMiniApp(),
    ]
}
```

`ExpandedView` iterates `MiniAppRegistry.all`. `AppDelegate.prewarmMiniAppState()`
calls `app.prewarm()` for each. `NavigationState.activeApp` becomes a
`MiniApp.ID`. Adding a new tab = drop in one struct + one line in the registry.

### 3c. `DefaultsKeys` registry

Every `UserDefaults.standard.string(forKey: "someKey")` is a ticking bomb
for typos and data-loss-on-rename. Today there's no central place that
lists every key the app uses.

**Approach:** one file, `Core/DefaultsKeys.swift`:
```swift
enum DefaultsKeys {
    static let grantedFolderPaths   = "grantedFolderPaths"
    static let metaMarketplaceURLs  = "metaMarketplaceURLs"
    static let onboardingComplete   = "onboardingComplete"
    static let accentColor          = "accentColor"
    // …every key referenced in the codebase
}
```

Plus a thin typed-access helper:
```swift
enum Defaults {
    static func string(_ key: String) -> String? {
        UserDefaults.standard.string(forKey: key)
    }
    static func setString(_ key: String, _ value: String?) { … }
    static func stringArray(_ key: String) -> [String] { … }
    // etc.
}
```

Every access site goes through `Defaults.xxx(DefaultsKeys.yyy)`. Typos
become compile errors; key renames become one-liners.

## Wave 4 — Quality gates

### 4a. Test target + first unit tests

Once Wave 3a ships (injectable scanners), add an XCTest target. First
tests should cover:

- **Scanner dedupe** — two paths that find the same config item produce
  one output, not two.
- **Glob matching** — `*.prompt.md` matches correctly; `*.instructions.md`
  excludes `copilot-instructions.md`.
- **Worktree parsing** — main-worktree detection, linked-worktree pointer
  resolution, detached HEAD handling.
- **ErrorCenter coalescing** — `.surface(source:)` with the same source
  replaces rather than stacks.

Target size: ~15–20 tests. Uses fake file-system fixtures under
`TestResources/`.

### 4b. Replace brittle sleeps with lifecycle observation

`AppDelegate` has three hardcoded timing hacks:

- `Task.sleep(for: .milliseconds(500))` before `notchManager?.expand()` at
  launch (`AppDelegate.swift:23`)
- `Task.sleep(for: .milliseconds(250))` before `notchManager?.expand()`
  after onboarding (`AppDelegate.swift:144`)
- `DispatchQueue.main.asyncAfter(deadline: .now() + 0.1)` to reset window
  level after focus (`AppDelegate.swift:133, 202, 246`)

**Approach:** use `NSWindowDelegate` callbacks (`windowDidBecomeKey`,
`windowDidUpdate`) or SwiftUI's `.onAppear` / `.onChange` on relevant
state. The sleeps work on dev machines but break on cold boots, slow
hardware, or when other apps are launching simultaneously.

### 4c. `CleanupScanner` audit (small, possibly-skip)

`CleanupScanner` runs on `@MainActor` but its work is mostly async git
subprocess calls, so it's not a UI-blocking offender. Still worth an
audit to make sure it respects cancellation the same way the two main
scanners now do. Low urgency — the scanner only runs when the user opens
the "Cleanup candidates" view explicitly.

## Sequencing

Recommended order inside the Wave 3/4 PR series:

1. **PR — DefaultsKeys registry** (Wave 3c). Smallest, isolated,
   immediately reduces typo risk.
2. **PR — Protocol injection for scanners** (Wave 3a). Unblocks testing.
3. **PR — Test target + scanner tests** (Wave 4a). Payoff realized.
4. **PR — `MiniApp` protocol + registry** (Wave 3b). Bigger refactor, but
   purely additive if done carefully.
5. **PR — AppDelegate lifecycle cleanup** (Wave 4b). Optional polish.

Total estimated scope: ~3–5 days of focused work. None of these are
user-visible improvements — they're foundation work. Prioritize them
when the UX is stable (post Waves 1–2) and before scaling the mini-app
count.

## Anti-goals

A few things the review flagged that aren't worth doing:

- **Full DI container (Resolver, Swinject, etc.)** — overkill for 5
  singletons and 3 scanners. Protocol defaults via init are enough.
- **Reactive everything / replace Combine with structured concurrency
  end-to-end** — current mix is fine; rewriting working code isn't
  architecture, it's churn.
- **Abstract base class for scanners** — tempting because of surface
  similarity, but the two scanners have diverged enough (worktree needs
  git-status enrichment, config scanner doesn't) that a base class would
  carry generic-at-the-seams deadweight. Leave them as sibling concrete
  implementations.
