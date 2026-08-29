# EST

A free, open source card game for iPhone, made in the spirit of SET.

The deck has 81 square cards, one for every combination of four traits: count
(1, 2, 3), color (red, blue, yellow), shape (circle, square, triangle), and
fill (solid, translucent, outline). Find three cards where each trait is
either the same on all three or different on all three. Race the deck alone
against a Game Center leaderboard, pass one phone around the table, or play
live across devices.

## Why

I love SET. I have given away more copies of it than of any other game. The
structure behind it is pure mathematics: the deck is the affine space AG(4,3),
the same object at the center of the cap set problem, and it existed before
any card was printed. EST is my interpretation of that structure, drawn from
first principles: square cards, elementary shapes, a name that refuses to sit
still. It shuffles its own letters while you watch.

EST is an homage, not a substitute. If you have never held the original,
[buy a copy of SET](https://www.playmonster.com/brands/set/). It is a perfect
object.

## The mathematics

Each card is a point in AG(4,3), the four-dimensional affine space over the
field with three elements. Write a card as four base-3 digits (count, color,
shape, fill) and a valid set is exactly a line: three points whose
coordinates sum to zero in every position. That is why any two cards have one
and only one completing third, and why the deck's 81 points carry exactly
1080 lines.

The zero-sum rule has table-level consequences you can watch in the app. The
whole deck sums to zero and every removed set sums to zero, so the leftover
at the end of a game always sums to zero too. A leftover of exactly 3 cards
would itself be a set, so it cannot happen: you finish with 0 cards (a
perfect clear) or with 6 or more that hide no set.

A group of cards with no set in it is called a cap. Random 12-card tables are
capless often enough that the game regularly deals 15. The largest possible
cap in this space has 20 cards, proved by Giuseppe Pellegrino in 1971, which
is why 21 cards always contain a set. How caps grow as the dimension rises
stayed open for decades until Croot, Lev, Pach, Ellenberg and Gijswijt
settled the growth rate in 2016, one of the cleanest breakthroughs in recent
combinatorics. The endgame screen tells you which cap you finished against.

Reading: Davis and Maclagan, "The Card Game SET" (Mathematical
Intelligencer, 2003); McMahon, Gordon, Gordon and Gordon, "The Joy of SET"
(Princeton, 2016); Ellenberg and Gijswijt, "On large subsets of F_q^n with
no three-term arithmetic progression" (Annals of Mathematics, 2017).

## Relationship to SET

SET is a registered trademark of Cannei, LLC, and the game is published by
PlayMonster LLC. EST is not affiliated with, sponsored by, or endorsed by
either company. This project uses its own name, artwork, and code, and
mentions SET only to credit the inspiration.

## Playing

- **Solo 81**: clear the whole deck as fast as you can. Completion time goes
  to a global Game Center leaderboard. A hint marks the run and keeps it off
  the board.
- **Quick 27**: the 27 solid cards, 9 on the table, its own leaderboard. One
  trait drops out, so it plays fast.
- **Duel (one phone)**: two players, buzz buttons on opposite edges. See a
  valid trio, hit your button, and you get 3 seconds to tap the cards. Misses
  cost a point and a short lockout.
- **Duel (two phones)**: same rules over Game Center, online or nearby.

## Building

Requires Xcode and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```
xcodegen generate
xcodebuild -project EST.xcodeproj -scheme EST -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_ALLOWED=NO
```

The project file is generated; edit `project.yml`, never the `.xcodeproj`.
Game Center features need an App Store Connect record with a leaderboard named
`est.solo.completion.time` (elapsed time, ascending).

## License

MIT. See [LICENSE](LICENSE). The license covers the code and artwork in this
repository. It grants no rights to the SET trademark.
