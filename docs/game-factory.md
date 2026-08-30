# A small game factory, not a generic engine

EST is the first game in a prospective family of compact, tactile tabletop
games. The aim is to reuse proven interaction mechanics without forcing every
future game through EST's card rules or visual language.

## The boundary

| Reusable foundation | EST product code |
| --- | --- |
| Claim timing, lockouts, and exclusive answering | Choosing exactly three cards and judging an EST |
| Game Center authentication, presentation, and score delivery | EST leaderboard IDs, centiseconds, and eligibility checks |
| Matchmaker player limits | EST's two-to-four player policy |
| Button roles and palette positions | Card traits, card artwork, and named card tints |
| Host-authoritative snapshot pattern | EST wire events and snapshot fields |

The rule is simple: a foundation type may know about players, scores, time, or
a palette position, but it must not import `Card`, `GameEngine`, an EST variant,
or an EST leaderboard identifier.

## Changes made now

### `ClaimRace`

`ClaimRace<PlayerID>` owns first-claim-wins behaviour, claim deadlines,
escalating lockouts, and penalty history. It is a value type with injected time
on every decision, which makes it deterministic and straightforward to test.
It deliberately does not schedule timers or decide what constitutes a correct
answer.

`PartySession` and the host side of `NetworkPartySession` now use that one
state reducer. Their adapters retain EST-specific responsibilities:

- Party mode gives a successful player three collected cards and one point.
- EST decides that an expired or invalid trio costs a point.
- The network host schedules expiry and broadcasts EST's full state snapshot.
- Clients adopt host-provided remaining-time values onto their local clocks.

This is the first extraction because the same behaviour was already duplicated
between local and network party play. It is ready for future buzzer, quiz, and
reflex games without requiring any card logic.

### Game Center and matchmaking

`GameCenterManager` now only authenticates, displays a supplied leaderboard,
and submits a prevalidated `GameCenterScore`. `ESTLeaderboard` holds the EST
leaderboard IDs and rejects paused or implausibly fast completion times before
creating that score.

`MatchmakerView` accepts `MatchmakerConfiguration` instead of reading
`PartySession` directly. A future game can choose its own player range while
using the same Game Center sheet.

### Palette tokens

`GameAccent` gives reusable game chrome four palette positions: `first`,
`second`, `third`, and `danger`. EST maps the first three to its red, blue,
and yellow card palette through `Appearance`; card rendering continues to use
`Card.Tint`. `GameButtonStyle` depends on `GameAccent`, so a different game
can reuse the control vocabulary without inventing EST cards just to colour a
button.

## Deliberate non-extractions

`GameEngine` remains EST code. Its starting table size, replace-in-place
behaviour, and deal-until-a-valid-set loop are the game, not a generic deck
engine. Likewise, `Card`, `CardView`, `BoardGridView`, `PlayerStats`, tutorial
content, and the current `NetMessage` schema are intentionally product-owned.

The synthesized audio implementation is also left in EST for now. Extract a
sound-bank player only when a second title needs distinct sounds; extracting it
earlier would create a generic API without a genuine consumer.

## What earns the next extraction

Build a second title before creating a Swift package. `THIRD` (find the unique
third card from two visible cards) would reuse EST's ternary puzzle algebra;
`SIGNAL` (a multiplayer reflex game) would reuse `ClaimRace`, matchmaking, and
host authority while proving the factory works without the SET table rules.

When one of those games exists, move only its shared, unchanged code into a
local `TabletopKit` package. Until then, keeping these files in EST makes their
dependencies obvious and keeps refactoring cheap.
