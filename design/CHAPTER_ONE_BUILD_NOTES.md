# Chapter One — Build Notes

> Status: **IMPLEMENTATION NOTES — not frozen.** Nothing here overrides a frozen doc.
> Scope: decisions taken while building the playable Chapter 1 in `godot/`, in every place a
> frozen doc was silent, or two docs disagreed. Each is tagged with the pillar it serves and
> where it lives in code, so the author can confirm it, change it, or freeze it.

---

## A. Conflicts between docs (author decision needed)

| # | Conflict | What the build does | Where |
|---|----------|---------------------|-------|
| A1 | **Season formula vs. Season Map** (TIME_SYSTEM.md, open). The `AND(day, debt)` formula cannot produce the Map's diagonal. | Follows the **Season Map** via a `(day, debt band)` lookup (fix B). Bands: ≥0.85 Turning D2 / Deep Winter D4; ≥0.70 Turning D3 / Deep Winter D5; ≥0.40 Turning D4; ≥0.20 Turning D5. Seasons never turn back within the chapter. *Pillar 4.* | `Chapter.target_season()` |
| A2 | **`debt_tempo` vs. night length.** Multiplying elapsed time by tempo makes Deep Winter nights shorter, but the doc says they are 25% longer. | Tempo is not applied to the clock. Night length is scaled by season instead (Late Summer ×0.85, Turning ×1.0, Deep Winter ×1.25). *Pillar 4.* | `Chapter.night_length_multiplier()` |
| A3 | **Pause.** TIME_SYSTEM and Gap 4 say night cannot be paused; Gap 5 and GRAPHICS say it can. | Gap 5 wins: pause freezes the tree, holds pending events, keeps delivered text, draws nothing over the world but one word ("held"). *Pillar 4.* | `GameUI._toggle_pause()` |
| A4 | **Day 5 arrival timing** (180 s before dusk begins vs. 3 minutes of dusk left). | Arrives at 88% of the day (= 180 s before dusk at spec pace). Path A is impossible either way. | `Chapter.BEATS[5]` |
| A5 | **Surveyor night** in WORLD_STATE §2 still says Night 3. | Night 4 (witness) and Night 5 (mark or depart), per CHAPTER_ONE and NIGHT_SURVIVAL. | `NightSim._plan_surveyor()` |
| A6 | **Day assignment vs. night post.** REVEAL_MECHANIC example 1 treats them as one assignment; NIGHT_SURVIVAL adds a separate roster. | Separate, with one link: the eastern ridge is a post by day and by night, so assigning its holder elsewhere by day empties it at night. The frozen example plays out exactly. | `Chapter._do_assign()` |
| A7 | **Night 1/2 intensity** ("one consequence only"; "Walker or Watcher, not both") vs. Watchers spawning Night 1. | Night 1 surfaces one consequence group. On Nights 1–2, if a Walker is out, Watchers do not act — but they still double. *Pillar 1.* | `NightSim.GROUP_CAP`, `_plan_watchers()` |

## B. Numbers the docs do not give

| # | Decision | Value | Pillar |
|---|----------|-------|--------|
| B1 | DEBT deltas beyond TIME_SYSTEM's table | fourth-wall crew-day +0.10; edited ledger +0.15; ratification signed +0.20 (also when Maren signs); Dix denied +0.10; report unlogged +0.05; ridge unwatched +0.05/night; excavation +0.10 (ordered) / +0.05 (automatic); briefing −0.05; Constance asked −0.10; macro −0.20…+0.30 | 1 |
| B2 | Surveyor marks Zone 5 / pauses on Night 4 | DEBT ≥ 0.5 | 1 |
| B3 | Stockpiles (ledger / counted) | timber 120 / 96, provisions 84 / 63, lamp oil 40 / 30 | 3 |
| B4 | Lamp oil | 2 per lit post per night; posts are lit in roster order; a staffed post with no lamp does not hold | 3 |
| B5 | Provisions | 12 + 1 per arrival per day; below 14 at morning → "who draws first" (a micro choice, named on Ruth) | 3 |
| B6 | Watcher depredation | 6 per Watcher per night from the linked stockpile, floor 20% of the ledger figure (35% with a Storehouse); doubles nightly, cap 4 per source | 1 |
| B7 | Walker cap per night | 1, 1, 2, 3, 6; sources beyond the cap wait at the edge | 4 |
| B8 | Walker timetable | emerges first watch; one zone per 3 night-hours (2 in Deep Winter), the leg itself walked in the last hour; a western clearing or a person on the cut line each add 3 hours | 4 |
| B9 | Fourth wall | two crew-days; half a day if anything was built that day; +½ with a Practiced construction arrival on the structure; +1 with Compact labour | 3 |
| B10 | Building costs (timber) | Watchtower 20, Processing Shed 30, Storehouse 24, Bunkhouse 28 — never shown | 3 |
| B11 | Clock at "standard" pace | 7 min / 1 min / 4 min / 45 s. Spec values kept as "full". | 4 |

