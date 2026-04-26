# NPC Inflow & Productivity System — Hollow Township

> Status: IN PROGRESS (2026-04-26). Extends WORLD_BACKSTORY.md inflow mechanic.
> Reference model: Fallout Shelter (skill matching, room assignment, settling curves, risk/reward).
> Adapted for Hollow Township's pillar constraints — no stat bars, no happiness meters, no optimal play paths.
> Pending review before freeze.

---

## Design Mandate

The game cannot endlessly punish. THE DEBT compounds. Creatures arrive. NPCs die. If the only inputs to the player's situation are depletion and loss, the loop breaks — not because it's too hard, but because it has no grammar of hope.

NPC inflow is the silver lining. Every arrival is a productivity opportunity. But it is never free. The same mechanic that gives the player more capacity is the one that asks them to treat a frightened person as a resource. The tension is load-bearing. It cannot be resolved in favor of either side without breaking a pillar.

**The Fallout Shelter model, adapted**:
- Fallout Shelter: dwellers arrive with SPECIAL stats, assigned to matching rooms, produce resources, level up over time, can be rushed at risk.
- Hollow Township: arrivals carry former-life skills, assigned to matching roles, produce output that grows with integration time, can be rushed at moral cost rather than random risk.

The difference: Fallout Shelter's rush failure is a dice roll. Hollow Township's rush cost is a person's arc.

**The optimization game is the moral surface (Gap 11 — Option B)**: The full depth of this system — 5 domains, 3 depths, 3 settling paths, bonds, output modifiers — is an optimization game. A player who routes arrivals efficiently (Path C, matched domain, separated to prevent bond vulnerability) is demonstrably treating people as resources. The game does not label this. But the arc states make the pattern visible to anyone watching. The Theorist archetype observing a manager who has processed four arrivals through Path C has a specific behavioral state line that reflects what they have watched. The optimization is not hidden or punished — it is surfaced as a mirror. What using these numbers efficiently says about the manager is Pillar 3 material. The numbers are load-bearing. The moral weight is in seeing them clearly.

---

## Pillar Compliance

| Pillar | Risk | Resolution |
|--------|------|-----------|
| Pillar 1 — Earned Dread | Free productivity removes moral weight | Every productivity gain has a moral cost in how the arrival is treated. No gain without choice. |
| Pillar 2 — The Watched Feeling | Arrivals feel like resource tokens, not people | Arrivals have former-life specificity, behavioral state lines, voice registers. The world responds to how the player treats them — existing NPCs observe and change. |
| Pillar 3 — Moral Weight at Every Turn | Skill matching creates "optimal assignment" that removes moral tension | Optimal assignment exists but always conflicts with something: speed vs. integration, productivity vs. arc health, efficiency vs. decency. No assignment is free. |
| Pillar 4 — Day/Night Structure | Productivity gains make night feel less threatening | Night threat scales with DEBT and season. More workers = more buildings = more Walker targets. Productivity and threat grow together. |
| Pillar 5 — Genre Whitespace | Fallout Shelter mechanics soften horror register | No stat numbers, no resource bars, no happiness percentages. The productivity layer is visible only through NPC behavior and building output — not through a management UI. |

---

## Part 1 — Skill Inheritance from Former Life

Every arrival carries competencies from their former life. These map directly to township functions. The mapping is not labeled as a stat — it appears as a behavioral observation in the assignment context panel.

### The Five Skill Domains

| Domain | Former-life examples | Township function | Building types enabled |
|--------|---------------------|-----------------|----------------------|
| **Construction** | Carpenter, engineer, contractor, architect | Building speed, structural integrity, repair rate | All build sites, incomplete structure, perimeter |
| **Medicine** | Nurse, surgeon, paramedic, pharmacist | NPC injury recovery speed, trauma treatment, arc stabilization | Medical post, Thomas's clinic |
| **Logistics** | Accountant, supply chain, warehouse, clerk | Resource processing rate, ledger accuracy, Watcher spawn reduction | Mill Quarter, stockpile management |
| **Observation** | Security guard, surveyor, naturalist, trucker | Watchtower effectiveness, creature detection lead time, treeline monitoring | Eastern Ridge, all watchtower posts |
| **Social** | Teacher, counselor, organizer, negotiator | Faction trust accumulation rate, NPC morale recovery, new arrival settling speed | Settlement Common, faction meeting spaces |

### Skill Depth — Three Levels

