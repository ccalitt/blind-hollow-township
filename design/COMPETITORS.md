# Competitive Landscape — Hollow Township

> Research date: April 2026. Used to validate genre whitespace claim in `PILLARS.md` Pillar 5.

---

## Genre Axis Scoring

| Game | Horror | Simulation | Drama | Direct Threat |
|------|--------|------------|-------|---------------|
| Frostpunk 1 | Weak | Strong | Moderate | Partial — sim/drama overlap |
| Frostpunk 2 | Weak | Moderate | Strong | Partial — lost sim depth |
| This War of Mine | Moderate | Strong | Moderate | Partial — no horror depth |
| Disco Elysium | Weak | Moderate | Strong | Partial — false player agency |
| Darkest Dungeon 1 | Strong | Moderate | Moderate | Partial — no management scale |
| Darkest Dungeon 2 | Strong | Weak | Weak | Not a threat — player backlash |
| Cult of the Lamb | Moderate | Strong | Moderate | Partial — horror aestheticized |
| RimWorld | Weak | Very Strong | Moderate | Not a threat — no horror |
| Dwarf Fortress | Moderate | Very Strong | Moderate | Not a threat — accessibility barrier |
| Don't Starve Together | Moderate | Moderate | Weak | Not a threat — no drama depth |
| **Hollow Township target** | **Strong** | **Strong** | **Strong** | — |

**Finding**: No competitor holds Strong across all three axes. The intersection is unoccupied.

---

## Competitor Deep Dives

### Frostpunk 1 & 2

**What works**: Impossible moral choices under resource scarcity. Child labor, executions, amputation for coal. Collective desperation modeled through stress mechanics.

**What it doesn't do**:
- No supernatural horror — dread is atmospheric, not mechanical
- Narrative is linear event-driven, not emergent from player choices
- Citizens are statistics, not named people with arcs
- Night is not mechanically distinct from day

**Steam data**: FP1 ~2–5M owners, 93% positive (133K reviews). FP2 ~500K–1M owners, 75% positive — mixed reception after it shifted toward political simulation and *lost* the city-building intensity players loved.

**What 3-star reviews reveal**: "I wish I could zoom in and see citizens' faces, not meters." / "Politics overshadows survival urgency." / "FP2 feels hollow without the tower-defense panic of FP1."

**Implication for Hollow Township**: The audience explicitly wants named citizens and closer consequence. FP2's political turn created a vacuum for a game that does *both* politics *and* survival horror with personal stakes.

---

### This War of Mine

**What works**: Moral weight embedded in mundane scarcity. Steal from the elderly to survive? Give medicine to strangers? Decisions have emotional weight without being labeled "good/evil."

**What it doesn't do**:
- No supernatural elements — horror is human, not dread
- Scavenging loop becomes repetitive after 10 hours
- No day/night mechanical asymmetry
- Narrative is authored encounters, not emergent from player decisions
- No township scale — just a single shelter

**Steam data**: ~1–2M owners, 89% positive (95K reviews). Peak concurrent: 6,139 (2024), now down 89% — audience moved on, sequel never came.

**What 3-star reviews reveal**: "Gets repetitive." / "More ways to interact with survivors." / "Sequel when?"

**Implication for Hollow Township**: This game proved the market exists for moral-weight-embedded-in-logistics. The audience wants *more* — more mechanical depth, more emergent narrative, more consequence persistence. We are building the game they wanted TWOM to become.

---

### Disco Elysium

**What works**: 240K+ words of dialogue. Skills as personality expression. Political depth. The game treats the player as an adult.

**What it doesn't do**:
- No real player agency — one ending regardless of choices
- No survival or management mechanics
- No spatial consequence — choices don't reshape the world
- No horror in any mechanical sense
- Stat-gating removes moral weight: the game decides whether your chosen dialogue succeeds

**Steam data**: 55K+ reviews, 92% positive. But player discourse is divided — loved for writing, resented for the gap between promised and actual agency.

**What 3-star reviews reveal**: "No matter what I chose, I was dragged to the same ending." / "Choice should matter to outcomes, not just pacing." / "Stats determine dialogue access — that's not freedom."

**Implication for Hollow Township**: The audience craves real agency that changes outcomes. They know they've been given the illusion of choice before. If we deliver actual consequence — night shaped by day choices, NPCs who remember, endings that diverge — this is the direct contrast to Disco Elysium's broken promise.

---

### Darkest Dungeon 1 & 2

