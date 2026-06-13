# Night Survival System — Hollow Township

> Status: FROZEN (reviewed 2026-06-13). Active night survival and day evolution loop.
> All decisions serve PILLARS.md. Pillar compliance tagged on every major decision.
> Review note: corrected Surveyor's Shadow appearance from the deprecated 3-day timing
> (Night 3) to the frozen 5-day timing (Night 4 pre-appearance, Night 5 climax) — now
> consistent with WORLD_STATE.md, CHAPTER_ONE.md, and TIME_SYSTEM.md.

---

## Design Mandate

Night gameplay is active survival. Day gameplay is evolution. The township can be destroyed.

This is not a change to the horror philosophy — it is the horror philosophy made concrete and physical.

The existing design made THE DEBT a consequence system. This document makes THE DEBT a presence. It arrives at night. It has rules. It can be countered. But every counter costs something the player built during the day, and what it targets is determined by what the player chose.

**The non-negotiable**: Night survival must remain about allocation and triage, not execution skill. A player who builds well and chooses well should survive — but survival is never clean. Every night that ends with the township standing ends with something changed. There is no clean defense. There is only the cost you chose to pay.

---

## Pillar Compliance Check

| Pillar | Threat | Resolution |
|--------|--------|-----------|
| Pillar 1 — Earned Dread | Creatures must not appear randomly | Creature spawn conditions are 100% derived from player day-choices. A player who made no choices generates no creatures. Creatures are THE DEBT made physical. |
| Pillar 2 — The Watched Feeling | Active survival might shift focus from NPCs to mechanics | Named NPCs are the defense assets. The player is not fighting creatures — they are deciding which people stand where. The cost of a failed defense is an NPC, not a health bar. |
| Pillar 3 — Moral Weight at Every Turn | Combat systems create "optimal play" paths that remove moral weight | No real-time combat. Night is resolved through allocation decisions (assign, sacrifice, hold, fall back). NOT-THIS.md rule preserved: "Night phase that can be solved with enough stat investment" is forbidden. |
| Pillar 4 — Day/Night Structure | Night survival must strengthen, not break, the Relief→Unease→Compulsion loop | Day = build defenses + make choices that determine what arrives (Relief). Night = survive what your choices summoned (Unease). Dawn = count what it cost (Compulsion). The loop is now physical. |
| Pillar 5 — Genre Whitespace | Active night survival risks sliding into tower defense or action-RPG | Night phase is strategic allocation, not real-time action. The player issues orders before night begins and cannot change them during. Night unfolds as a consequence sequence, not a reflex test. |

---

## The Creatures — Manifestations of THE DEBT

Creatures are not monsters. They are the ecological consequence of Harrow's Crossing's falsified land survey given physical form. THE DEBT doesn't send demons — it sends what was always in the western hollow, now able to reach the settlement because the player's choices opened the path.

### Design Principles

- **Every creature type is tied to a specific category of player choice.** There is no generic "night enemy." Each creature's presence is traceable.
- **Behavior is fully deterministic and learnable.** No RNG on what they do. Variance only in which specific NPC or building they target (determined by assignment/placement). Players learn the rules; the horror is that knowing the rules doesn't make the choices easier.
- **Creatures escalate across Chapter 1** — Night 1 is low intensity, a single creature type. Nights 2–3 compound. Night 4 introduces the Surveyor pre-appearance (witnessing only). Night 5 is the chapter climax: everything the player spent five days building either holds or it doesn't.
- **Creatures cannot be killed.** They can be slowed, redirected, or driven back by sufficient defense. Killing a manifestation of an eleven-year debt is not possible in Chapter 1. This is load-bearing for Pillar 3 — there is no "winning" the night, only surviving it at cost.

---

### The Three Creature Types (Chapter 1)

---

#### THE HOLLOW WALKERS
**What they are**: The oldest trees from the falsely surveyed western hollow, now ambulatory. Not fast. Not dramatic. They walk toward the newest structure in the settlement — the thing built most recently, on the edge of what was permitted.

