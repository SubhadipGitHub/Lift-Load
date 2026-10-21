---
name: add-ad-placement
description: Add or change a rewarded or interstitial ad placement in Lift Load safely. Use whenever a new ad offer, reward, or ad timing is requested.
---

# Add an ad placement

## Rules that never bend

- Rewarded is opt-in, labelled ("Watch ad · …", mint button, play icon), and pays only on the SDK reward callback.
- 12 rewarded views per day in total; each placement has a cap.
- Interstitials only via `InterstitialPolicy`: after a win, from L15, ≥ 3 levels and ≥ 180 s apart, ≤ 4 per session,
  never after a fail, never for payers.
- No ad interrupts play: not on level start, not during a send or crash animation.

## Steps

1. Write the placement spec: trigger moment, reward, cap, and which PRD gate metric it serves. Get the owner's OK.
2. Add the value to `RewardedPlacement` in `lib/services/ad_policy.dart`, with a `dailyCap` if it needs one.
3. Add a `canX` getter and an `X()` method in `GameController` that call `_showRewarded(placement)` and apply the
   reward only if it returns true. Save the profile after.
4. Add the button with `RewardedButton` from `lib/ui/widgets/result_sheets.dart` (keeps the mint styling).
5. Add a test in `test/ad_policy_test.dart` for the cap, and a widget or controller test for the reward.
6. Add the analytics expectation to `docs/analytics.md` if a new event or param is needed.
7. Update the monetization table in `docs/PRD.md`.
8. Ask the `monetization-auditor` agent to review the diff before committing.