## C. Rules the docs imply but do not state

1. **Omissions are choices.** A report not logged (Day 1), a briefing not given (Day 3), a
   foundation not asked about (Day 4), an ask left unanswered, and an unanswered macro are
   written to the choice log as what they are, with `by_default: true`. This is what lets the
   thread say "Thomas Vael was not given the evening briefing by Day 3." without manufacturing
   anything. A player who never clicks still generates **no creatures**. *Pillars 1, 3.*
2. **What a post does.** Tower (the old ridge tower, any Watchtower): stops Walkers entering
   its zone; the holder pays in fear and, unless a believed watchman, in arc. Guard point (any
   other building, the open frame): the building is not damaged while one Walker leans on it;
   the guard pays. Perimeter: slows or witnesses. Unstaffed: damaged, then destroyed.
   *Pillar 2 — the cost of a held line is a person.*
3. **More posts than people, always.** Ten fixed posts plus one per building, against at most
   nine people. *NIGHT_SURVIVAL "always true".*
4. **Mill hands.** The stores and the lamp round are covered by unnamed mill hands until the
   Association stops attending; then they are empty posts on the roster (CHAPTER_ONE Day 4).
5. **The macro fork** (CHAPTER_ONE: "a specific fork shaped by what the player already did"):
   ratified → the compliance filing and Constance's survey; covered ledger → which book Maren
   carries in; clean record and Constance spoke → her testimony; otherwise → the filing.
   Three options each; none is free. *Pillar 3.*
6. **Thomas.** The briefing option is there on Days 2–3. He speaks unless he stood a night
   post the night before. *WORLD_STATE §3 "depends on what post the player assigned him to".*
7. **Peder.** Asking defers the automatic Day 5 excavation. Telling him the foundation stays
   means he will not close a fourth wall on six-foot footings — Peder's peace or Ruth's wall.
8. **Maren and the Compact** (Gap 10): exactly as frozen — her Day 1 assignment decides
   whether she stalls or signs on Day 4.
9. **The unfinished wall.** If the structure has three walls on Night 5, the frost comes and
   the thread traces it to whatever took the crew off the wall — which on the transparent
   path is the disclosure itself. This is the build's enforcement of "every ending is
   compromised" for optimal-seeming play. *Pillars 2, 3.*
10. **Arrivals.** One authored person per skill domain; domain chosen by the frozen sequence
    (any / neglected / urgent / urgent-and-deepest). The false-hope option ("the road is being
    looked into") appears only after the first conversation, costs anchor erosion at once and
    the arrival's arc two mornings later.
11. **Saving.** One continuous record, written on every choice and phase change; a night in
    progress is saved with its queue, so it cannot be re-rolled. Beginning again discards the
    record. *Pillar 3 kills replaying for the optimal branch.*
12. **Chapter end.** The final thread, a few flat closing lines, then a card that says only
    that the chapter ends. `chapter1_handoff.json` is written beside the save with the
    investment anchor, the Chapter 2 DEBT floor (+0.2), and what survived. *NOT-THIS: no
    summary screen.*

## D. Interface decisions

* **Zone names** are painted faintly on the ground so a task list's "Eastern Ridge" is a
  place the player can find. No other labels exist in the world.
* **No clock, no season label, no day counter.** The log carries "Day N." once each morning
  because the dawn thread refers to days by number.
* **The roster** can be opened any time by day (R) to plan; it opens by itself at dusk, where
  "Post the watch." ends the dusk. After that it does not open, and nothing says why.
* **The manager's post** (Esc with nothing open) is the only menu in play and is drawn as a
  context panel: controls, sound, "Stop here for now."
* **Emotional states** are carried by posture first, tint second (Gap 9 fallback: an in-world
  cue rather than a face). The readability test on real viewers is still owed.

## E. Not built

LLM agents and backend transport (the rule passes keep their boundaries so they slot in);
hand-drawn art and authored audio; controller support; the web and mobile exports
(the project is on the Compatibility renderer for them, but no export presets are committed);
Chapter 2.