Each arrival has one primary domain at one of three depth levels. Depth is not shown as a number — it surfaces as the specificity of the behavioral state line.

```
Surface (most common):     General capability. Useful. No special output.
                           State line: "Worked construction most of her life."

Practiced (less common):   Domain-specific experience. +30% output in matched role.
                           State line: "Twelve years framing residential builds. Knows
                                        which joints hold in cold weather."

Deep (rare, seasonal):     Specialized expertise. +60% output in matched role.
                           Also unlocks one building or capability not otherwise available.
                           State line: "Structural engineer. She can read a foundation
                                        the way Thomas reads a patient."
```

Deep-level arrivals are more frequent in Deep Winter (the trap pulls through people mid-urgency) and rare in Late Summer. A Deep Construction arrival in Chapter 1 can unlock the ability to reinforce Zone 4's foundation — which changes what Peder finds when he digs. This is not a free upgrade. What Peder finds is load-bearing for the horror.

### Assignment UI — No Numbers

The assignment context panel shows:
- Arrival name
- One behavioral observation (the skill signal — written in TONE.md register)
- Available roles (text list, same as all NPC assignment)
- No percentages, no stat bars, no "best match" indicator

The player reads the behavioral observation and makes an inference. A player who assigns the structural engineer to a watchtower post is not wrong — they made a choice with a real cost and a real gain. The game does not tell them they chose suboptimally.

---

## Part 2 — The Settling Curve

Arrivals do not produce at full capacity immediately. They have a settling curve: a period where their output is reduced and their arc is forming. How the player handles this period determines the arrival's long-term arc and their relationship to the township.

### The Three Settling Paths

**Path A — Full Integration (2 in-game days)**
Player assigns: housing near a compatible NPC, matched role, one conversation that does not ask them to set their grief aside.

Result: Arrival reaches full output at Day 3 (or Day 2 of next chapter). Arc is stable. They have begun to form a relationship with the NPC they were housed near. That NPC's behavioral state line reflects it.

Output during settling: 50% → 75% → 100% across 2 days.
Arc state at full output: Settling → Present → Contributing.

**Path B — Accelerated Integration (1 in-game day)**
Player assigns matched role immediately but skips the housing choice (assigns to any available bunk) and does not initiate first conversation.

Result: Arrival reaches 80% output at Day 2 and plateaus there. They never fully settle. Arc state: Functional but distant. They do not form bonds with other NPCs. If injured during night, recovery is slower (no relationships to stabilize arc).

Output during settling: 60% → 80% → 80% (plateau).
Arc state at plateau: Working but not present. Goes through the motions.

**Path C — Immediate Deployment (rushed)**
Player assigns to urgent role before arrival has had time to process. This is the Fallout Shelter "rush" — but the failure mode is not a fire. It is the person.

Result: Full output immediately. Arc state begins damaged: Functional/Fragile.
Behavioral state line on Day 1 of arrival (Path C): "Working. Hasn't stopped since she arrived."
Behavioral state line on Day 1 of arrival (Path A, 50% output): "Getting her bearings. Working carefully."
Both NPCs are visibly working. The output difference is not observable in the moment — it surfaces as zone-level productivity changes over subsequent days, exactly when micro consequences are designed to surface. The player cannot identify Path C as "the rush option" by observing immediate output. They observe it by what the person becomes. Fragile NPCs are the first to break under night pressure. A Fragile NPC assigned to a night watch post has a higher arc-destabilization rate. If they break, their productivity drops permanently and their arc becomes: Broken.

A Broken arrival has reduced output (40% of skill level), does not form bonds, and destabilizes nearby NPCs through behavioral contagion — the Theorist archetype especially; a Broken Theorist spreads despair instead of hope.

Output during settling: 100% immediately.
Arc state trajectory: Functional/Fragile → either stabilizes with delayed integration investment OR breaks under first pressure.

**The moral surface**: Path C produces the most output the fastest. It is also the choice that treats a frightened person as a machine. The game does not label it. The player chooses it or they don't. The arc trajectory is the consequence.

**The compounding enforcement mechanism**: A player who routes all four arrivals through Path C will have four Fragile or Broken NPCs by Day 5. Broken NPCs destabilize adjacent NPCs through behavioral contagion. At three or more Broken arrivals, the contagion reaches the original six NPCs — arc-stable NPCs in adjacent zones move from `present` toward `fragile` under the Broken Theorist's influence. This is not a punishment system. It is the design working: a township full of people treated as machines behaves like a machine approaching failure. Night 5 finds the player with higher output capacity (they maximized productivity) and a structurally destabilized workforce. The Surveyor measures what was built. A high-output, high-Broken-NPC township reads differently to the consequence engine than a lower-output, arc-stable one. The macro choice on Day 5 lands harder — and costs more — when it fires into a workforce that the player has already depleted of arc resilience. The mirror is not optional; it is load-bearing for the night that follows it.

