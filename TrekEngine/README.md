# TrekEngine

The rules of the 1978 "Super Star Trek" BASIC game as a pure Swift package.
No UI imports, every type is a `Sendable` value, and a whole game is `Codable`.

- `Game.start(seed:)` builds a galaxy and returns the opening events.
- `game.apply(_ command:)` plays one turn and returns `[Event]`.
- `Narrator` renders events as the teletype lines; `Lexicon` holds every
  name that could be renamed (ship, enemy, weapons, officers, glyphs).
- `Game(fixture:)` builds a hand-laid situation for tests and previews.

Run `swift test` from this directory. The `FullGameTests` autopilot plays
complete games across many seeds to prove they always terminate.

Deliberate departures from the listing are commented in the source: the
beam-accuracy penalty is keyed to the computer rather than shield control,
a starbase-less galaxy is fixed sanely, and stardates are rounded to avoid
float drift.