**Spawn condition**: Player places a building adjacent to the hollow (Zone 5 adjacency) OR builds the incomplete structure's fourth wall (Peder's crew works toward the hollow all day). One Walker per building placed in violation. Spawns at Night 1 if the condition is met on Day 1.

**Behavioral rules** (fully learnable):
- Walkers always target the most recently constructed building in their path.
- They move one zone per hour of night.
- They cannot cross a watchtower's sightline if the watchtower has a named NPC assigned to it.
- They do not pursue NPCs — they pursue structures. An NPC in their path is endangered by proximity, not targeting.
- They stop at dawn. They do not retreat — they simply become still. Still Walkers block building access in the zone where they stopped.

**Counter**: A watchtower with an assigned NPC in the Walker's path stops its advance for that night. The NPC assigned to the watchtower pays a cost — their arc destabilizes (fear state, injury risk). The structure is saved. The person is changed.

**Pillar compliance**: The Walker exists because of a specific building decision. The counter requires assigning a named person to danger. The player chose to build; they now choose who stands between their building and what they summoned.

---

#### THE LEDGER WATCHERS
**What they are**: Not physical. Present as simultaneous equipment failure, mislaid supplies, and tools found exactly where they shouldn't be — in places that connect to the discrepancies in Maren's ledger. They are the falsified accounting, still seeking resolution.

**Spawn condition**: Player covers a ledger discrepancy instead of reporting it (Maren's accounting choice), OR accepts the Compact's resource surplus (which came from the hollow). Spawns Night 1 if triggered on Day 1; compounds on Night 2 if the cover-up is repeated.

**Behavioral rules**:
- Watchers do not have a physical form that can be blocked. They cannot be stopped with watchtowers.
- Each active Watcher degrades one resource stockpile per night — specifically the stockpile connected to the covered discrepancy.
- Watchers multiply: one Watcher on Night 1 becomes two on Night 2 if the discrepancy remains unaddressed.
- Watchers are neutralized only by transparency: the player reports the discrepancy to the Association on the following day. The reporting costs the player Compact trust and may trigger the Compact's labor-withdrawal response.
- Watchers cannot destroy a building. They can make the township functionally resource-starved by Night 3 if allowed to compound.

**Counter**: Disclosure. Tell the Association. Pay the political cost. The Watcher tied to that discrepancy disappears. The political consequence with the Compact arrives the next day.

**Pillar compliance**: The Watcher is the cover-up made physical. The only counter is the choice the player refused to make. The moral weight of Night 1's disclosure is now visible as a survival decision — but the choice still costs something real on Day 2.

---

#### THE SURVEYOR'S SHADOW
**What it is**: A single entity. First appears on Night 4 (pre-reckoning, witnesses only) and returns on Night 5 (chapter climax, marks or departs). The original surveyor — the person who filed the false paperwork eleven years ago — present now as something that walks the boundary between the permitted land and the falsely claimed hollow, measuring. It does not attack. It witnesses.

**Spawn condition**: Pre-appearance on Night 4 (witnesses only, does not mark — regardless of DEBT level). Marking appearance on Night 5 (chapter climax). Intensity on Night 5 is determined by accumulated DEBT. A player who has been transparent (reported discrepancies, refused to sign the Compact's ratification, approved Dix's inspection) faces a Surveyor that witnesses and departs. A player who has compounded the falsification faces a Surveyor that witnesses — and marks.

**Night 4 behavior (pre-reckoning)**: The Surveyor walks the Zone 3/5 boundary once. Does not mark. Every NPC with line-of-sight has arc state updated: they saw it. Permanent. At dawn after Night 4, the Surveyor's footprints are visible at the boundary — leading in, coming back out. It was measuring. A high-DEBT player's Surveyor pauses at the Zone 5 boundary before withdrawing. The pause is information. One day remains.

**Behavioral rules**:
- The Surveyor walks the Zone 3/Zone 5 boundary (Eastern Ridge to Western Hollow) once per night.
- It does not enter the settlement. It does not target NPCs or structures directly.
- Every NPC who has line-of-sight to the Surveyor during its walk has their arc state updated: they saw it. This is permanent. What they do with that knowledge is their arc.
- If THE DEBT is high (player compounded the falsification): the Surveyor marks the Zone 5 boundary. The mark means Zone 5 becomes accessible on Chapter 2 Day 1 — the hollow is now open. What is in it is Chapter 2's horror.
- If THE DEBT is low (player chose transparency): the Surveyor completes its walk and does not mark. Zone 5 remains closed. Chapter 2 begins with the false dawn anchor (the NPC investment anchor from CHAPTER_ONE.md).

**Counter**: There is no counter. The Surveyor cannot be blocked, redirected, or deterred. The only relevant action is what the player chose during Days 1–5. By Night 5, the accounting is done.

**Pillar compliance**: The Surveyor is Earned Dread at chapter scale. The player who played well faces a horror that witnesses and leaves. The player who compounded the lie faces the same entity — but it marks what they built. The macro choice weight lands because every micro and mid choice has already accumulated.

---

## Defense Systems — Day Evolution

Day is where defenses are built. These are not stat upgrades — they are moral infrastructure. Each defense system has a counterplay cost.

### Watchtowers
- Function: stop Hollow Walkers, provide sightline for Surveyor tracking
- Cost to build: Peder's crew time (delays the incomplete structure timeline — breaks the Association's trust if the structure timeline was promised)
- Staffing cost: an NPC assigned to a watchtower at night is in danger. The watchtower works only if someone is there. The someone is changed by being there.
- Placement moral grammar: a watchtower facing the treeline (Zone 3/Zone 5 boundary) enables Elias's reports. A watchtower facing inward (protecting Mill Quarter) protects resources but leaves the treeline dark. Both are valid defenses. Neither is free.