---

## Part 3 — Productivity Outputs by Domain

Each domain produces a specific township output. Outputs are not shown as numbers — they manifest as visible changes in building state, resource availability, and NPC behavioral state lines.

### Construction Domain
- **Matched output**: Incomplete structure build rate increases. If Peder's crew has a Construction arrival at Practiced+, the fourth wall is complete one day earlier. This changes the Night 2 Walker spawn condition (the wall is finished before they arrive — the trigger fires differently).
- **Deep unlock**: Reinforced foundation — available only with a Deep Construction arrival. Peder excavates further. What he finds is a design decision for the horror layer.
- **Unmatched output**: General labor. Useful for any Zone but no domain bonus.

### Medicine Domain
- **Matched output**: Injured NPCs recover arc stability faster. Thomas can treat two NPCs per day instead of one with a Medicine arrival assisting. A Practiced Medicine arrival can prevent arc-break on a night-watch NPC who took damage (stabilizes at Afraid rather than Breaking).
- **Deep unlock**: One additional injured NPC can survive a night watch post (the Deep Medicine arrival triages in the field). Changes night roster calculus — a previously unusable injured NPC becomes assignable.
- **Unmatched output**: None specific. Medicine skills do not transfer to construction or logistics.

### Logistics Domain
- **Matched output**: Ledger accuracy improves. One Logistics arrival at matched role reduces Watcher depredation noticeably by Day 2 — a stockpile that was depleting stabilizes. Two Logistics arrivals at full output eliminate one Watcher's specific discrepancy entirely: that stockpile stops depleting. The effect is qualitative and observable (a stockpile that was declining is no longer declining), not a displayed number. The player discovers "Logistics arrivals help with Watchers" through observation, not calculation.
- **Practiced+**: Can identify the specific discrepancy that spawned each Watcher. Presents it to the player as a named, actionable choice rather than a general pattern. More precise than Maren's reporting (she knows the ledger; a Logistics arrival knows the supply chain).
- **Deep unlock**: Full ledger audit — surfaces all hidden discrepancies at once. This is both a gift and a horror: the player now knows everything that is wrong. The Compact responds within one day.

### Observation Domain
- **Matched output**: Watchtower lead time increases. An Observation arrival on the Eastern Ridge gives 2 in-game hours advance warning before a Walker reaches the settlement (vs. 0 warning without). Player has time to shift an NPC assignment — not full reassignment, but a single post swap within the dusk window.
- **Practiced+**: Can identify which Zone the Walker will enter before it arrives. Changes night roster from reactive to anticipatory.
- **Deep unlock**: Treeline mapping — produces a partial record of Zone 5 that reveals one specific Walker origin point. Changes one Walker's spawn condition for the following night. Not an elimination — a redirection.

### Social Domain
- **Matched output**: Faction trust accumulates faster. One Social arrival in the Settlement Common reduces the cooldown on faction negotiation by one day. A player who burned Compact trust by disclosing a discrepancy can rebuild it one day sooner.
- **Practiced+**: New arrivals settle faster when a Social NPC is present — settling curve Path A completes in 1 day instead of 2.
- **Deep unlock**: One faction relationship can be reset to neutral (not positive — neutral). The Social arrival brokers something. This is a one-time use per chapter.

---

## Part 4 — Cooperative Bonding (Room Synergy Adapted)

Fallout Shelter's room adjacency bonus — merging same-type rooms for efficiency boost — is adapted here as cooperative bonding between NPCs. When two NPCs work the same zone for 2+ consecutive days, they form a bond. Bonds have mechanical and narrative effects.

### Bond Formation

```
Condition: Two named NPCs (arrival or original six) assigned to the same zone
           for 2 consecutive day phases.
Result:    Bond formed. Visible in both NPCs' behavioral state lines.
           Neither NPC's line explicitly says "they are bonded."
           Both lines change to reflect the other's presence.

Ruth + Construction arrival in Zone 4 for 2 days:
  Ruth's state line (day 3): "Working faster than she has in weeks. Doesn't say why."
  Arrival's state line (day 3): "Follows Ruth's lead without being asked to."
```

