# Analytics events

Every event the gates in `docs/PRD.md` depend on. Names are a contract with the dashboards: rename only together
with this file. Logged through `AnalyticsService` (`DebugAnalytics` in M1, Firebase in M3).

| Event | Params | Fired when | Feeds |
| --- | --- | --- | --- |
| `level_start` | level, difficulty, trips, venue, scenario (if any), attempt, lanes, unknown_share (% of residents) | A level is created | Funnel, Gate A clear rate |
| `level_win` | level, venue, trips_used, trips_total, perfects, coins, attempt, continues, powers_used | Everyone delivered | Win rate per level, Hard 45–55% target |
| `level_fail` | level, venue, scenario (if any), kind (crash / outOfTrips / jam), trips_used, attempt, powers_used | A fail screen appears | Fail mix, unfair-crash review |
| `overload` | level, type, cargo, lift_kind, scenario (if any), riders | The cable snaps | Which types, props and lift kinds players misjudge |
| `trip_sent` | level, rating, fill_pct, riders, lift_kind | Send pressed | Fill distribution, push-your-luck behaviour |
| `level_abandon` | level, via (restart / quit), trips_used, attempt, powers_used | A started level is restarted or left (costs a life) | Rage-quit rate per level, lives sink |
| `scale_used` | level, left | Scale booster used | IAP intent |
| `power_used` | power (swap / seats / trip / express), level, left, trips_used | A power is spent | Which powers carry difficulty; uses per level |
| `power_empty_tapped` | power, level | A power is tapped with none in stock | Demand for refills, the best moment to offer one |
| `power_refill_ad` | power, level, stub (true in tester builds) | Rewarded ad earned a power use | Rewarded views per DAU, refill opt-in |
| `power_bought` | power, coins, level | Coins spent on a power | Coin sink; price sensitivity |
| `unknown_revealed` | level, lane | An unknown person reaches a lane front | How often the mystery pays off; reveal pacing |
| `coin_continue` | level, kind | 300-coin continue | Economy sink |
| `rewarded_offer_accepted` | placement, level | Player taps a rewarded button | Opt-in rate |
| `rewarded_complete` | placement | SDK reports reward earned | Rewarded views per DAU (≥ 2.5) |
| `interstitial_shown` | level | Interstitial displayed | Ad load vs retention |
| `setting_changed` | setting (sound / music / haptics / left_handed), on | A settings toggle is flipped | How many mute, and whether muters churn faster |
| `crash_fairness` | level, attempt, fair | Tester build: the tester taps Fair or Unfair on a crash sheet | Gate A "crashes called unfair" |
| `exit_heavy_types` | level, answer (free text), skipped | Tester build: once, on the first win from level 15 | Gate A "names the heavy types" |
| `exit_unknown_fair` | level, fair (absent when skipped), skipped | Tester build: once, on the first win from level 13 on a level with unknown people, never on the heavy-types win | Gate A with powers on: "unknown people felt fair" |
| `test_complete` | level | Tester build: level 60 won | Gate A completion |

`attempt` is 1 on the first try at a level and counts up on every Retry or restart (stored per level in the
profile); `continues` counts the repairs and extra trips a won attempt used. Together they give Gate A's
first-attempt win rate. The tester build keeps the level, overload and tester events on the device with a timestamp;
see docs/gate-a.md.

The cast learnability check for Gate A: the share of `overload` events caused by the gym regular should fall as
players pass level 60; if it does not, the "liar" is unfair and needs a stronger visual cue. The same check applies to
the puffer-jacket teen (the inverse liar shows up as under-filled trips, not overloads: watch `trip_sent` fill_pct on
L45–60) and to cargo, by the `cargo` param on `overload`. For World 2, compare `overload` on `lift_kind` = old against
normal: if old lifts dominate crashes, the cabin cue is too weak.