### Disclosure Records
- Function: neutralize Ledger Watchers
- Cost to build: the player formally records discrepancies — creates an official paper trail that the Compact can read, that Dix can read, that surfaces in the audit
- This is not a building — it is a Day phase choice in the faction negotiation UI (text-list option: "Log the discrepancy formally")
- Effect: one Watcher neutralized per disclosure. The political cost with the Compact arrives as a behavior change the following day.

### Perimeter Clearings
- Function: slow Hollow Walker advance (reduces their movement by one zone per night)
- Cost to build: Peder's crew clears the perimeter brush — one day of work, delays all other construction
- Placement choice: which direction to clear. Clearing toward Zone 5 slows Walkers from the hollow. Clearing toward Zone 3 protects the eastern ridge's watchtower access. One crew, one day, one direction.

### Assigned Night Watch Rotations
- Function: the player assigns NPCs to posts before night begins. Post assignments are locked at dusk. Cannot be changed during night.
- This is the primary night-survival mechanic: the player spends the last 30 minutes of the day phase assigning people to positions. Then the night unfolds.
- NPC at a defended post: blocks the relevant creature type for that zone. The NPC's arc is affected.
- NPC unassigned at night: they are in their quarters. Safer from direct threat. But their zone is undefended.
- Moral weight: the player cannot assign everyone everywhere. There are more zones than available NPCs for night watch. Every night is a triage of who stands where and who is left exposed.

---

## Night Phase Resolution — Allocation, Not Execution

Night does not play like a tower defense game. The player cannot issue orders after dusk.

### How Night Resolves

```
Dusk (player assigns final night watch positions — 2–3 minutes of real time)
    → All NPC assignments lock
    → Backend computes creature spawn list from day choices
    → Night Event Queue generated (pre-computation pipeline from ARCHITECTURE.md)

Night Phase (real-time, player observes only):
    → Creatures move per their behavioral rules
    → Assigned NPCs respond per their post rules
    → Consequences fire as WebSocket push events to narrative log
    → Player can pan/zoom camera, observe, cannot issue orders

Dawn:
    → Creature sequence completes
    → Consequence thread fires (REVEAL_MECHANIC.md dawn model)
    → Player surveys what changed: structures, NPC states, zone accessibility
```