### Bond Mechanical Effects

**Productivity**: Bonded pair in matched roles produces +20% combined output. Not labeled. The player observes output increasing and may or may not connect it to the bond.

**Night survival**: If both members of a bond are assigned to night watch posts, each has a reduced arc-destabilization rate (they stabilize each other). If one is threatened, the other's behavioral state line reflects it the following morning.

**Bond cost**: A bond makes both NPCs vulnerable to each other's loss. If a bonded NPC dies or breaks, the surviving NPC's arc takes a destabilization hit proportional to the bond depth. The game does not warn the player that bonds create vulnerability. They observe it when it happens.

**Bond depth**: Bonds deepen with each additional consecutive day of shared work. Maximum depth at 4 days (Chapter 1 has 3 days — Deep bonds form in Chapter 2+). Deeper bonds have stronger productivity bonuses and stronger destabilization costs.

### Bond and Moral Weight

The player who notices bonds forming and deliberately separates the two NPCs (to prevent vulnerability) is making a moral choice the game does not label. So is the player who keeps them together knowing one of them is going on a dangerous night watch. Both choices have costs. Neither is labeled as moral.

### Bond Depth and Gossip Threshold

Bond depth (0–4, deepening with each additional consecutive shared-zone day) directly modulates gossip transmission threshold in the Gossip Engine (see `ARCHITECTURE.md` — Gossip Engine and `WORLD_BACKSTORY.md` Section 7). At bond depth 0, transmission probability equals the NPC's base disposition threshold. At bond depth 2+, threshold is halved for bond-exclusive NPCs (Elias) and reduced by 30% for all others. At bond depth 4, bond-exclusive NPCs transmit everything they hold without any roll. The practical consequence: the player who builds deep bonds creates a densely connected information network. The player who prevents bonds creates isolated observers who each hold partial information that never integrates. Both strategies have compounding consequences by Day 4 when the gossip network's accumulated state shapes Night 4 pre-computation.

---

## Part 5 — Season-Modulated Arrival Quality

The silver lining scales with the threat. Deep Winter is harder — but the trap pulls through more capable people faster.

| Season | Arrival frequency | Skill depth distribution | Special condition |
|--------|-----------------|------------------------|-------------------|
| Late Summer | 1 per 6 days | 70% Surface, 28% Practiced, 2% Deep | Arrivals have full settling time available |
| Turning | 1 per 4 days | 60% Surface, 35% Practiced, 5% Deep | One Practiced arrival guaranteed before first winter night |
| Deep Winter | 1 per 2 days | 45% Surface, 40% Practiced, 15% Deep | Deep arrivals possible; arrive mid-urgency (Path C pressure) |
| Thaw | 1 per 8 days | 55% Surface, 40% Practiced, 5% Deep | Arrivals are calmer — settling curve shortened by 1 phase |

**Chapter 1 guaranteed arrival sequence** (independent of season, 5-day arc):
- Day 1: No arrival — player learns the six original NPCs before inflow begins
- Day 2: One Surface arrival (any domain) — establishes the mechanic, low stakes
- Day 3: One Practiced arrival in the domain the player has neglected most — the world fills the gap the player left
- Day 4: One Practiced arrival whose domain matches Night 4's most urgent defense gap — computed from threat state, not domain absence. A player who deliberately neglected a domain will have compounded DEBT in the process, making Night 4 more dangerous regardless. The optimization is self-taxing.
- Day 5: One arrival at highest available skill depth (Deep possible in Turning/Deep Winter), domain matched to Night 5's most urgent need — arrives at dusk minus 3 minutes. Path A is impossible. The game's last day-phase decision is also its most human.

The Day 4 arrival is computed from threat state, not domain absence — "urgent" means the gap that most directly threatens the player's Night 4 survival, not simply the domain with fewest workers. This closes the replayability exploit: a player who deliberately neglects a domain to farm a high-quality Day 4 arrival will have generated DEBT doing it. The compensation is self-taxing.

The Day 5 arrival is the clearest silver lining: the worst night brings the most capable help. But they arrive with 3 minutes of dusk window remaining. Path C (immediate deployment, arc damage) is the only efficient option. The game does not label this. The player makes the call.

---

## Part 6 — The Productivity Floor — THE DEBT's Logic, Not a Mercy System

These floors are not the game protecting the player. They are THE DEBT protecting the conditions for a longer accounting. The trap needs the township marginal, not dead. Marginal is more useful to it. When a floor triggers, THE DEBT made a choice — and the player observes the consequence of that choice as a horror event, not as a UI message.

