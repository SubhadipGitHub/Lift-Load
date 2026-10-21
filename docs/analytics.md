# Analytics events

Every event the gates in `docs/PRD.md` depend on. Names are a contract with the dashboards: rename only together
with this file. Logged through `AnalyticsService` (`DebugAnalytics` in M1, Firebase in M3).

| Event | Params | Fired when | Feeds |
| --- | --- | --- | --- |
| `level_start` | level, difficulty, trips | A level is created | Funnel, Gate A clear rate |
| `level_win` | level, trips_used, trips_total, perfects, coins | Everyone delivered | Win rate per level, Hard 45–55% target |
| `level_fail` | level, kind (crash / outOfTrips / jam), trips_used | A fail screen appears | Fail mix, unfair-crash review |
| `overload` | level, type, riders | The cable snaps | Which types players misjudge (cast learnability) |
| `trip_sent` | level, rating, fill_pct, riders | Send pressed | Fill distribution, push-your-luck behaviour |
| `scale_used` | level, left | Scale booster used | IAP intent |
| `coin_continue` | level, kind | 300-coin continue | Economy sink |
| `rewarded_offer_accepted` | placement, level | Player taps a rewarded button | Opt-in rate |
| `rewarded_complete` | placement | SDK reports reward earned | Rewarded views per DAU (≥ 2.5) |
| `interstitial_shown` | level | Interstitial displayed | Ad load vs retention |

The cast learnability check for Gate A: the share of `overload` events caused by the gym regular should fall as
players pass level 60; if it does not, the "liar" is unfair and needs a stronger visual cue.