The player's work is done before night begins. Night is the accounting.

This is deliberate. The horror of night is not "can you click fast enough." The horror is watching what your decisions summoned, unable to change them. The camera is the only freedom. The player can look. They cannot act.

### What Can Be Lost

- **NPCs**: an NPC on an overrun post can be injured (arc state: injured), traumatized (arc state: breaking), or removed from the game (arc state: gone). Gone is permanent. Chapter 2 begins without them.
- **Buildings**: a Walker that reaches a building damages it. Damaged buildings have reduced function. A building destroyed by a Walker is gone — the player's Day 1 choice of what to build there is now a scar in the world.
- **Stockpiles**: Watcher depredation reduces resource counts. If stockpiles reach zero in a category, the day phase mechanics that depend on that resource are unavailable until rebuilt.
- **Zone access**: a still Walker blocking a zone entrance makes that zone inaccessible at dawn until Peder's crew clears it — one day of work, delayed other construction.

The township cannot be fully destroyed in Chapter 1. At least one building and at least one NPC survive to Chapter 2. This is the floor. Above the floor, everything is at risk.

---

## The Day Evolution Loop

Day is not just preparation. It is the only time the township grows. Night cannot be used for construction.

### Evolution Layers

**Structural expansion**: New buildings extend the township's capacity — more NPCs housed, more resources processed, more defenses possible. Each new building is also a new potential Walker target and a new moral choice about who builds it, where, and what that placement means for the hollow's reach.

**Knowledge accumulation**: The player learns THE DEBT's rules through night observation. Night 1 teaches the Walker's movement pattern. Night 2 reveals the Watcher's compounding behavior. By Night 3 a player who has paid attention knows what will happen. When the Surveyor first appears on Night 4, they cannot stop it. They know, and they watch.

**NPC investment**: Named NPCs who survive nights become more capable — not through stat increases, but through behavioral arc progression. Elias who reported the treeline and was believed becomes a different watchman than Elias who reported and was ignored. Ruth who spoke about the ledger becomes a different foreman than Ruth who stayed silent. These are arc states, not upgrades. The player cannot grind an NPC into a combat asset. They can only give them conditions to change.

**Faction leverage**: Day choices with factions build or destroy the trust that determines what the township has access to at night. The Compact controls labor. The Association controls worker reliability. Dix controls whether the audit closes or escalates. Each faction relationship is a resource that day choices spend or accumulate.

---

## Brutality Parameters

The world is brutal. These are the specific rules that make it so.

- **NPCs do not respawn.** If Ruth is gone, she is gone. The player does not get a replacement foreman with Ruth's knowledge. The township continues without her, and it is worse for it.
- **Buildings do not auto-repair.** A damaged building requires Peder's crew and materials to fix. That is one day of work not spent on expansion, defense, or the Association's timeline commitment.
- **THE DEBT does not plateau.** Compounded choices compound consequences. A player who spent three days covering discrepancies faces Night 3 with Watchers multiplied and THE DEBT high. There is no catching up in Chapter 1. The accumulation is the lesson.
- **Night 5 always ends Chapter 1.** The Surveyor walks regardless. The chapter ends when it completes its walk. The player does not choose when the chapter ends.
- **Dawn after Night 5 is the state Chapter 2 inherits.** Every NPC gone, every building damaged, every Watcher still active at chapter end — that is the starting condition of Chapter 2. The false dawn anchor (CONCEPT.md) is the one thing that survived. What it costs to continue is Chapter 2's opening question.

---

## Night Watch Roster UI — Pre-Dusk Assignment

The night watch roster is the primary pre-night decision surface. It opens automatically 30 in-game
minutes before dusk (triggered by day cycle timer) as a soft panel. It can be dismissed. The player
can continue working after dismissing it. Dusk fires at its scheduled time regardless of whether
the player has confirmed assignments. If the player did not assign posts, those posts are empty.
The game does not hold the player at a confirmation screen. The horror is not the UI demanding
action — the horror is realizing at night that the eastern ridge is undefended.