**Population floor**: Minimum 4 named NPCs must remain capable at any chapter end. If losses would drop below 4, the Surveyor's Shadow on Night 4 (pre-reckoning) behaves differently — it witnesses longer than usual. It does not withdraw immediately. NPCs who see it on Night 4 have a different arc update than those who see the standard Night 4 appearance. The accounting is being measured more carefully, not deferred. Chapter 2 opens with the deficit visible.

**Resource floor**: Stockpiles cannot drop below 20% of starting level through Watcher depredation alone. At 20%, Watcher behavior changes — they redistribute rather than continue depleting. The player who notices this observes: Watchers stopped taking from the grain store. They moved to the mill. This is THE DEBT preserving the conditions for continued extraction, not mercy. A Logistics arrival who reaches this state has a specific behavioral observation: "She's been watching the Watchers. She's starting to understand their pattern."

**Skill floor**: The player always has enough domain coverage to staff one watchtower and one logistics role simultaneously, even after losses. Arrivals in Deep Winter fill these gaps automatically through the Chapter 1 guaranteed sequence (Days 2 and 4 arrivals in neglected domains). The trap fills the gaps it needs filled to keep the game going.

**These floors are not communicated to the player.** They experience them as: the worst night somehow didn't take everything. They do not know why. The game does not explain why. What they observe is specific, traceable behavior — not a mercy, but a horror with its own logic.

---

## Part 7 — The Compulsion Loop, Extended

With inflow as a productive mechanic, the three-beat loop now has a fourth beat that operates across days:

```
RELIEF  →  UNEASE  →  COMPULSION  →  INVESTMENT
(Day)      (Night)     (Dawn)         (Arrival)

Build.     What you    Count what     Someone new.
Manage.    built       it cost.       A skill you
Negotiate. watches                    didn't have.
           you back.                  A person who
                                      doesn't know
                                      yet what
                                      this place is.
```

The Investment beat does not resolve the compulsion. It compounds it: the player now has more capacity, which means more choices, which means more moral weight, which means more to lose at the next night. Every arrival is the game saying "you could build more." The player hears: "you could lose more."

That is the silver lining. It was never going to be simple.

---

## Backend Integration

Arrival events, skill domains, arc states, and bond data are tracked in DynamoDB and drive NPC Behavior Agent outputs.

```
Table: player_arrivals
  PK:  player_id
  SK:  arrival_id (ulid)
  Attributes:
    arrival_day:     number
    archetype:       string  ("practical" | "dependent" | "theorist")
    skill_domain:    string  ("construction" | "medicine" | "logistics" | "observation" | "social")
    skill_depth:     string  ("surface" | "practiced" | "deep")
    settling_path:   string  ("integration" | "accelerated" | "rushed")
    arc_state:       string  ("settling" | "present" | "contributing" | "functional" | "fragile" | "broken")
    bond_npc_ids:    list    (NPCs bonded with)
    bond_depth:      number  (0–4)
    output_modifier: float   (current productivity multiplier: 0.4–1.6)
    chapter:         number

GSI: skill_domain → arrival_id  (query all active arrivals by domain for productivity computation)
```

NPC Behavior Agent receives arrival arc states in the USER block of each call. Bonded NPCs have their bond partner's arc state included alongside their own. Bond vulnerability is computed server-side and included in horror event generation — a Walker targeting a bonded pair's zone triggers a specific horror variant.

---

## Required Updates to Existing Documents

| Document | Addition needed |
|----------|----------------|
| `WORLD_BACKSTORY.md` | Replace Section 4 inflow mechanic with reference to this document. WORLD_BACKSTORY.md describes the narrative layer; this document owns the mechanical layer. |
| `INTERACTION_MODEL.md` | NPC assignment context panel needs skill signal line added. First conversation option added as third assignment decision (housing, role, conversation). |
| `WORLD_STATE.md` | Five skill domains added to the operational reference — NPC Behavior Agent needs them for generating behavioral state lines that reflect skill domain. |
| `ARCHITECTURE.md` | `player_arrivals` table added to DynamoDB schema. GSI for skill_domain query. Bond state included in NPC Behavior Agent USER block. |
| `TIME_SYSTEM.md` | Season-modulated arrival frequency table replaces the simpler table in NPCInflowSystem.gd. Chapter 1 guaranteed arrival sequence added to NPCInflowSystem logic. |
