# Super Trek

An iPhone and iPad game, published on the App Store as "Super Trek 1978", that ports the rules of the 1978 BASIC listing of the 1971 text game to a touch interface. The look is green phosphor on a black terminal; the feel the owner is after is the Commodore 128 versions of the game: screen flash and sound on hits, sound on movement, red condition styling.

## Layout

- `TrekEngine/` is the whole game as a Swift package with no UI imports: seeded galaxy generation, `Game.apply(_:)` returning typed `Event`s, and `Narrator`, which renders events as teletype text. Rule changes belong here, with tests.
- `SuperTrek/` is the SwiftUI app, a thin layer over the engine. `GameStore` owns the game, the log, and the save file. `BridgeView` uses the phone layout below 700×700 points and the iPad boards (`BoardViews.swift`) at or above it, in landscape or portrait.
- `SuperTrek/SuperTrek.xcodeproj` is generated from `SuperTrek/project.yml` by `xcodegen generate`. Put build settings, signing, versions, and new targets in `project.yml`; changes made in Xcode's UI are lost on the next regeneration. Regenerate after adding or removing source files.
- `SuperTrek/Store/` holds the App Store listing and privacy policy text that the owner pastes into App Store Connect. `check.py` verifies field lengths.
- `SuperTrek/Design/RenderIcon.swift` renders the app icon into the asset catalog. Compile it with `swiftc` and pass the output PNG path.

## Names and trademarks

The game is a public domain program, but the franchise it imitated is not. Keep franchise names out of engine text, UI text, and store metadata. Every renameable term (ship, enemy kinds, alliance, weapons, glyphs) lives in `TrekEngine/Sources/TrekEngine/Lexicon.swift`; add new names there rather than inline. The engine's `NarratorTests` fail if a banned franchise word appears in narrated text.

App Review has rejected store metadata three times under guideline 4.1(a) for resembling other titles, and the listing file's "Review notes" section records what triggered each one. In metadata, avoid naming the BASIC or UNIX titles, pairing "star" with the "Trek" in the app name, pairing "starship" with "command" (Acornsoft's Starship Command), and pairing "space" with "invaders" (Taito). Screenshots count as metadata too.

## Building and testing

The owner usually has the project open in Xcode, which locks the shared build database, so command-line builds pass a private `-derivedDataPath` (a scratch directory works). Simulators are shown in DeviceHub rather than a Simulator app; use the iPhone 17 Pro on iOS 26.5, which is the one the owner watches.

```
cd TrekEngine && swift test
cd SuperTrek && xcodegen generate
xcodebuild -project SuperTrek/SuperTrek.xcodeproj -scheme SuperTrek \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath <scratch>/DerivedData test
```

The UI tests drive real taps and take about a minute. Run them after any change to the app layer; run `swift test` after any engine change. The engine's line-width tests keep narrated prose within the log's width, and the autopilot tests play complete seeded games.

Launch arguments stage specific screens for screenshots and UI tests:

- `-autoFixture battle` loads a hand-built quadrant with a warbird, stars, and a starbase.
- `-autoStartSeed N` starts a fresh seeded game; `-autoCommands NAV,LRS,TOR,SRS,DAM,COM1,COM2` then runs those commands.
- `-autoPanel nav|torpedo|computer|help` opens a control panel or the computer sheet.
- `-freezeBursts YES` holds explosions and torpedo flights mid-animation.
- `-resetSave YES` discards the saved game, so the new mission screen appears.

For iPad landscape screenshots, run the UI test `testHoldLandscapeForScreenshot` on the iPad Pro 13-inch (M5) simulator with `TEST_RUNNER_HOLD_LANDSCAPE=1` in the environment; it rotates the app and holds the screen.

## Conventions

- Animation start times live in model data (`Shot.fired`, `Burst.started`), never in a view's `let start = Date()`. SwiftUI rebuilds views when the grid changes, and a clock stored in a view restarts the animation.
- The log stores narrated lines unwrapped; `LogView` wraps them to the column count its width allows. The narrator's wrap keeps `row , col` coordinates on one line.
- The saved log carries a format version in `GameStore`. Bump it when the log's rendering changes, so old logs are dropped on load while the game itself is kept.