**What it shows**:
- All available posts (watchtowers, perimeter positions, structure guard points)
- All NPCs available for night assignment (those not injured, not arc-broken)
- Current assignment status per post: STAFFED / EMPTY
- One line of each NPC's behavioral state (from NPC Behavior Agent — their current arc condition)
- On Night 2+: each post's last-night outcome as a single descriptor — e.g. "Eastern Ridge — quiet", "Zone 4 post — Walker reached here". No explanation. The player has earned this context by surviving the previous night. On Night 1 this field is blank — the player has seen nothing yet, which is the correct horror.

**Night 1 roster design rule**: On the first night, the player has no prior night data. The roster lists posts and NPCs with no consequence context. This is intentional. The player is making an assignment in the dark. The game does not compensate for this with tooltips or warnings. What Night 1 teaches is learned through the Dawn consequence thread — the player carries that knowledge into Night 2's roster, and the roster then reflects it. The learning curve is one cycle, not zero.

**Assignment rules**:
- Each NPC can be assigned to exactly one post
- Posts left EMPTY are undefended
- The player cannot over-staff a post — one NPC per post
- Assignments lock when the player confirms or when dusk triggers (whichever comes first)

**The moral surface**:
- The roster has more posts than NPCs. This is always true. There will always be an undefended post.
- The player's choice of WHICH post to leave empty is the night's primary moral decision.
- Injured NPCs appear on the roster but their effectiveness is reduced — assigning them is a choice.
- An NPC who was traumatized on a previous night appears with their arc state visible.
  The player can assign them again. The game does not prevent this. It only shows what they are now.

**After confirmation**:
- Roster closes. Cannot be reopened.
- Day phase ends. Night transition begins (GRAPHICS.md transition sequence).
- NPCs walk to their assigned posts. The player watches.
- Then it is night.

---

## Required Updates to Existing Documents

This document introduces new mechanics that require additions to frozen docs. These updates do not change frozen decisions — they add specificity.

| Document | Required Addition |
|----------|------------------|
| `WORLD_STATE.md` | Add creature definitions to Section 2 (The Horror). DEBT now has physical manifestations: Walkers, Watchers, Surveyor. Causal grammar table expands to include creature spawn conditions. |
| `ARCHITECTURE.md` | Night Event Queue must include creature position/movement data alongside narrative events. Horror Agent output schema needs: `creature_type`, `current_zone`, `target_type` (structure or NPC arc). |
| `CHAPTER_ONE.md` | Beat structure Night 1–5 sections need creature presence noted. Night 4 must specify the Surveyor pre-appearance (witnesses only); Night 5 must specify the Surveyor's marking/departing walk as the chapter-end trigger. |
| `GRAPHICS.md` | Walker, Watcher (non-physical), and Surveyor visual design needed. Walker: silhouette, no face, moves like something that was a tree. Watcher: environmental only (flickering light, misplaced tools — not a visible entity). Surveyor: a human figure at the treeline, seen from distance. Always at the boundary. Never closer. |
| `INTERACTION_MODEL.md` | Night watch assignment UI: player must be able to assign NPCs to posts in the last 30 minutes of day phase. This is a new UI surface — the night watch roster. Post assignment locks at dusk. |
| `WORLD_BACKSTORY.md` | NPC arrival backstories feed the behavioral state line on day 1. Each NPC's "what they are trying to get back to" is a voice register constraint — it surfaces in how they speak about their work. |

---

## What This Changes About the Experience

Before this system: the player made choices during the day and at night received text consequences about those choices. The horror was interpretive.

After this system: the player makes choices during the day and at night watches what those choices summoned walk toward the things they built. The horror is visible, physical, and traceable.

The game now has a win condition for each night: the township survives with its people intact. And it has a loss condition: NPCs gone, buildings destroyed, resources depleted. Neither outcome is random. Both outcomes are the player's.

The question the player asks at dawn is no longer just "what did I do?" It is: "was it worth it?"

That question is Earned Dread.