**What works**: The Affliction System. At peak Stress, heroes either transcend their fear or break — becoming paranoid, abusive, cowardly in real-time. A broken hero can heart-attack mid-dungeon. This is *earned* psychological horror.

**What it doesn't do**:
- No township or macro-level management (DD1 has estate, but it's upgrade-tree, not moral)
- Roguelike structure (especially DD2) prioritizes replayability over narrative stakes
- Named characters exist but have no persistent arcs
- Player choice doesn't shape the horror — it's procedural, not consequential

**Steam data**: DD1 ~500K–1M owners, 91% positive (55K reviews). DD2 76% positive — significant backlash over roguelite direction and RNG dependency.

**What 3-star reviews reveal (DD2)**: "Too RNG, not enough player control." / "Bring back DD1's permanent base management." / "Runs are too long for rewards that feel random." / "Tutorial is 10 hours."

**Implication for Hollow Township**: DD2's failure is instructive. Players rejected randomness when they wanted consequence. They rejected runs when they wanted permanence. They want a world that *remembers*. The Affliction System mechanic (stress leading to breakdown) is the closest existing mechanical model to what we want to do with NPCs under pressure — but we need to extend it to have memory across sessions.

---

### Cult of the Lamb

**What works**: Management simulation loop is genuinely compelling. Assign roles, manage needs, perform rituals. Dark themes handled with confidence.

**What it doesn't do**:
- Horror is aestheticized — the "cute-horror" visual language softens dread into coziness
- Cultists lack individual personalities or persistent arcs
- No day/night mechanical asymmetry
- Narrative is authored (linear), not emergent
- Roguelite action sequences are the weaker half of the game

**Steam data**: 96% positive (118K reviews). ~500K–1M owners. Described in reviews as "weirdly cozy for a cult game."

**What 3-star reviews reveal**: "Cultists have no personality — they're interchangeable." / "Management loop is addictive but shallow." / "Bugs frustrate the loop at critical moments."

**Implication for Hollow Township**: The audience will accept dark management themes at scale. But they want the people to *matter* individually. "Interchangeable" is the exact failure we design against with our named NPC requirement.

---

### RimWorld (Simulation Ceiling Reference)

**Genre axes**: Horror: Weak. Simulation: Very Strong. Drama: Moderate.

The simulation ceiling reference. Pawns have needs, skills, relationships, mental health. Breaking any need triggers mental breaks. Storytelling engine creates emergent narrative through failure.

**What it doesn't do**: No curated narrative arc, no authored horror, no day/night asymmetry, no supernatural consequence.

**Implication**: Sets the bar for simulation depth. We do not need to exceed RimWorld's simulation complexity — we need simulation deep enough to create genuine moral weight, not to be the deepest simulation ever made.

---

### Dwarf Fortress (Simulation Depth Reference)

**Genre axes**: Horror: Moderate (eldritch corruption exists). Simulation: Very Strong. Drama: Moderate.

The deepest simulation in existence. Procedural world generation. Dwarves with personalities, fears, relationships. Fortress spirals into madness through cumulative choice.

**Unmet need**: Accessibility. The UI is famously opaque. Players want the depth in a curated form.

**Implication**: Proof that horror + deep simulation can coexist. Also proof that accessibility is not a nice-to-have — it determines whether a game reaches its audience at all.

---

## Recent Releases (2022–2026) — Direct Competitor Scan

**Finding**: No game released 2022–2026 combines township management + horror + moral consequence simulation. The intersection remains uncontested.

Games checked: My Townies, Isolation Simulator, Moral Dilemma: The Interview, Children of the Sun, Signalis, Dredge, Pacific Drive, The Outlast Trials, Homeworld 3. None occupy all three axes.

---

## Genre Whitespace Summary

No game on Steam delivers this combination: **logistics-based moral weight** (RimWorld's simulation depth) + **psychological dread mechanics** (Darkest Dungeon's Affliction-style consequence) + **curated narrative arc with real player agency** (what Disco Elysium promised but didn't deliver) + **day/night mechanical asymmetry** (building/politics vs. horror/corruption) at **township scale** where political decisions cast shadows into supernatural night.

Frostpunk players want named citizens and personal stakes. This War of Mine players want sequel-level depth. Disco Elysium players want choices that actually change outcomes. Darkest Dungeon 2 players rejected randomness and want permanence and memory. Cult of the Lamb players want their people to matter individually.

Hollow Township is the game all five audiences describe in their 3-star reviews. The whitespace is not theoretical — it is visible in what players explicitly say they wanted and did not get.
