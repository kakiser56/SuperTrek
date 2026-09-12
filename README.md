# Super Trek

An iPhone remake of the 1978 BASIC "Super Star Trek" text game, built as a
pure Swift rules engine with a thin SwiftUI layer on top.

- `TrekEngine/` — the rules as a Swift package. No UI imports. `swift test` runs 60+ tests,
  including an autopilot that plays complete games.
- `SuperTrek/` — the iOS app. The Xcode project is generated from `project.yml`
  with [xcodegen](https://github.com/yonaskolb/XcodeGen): run `xcodegen generate`
  in that folder after changing the spec.
- `SuperTrek/Design/RenderIcon.swift` — renders the app icon.
- `SuperTrek/Store/` — App Store listing text and a length checker.

Franchise names are deliberately absent. Every renameable term lives in
`TrekEngine/Sources/TrekEngine/Lexicon.swift`.
