# zed-ios-app-starter

SwiftUI, SwiftData, iOS 18+, Xcode 26, no third-party dependencies.

<!-- template-only:start -->
A starter project to scaffold new iOS apps from, so the same shell doesn't get
rebuilt every time.

```sh
./scaffold.sh MyNewApp
open ../MyNewApp/MyNewApp.xcodeproj
```

That copies the template to a sibling directory, renames everything (target,
scheme, `@main` struct, bundle ID, StoreKit product IDs, this README) and makes
a first commit. See [Scaffolding](#scaffolding) for the options.


> [!NOTE]
> The repo is `zed-ios-app-starter`; the Xcode target inside it is
> **`AppStarter`**. Those differ on purpose — `AppStarter` is the placeholder
> that `scaffold.sh` replaces, and it has to be a valid Swift identifier
> because it becomes `struct AppStarterApp` (a hyphenated name wouldn't
> compile). Nothing needs renaming here; run the script and the generated
> project carries your name throughout.
<!-- template-only:end -->

## What's in it

- **Tab shell** — Home, Items, Settings, each with its own `NavigationStack`
- **SwiftData** — one `@Model`, wired through list → detail → edit → delete
- **Preferences** — `@Observable` object over `UserDefaults`, injected once
- **Onboarding** — paged walkthrough on first launch, replayable from Settings
- **Splash** — animated, over a matching launch-screen colour so there's no
  white flash
- **Theme** — spacing scale, radii, a `.card()` modifier, light/dark accent
- **Accessibility** — Reduce Motion helpers, combined VoiceOver labels
- **Optional: in-app purchases** — StoreKit 2, off by default
- **Optional: Claude API chat** — streaming, off by default

## Layout

```
zed-ios-app-starter/
├── scaffold.sh                    Rename-and-copy script
├── AppStarter.xcodeproj
│   └── xcshareddata/xcschemes/    Shared scheme (checked in, so CI works)
└── AppStarter/
    ├── AppStarterApp.swift        @main — container, environment, splash
    ├── Info.plist                 Launch screen only; the rest is generated
    ├── App/                       RootView (tabs), SplashView
    ├── Features/
    │   ├── Home/                  First tab
    │   ├── Items/                 List + detail over SwiftData
    │   ├── Onboarding/            First-launch walkthrough
    │   ├── Settings/              Preferences
    │   ├── Purchases/             StoreManager, PaywallView   (optional)
    │   └── AI/                    AnthropicClient, chat        (optional)
    ├── Models/                    Item (@Model), AppSettings
    ├── Store/                     Products.storekit
    ├── Support/                   Theme, Motion, Haptics, Keychain, previews
    └── Assets.xcassets/
```

**Adding files needs no project-file edits.** The target uses an Xcode
*file-system synchronized group*, so anything dropped into `AppStarter/` is
compiled automatically. New folders are picked up too. The only files that need
a `project.pbxproj` change are ones that must be *excluded* — currently
`Info.plist` and `Products.storekit`, both listed under `membershipExceptions`.

<!-- template-only:start -->
## Scaffolding

```
./scaffold.sh <ProjectName> [options]

  --bundle-id <id>        Default: wtf.zander.<ProjectName>
  --display-name <name>   Home-screen name. Default: <ProjectName>
  --dest <path>           Default: a sibling directory named <ProjectName>
  --no-git                Skip git init
```

`<ProjectName>` becomes a Swift type (`struct <Name>App`) and an Xcode target,
so it must be a plain identifier — letters, digits, underscores, not starting
with a digit. The script checks and refuses early rather than letting it fail
later as a confusing build error.

The copy excludes `.git`, build output, `DerivedData` and `xcuserdata`, and
deletes its own `scaffold.sh` from the result (that copy would have been
rewritten to refer to the new project, making it useless — the template keeps
the original).

`DEVELOPMENT_TEAM` is set to `C49QLB3U49` in the project so device builds work
without visiting Signing & Capabilities. Change it in `project.pbxproj` for a
different team.
<!-- template-only:end -->

## The pieces

### Preferences — `Models/AppSettings.swift`

`@AppStorage` only works inside a `View`, so anything a model needs ends up
threaded through the view tree. This is the same `UserDefaults` storage behind
an `@Observable` object: injected once in the app entry point, read anywhere
with `@Environment(AppSettings.self)`.

To add a preference: add a `Key`, add a property that reads it in `init` and
writes it in `didSet`. That's the whole pattern.

Writing to one from a view needs `@Bindable var settings = settings` at the top
of `body` — that's what turns an environment object into something `$`-bindable.

### SwiftData — `Models/Item.swift`

`@Query` in `ItemListView` handles fetching, sorting and live updates; inserting
or deleting through the `modelContext` re-renders the list with no manual
reload. `ItemDetailView` binds `TextField`s straight to the model, so edits save
themselves — which is why there's a delete confirmation but no save button.

**To remove SwiftData entirely:** delete `Models/Item.swift`,
`Features/Items/`, and `Support/PreviewData.swift`, then follow the compiler to
the four references — the `ModelContainer` and `.modelContainer()` in
`AppStarterApp.swift`, the Items tab in `RootView.swift`, the `@Query` and card
in `HomeView.swift`, and the debug section in `SettingsView.swift`.

### Theme — `Support/Theme.swift`

A 4pt spacing scale, three radii, and a `.card()` modifier. Colours that differ
between light and dark belong in `Assets.xcassets` as a colour set with a Dark
appearance (as `AccentColor` and `LaunchBackground` already do); semantic system
colours adapt on their own and are preferred where they fit.

If you change the splash background, change `LaunchBackground` to match — that
pairing is the only reason there's no flash at launch.

### Motion and haptics

Route anything that *moves*, *scales* or *rotates* through `.motion(_:value:)`
or `withMotion(_:reduceMotion:)` rather than calling `withAnimation` directly:
the state change still lands, it just lands instantly for people who asked for
that. Plain cross-fades can be left alone — Apple's guidance is to replace
movement with a fade, not to remove all change.

`Haptics` is gated on the user's preference, kept in sync from the app entry
point. Haptics are feedback, never information: everything they mark is also
visible on screen.

## Optional modules

Both ship **off**, switched in `Support/AppFeatures.swift`:

```swift
enum AppFeatures {
    static let purchases = false
    static let ai = false
}
```

The code is present and compiles either way — StoreKit and `URLSession` are
system frameworks, so an unused module costs nothing at runtime and there's
nothing to install. Flip a flag and its UI appears. If a project will never want
one, delete its folder and follow the compiler to the two or three references.

### In-app purchases — `Features/Purchases/`

StoreKit 2. `StoreManager` covers the three things every integration has to get
right:

1. **A transaction listener that outlives any one screen.** Purchases complete
   while backgrounded, on another device, or as an Ask-to-Buy approval days
   later. The listener runs for the life of the process, not the paywall.
2. **Entitlements as the source of truth.** `Transaction.currentEntitlements`
   is what the user owns *now* — restores and family sharing included, revoked
   purchases excluded. A local "did they buy it" flag drifts.
3. **Finishing transactions.** An unfinished transaction replays on every
   launch, forever.

`Store/Products.storekit` is referenced by the shared scheme, so purchases work
in the simulator with no App Store Connect setup — run, open Settings → Unlock
Pro, and buy. Xcode's Debug → StoreKit menu resets local transactions.

Before shipping: create the products in App Store Connect with the IDs from
`StoreManager.ProductID`, add the In-App Purchase capability, and replace the
placeholder terms text in `PaywallView`. For subscriptions or anything where
refunds matter, verify receipts server-side rather than trusting the device.

### Claude API chat — `Features/AI/`

A streaming client for the [Claude Messages API], written against `URLSession`
because there's no official Anthropic SDK for Swift. Defaults to
`claude-opus-5`; effort, model and token budget are properties on
`AnthropicClient`.

> [!WARNING]
> **Don't ship an API key inside the app.** Anything bundled with an iOS app —
> a constant, a plist entry, an obfuscated blob, a Keychain item written at
> first launch — can be extracted from the binary or the device, and a leaked
> key is billed to your account until you notice.

So the client has two modes. `.direct` sends `x-api-key` straight to Anthropic
and is for development on your own device; the key entry sheet in the chat
screen writes to the Keychain for exactly that. `.proxy` points at a server you
control, which holds the key and adds it server-side — and which is also where
per-user rate limiting, auth and abuse controls belong. The wire format is
identical, so going to production is a change of `Configuration` and deleting
the key sheet.

Two things the client handles that are easy to miss: a response can end with
`stop_reason: "refusal"` — a **successful** HTTP 200 where the model declined,
which is a normal outcome rather than an error — and thinking is on by default,
so `maxTokens` has to cover thinking *and* visible text or answers truncate
mid-sentence.

[Claude Messages API]: https://platform.claude.com/docs/en/api/messages

## Conventions

- **Swift 5 language mode.** Swift 6's strict concurrency checking is a lot of
  friction for a small app; switch `SWIFT_VERSION` to `6.0` in the project when
  you want it.
- **`@Observable`, not `ObservableObject`.** `@State` for ownership,
  `@Environment` for injection, `@Bindable` to write back.
- **Localisation is ready but not started.** `LOCALIZATION_PREFERS_STRING_CATALOGS`
  and `SWIFT_EMIT_LOC_STRINGS` are on, so adding a String Catalog
  (File → New → String Catalog) picks up every literal already in the code.
- **App icon is empty.** Drop a 1024×1024 PNG into `AppIcon.appiconset` — the
  build doesn't fail without one, it just looks unfinished on device.

## Build

Open the project in Xcode and run, or:

```sh
xcodebuild -project AppStarter.xcodeproj -scheme AppStarter \
  -destination 'generic/platform=iOS Simulator' build
```

The scheme is checked in under `xcshareddata`, so this works on a clean
checkout without opening Xcode first.
