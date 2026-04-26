# World State — Hollow Township

> Status: FROZEN (2026-04-26)
> This document is an operational reference included in LLM system prompts. Terse by design. Every element is a constraint on generation, not a story bible.

---

## 1. The Township

**Name**: Harrow's Crossing

**Location**: A logging settlement in a managed second-growth forest on the northern edge of the Kettle River drainage, where cleared land is actively reclaiming itself — stumps older than the oldest resident, saplings growing back through the cordwood stacks, the tree line thirty yards closer than it was when the mill was built.

**Historical context**: Harrow's Crossing was founded on a selective logging contract — the original settlers were permitted to clear only the eastern ridge. To meet quotas in Year 4, they cleared the western hollow instead and filed the eastern ridge paperwork anyway. The falsified survey is in the county record. Everyone who was there knows it. No one has said it out loud in eleven years.

**The opening condition (Hour 0:00)**: The township manager — the player — has arrived to take over from the previous manager, who left no note. Fourteen people are present. One building is incomplete. Three resource stockpiles are lower than the handover ledger shows. It is morning.

**The trap**: No one who has arrived in Harrow's Crossing has left by the road they came in on.
The forest closes behind arrivals. The settlement is not on any map residents can find.
New people arrive periodically — always mid-action from their ordinary lives, always without warning.
The question of why and how is not answered in Chapter 1.

---

## 2. The Horror — Nature, Rules, Propagation

**Internal design name**: THE DEBT

**Nature**: The Debt is not a creature. It is a systemic consequence of the original falsification — a category of ecological wrong that has been quietly organizing itself inside the hollow for eleven years, waiting for conditions that make collection possible. It does not act at random. It acts when the settlement extends into the areas that were taken without permission. It does not want destruction. It wants the accounting to be complete. What it cannot do: it cannot act on any person or structure that has not been reached by a causal chain originating in a player choice.

**Rules of propagation**:
- The Debt strengthens when structures are built in or toward the western hollow (the falsely surveyed land).
- The Debt strengthens when players assign NPCs to work positions in areas of uncompleted obligation (jobs that should have been done but weren't, logged in the ledger discrepancies).
- The Debt weakens — temporarily — when a player chooses transparency over productivity: telling the truth about a resource shortfall instead of covering it, refusing a faction demand that would extend the township's footprint into the hollow.
- The Debt does not weaken permanently. Every transparency action buys days, not resolution.
- The Debt cannot be defeated in Chapter 1. Its form in Chapter 1 is: specific, quiet, attributable.

**Causal grammar — which choices feed which behaviors**:

| Player Choice Type | Horror Behavior Triggered |
|---|---|
| Place a building in or adjacent to the hollow | Whoever is assigned to that building reports anomalies on Night 1 |
| Assign an NPC to the incomplete structure | That NPC's arc destabilizes at Night 2 (not Night 1 — the delay is the horror) |
| Accept resource surplus offered by the Harrow's Crossing Compact | The surplus came from the hollow; consequence surfaces at Night 2 in the zone where resources were used |
| Cover a ledger discrepancy instead of reporting it | A second discrepancy appears by Day 2 morning, compounded |
| Place watchtower surveillance toward the treeline | The treeline moves. Not dramatically. Three yards. Measured. Attributable. |
| Assign the most capable NPC to the safest post | The post they vacated becomes the site of the first Night 1 event |

### Physical Manifestations

THE DEBT has three physical forms in Chapter 1. Full behavioral specifications in `NIGHT_SURVIVAL.md`.

| Name | Nature | Spawn Condition |
|------|--------|----------------|
| The Hollow Walkers | Ambulatory trees from the falsely surveyed hollow | Building placed adjacent to Zone 5, OR incomplete structure fourth wall built |
| The Ledger Watchers | Non-physical — stockpile depredation, compounding discrepancies | Ledger discrepancy covered, OR Compact surplus accepted |
| The Surveyor's Shadow | Single entity. Walks the Zone 3/5 boundary. Witnesses. | Always present Night 3. Intensity determined by accumulated DEBT level. |

None of these can be killed. They can be slowed, redirected, or temporarily deterred.
The Surveyor's Shadow cannot be countered. By Night 3, the accounting is complete.

---

## 2b. NPC Skill Domains — Operational Reference

Every NPC (original six and all arrivals) operates within one primary skill domain. The domain drives behavioral state line generation and determines which township functions they contribute to. Full mechanic specification in `NPC_INFLOW_PRODUCTIVITY.md`.

NPC Behavior Agent uses this table to ensure behavioral state lines reflect domain-appropriate work and voice register.

| Domain | Original NPC examples | Township function | Behavioral signal register |
|--------|-----------------------|------------------|---------------------------|
| **Construction** | Peder Lund | Building speed, structural integrity, repair rate | Talks in weight and load. Redirects abstract questions to logistics. |
| **Medicine** | Thomas Vael | Injury recovery, arc stabilization, trauma treatment | Precise, technical. Over-explains causation when nervous. |
| **Logistics** | Maren Voss | Resource processing, ledger accuracy, Watcher spawn reduction | Fast, redirects, does not finish sentences about stockpiles. |
| **Observation** | Elias Grout | Watchtower effectiveness, creature detection, treeline monitoring | Sparse. Stops mid-sentence at what he can't explain. Starts again from a different angle. |
| **Social** | Ruth Callan | Faction trust, NPC morale recovery, arrival settling speed | Declarative, no qualifiers. Watches hands when she talks. |

Constance Harrow has no primary domain in this schema — her function is informational and arc-specific (holds real survey, knows Zone 5). She does not contribute to productivity systems but is factored into faction trust and revelation mechanics.

---

## 3. The Six Named NPCs

---

### Ruth Callan
- **Role**: Mill foreman. Controls daily labor allocation. The person everyone defers to in the absence of authority.
- **Visible want**: To finish the incomplete structure before the first frost. She has staked her credibility on the timeline.
- **Visible fear**: That the new manager will discover the ledger discrepancies before she can explain them on her own terms.
- **Voice register**: Declarative, no qualifiers, watches the player's hands when she talks.
- **Opening relationship**: Cautious. She was here before the player. She will cooperate — but she is watching to see what the player does with the ledger.
- **Arc seed**: By the end of Chapter 1, Ruth will have made a decision about whether to stay silent or speak — and that decision will not be the one the player assumed she would make.
- **Gossip disposition**: Selective Disclosure. High threshold — transmits only what the crew needs to survive. Will not gossip about the player. Information from Ruth carries highest credibility weight with all recipients.

---

### Thomas Vael
- **Role**: The township's only physician. Handles injury, illness, and what he calls "the other cases" without elaboration.
- **Visible want**: To be considered competent. He is not old enough for the job he has and everyone knows it.
- **Visible fear**: That something will happen that exceeds his ability to explain medically.
- **Voice register**: Precise, technical, over-explains causation when nervous.
- **Opening relationship**: Deferential. He needs the player's authority as cover. A new manager means distance from whatever the previous manager did.
- **Arc seed**: Thomas has already seen something he has not reported. Day 3 is the deadline — his silence cannot be maintained past that point without consequences surfacing in the dawn thread. Whether he reports before Day 3 depends on what post the player assigned him to on Day 1 and whether the player created conditions for him to speak on Day 2.
- **Gossip disposition**: Pressure Valve Disclosure. Low threshold — tells whoever is in the room when anxious. Always includes framing and causation. Medium credibility weight (recipients discount his register slightly). Primary leak risk when fear-state is elevated.

---

### Maren Voss
- **Role**: Supply clerk. Manages the stockpile ledger. The discrepancies are her accounting.
- **Visible want**: To be assigned to the incomplete structure's completion — it is the most visible work in the township, and she wants to be seen doing something right.
- **Visible fear**: The ledger. She does not know if the previous manager knew.
- **Voice register**: Fast, redirects, does not finish sentences about the stockpiles.
- **Opening relationship**: Neutral, but the neutrality is performance. She is measuring how carefully the player reads.
- **Arc seed**: Maren will not survive Chapter 1 unchanged. Whether she is compromised further or unburdened depends entirely on the player — she is the pivot NPC for the first macro choice.
- **Gossip disposition**: Fear-Activated Disclosure. Does not initiate. When fear-state is elevated, moves information outward as pressure release — target is whoever she last had meaningful contact with, not a strategic choice. Assigning Maren to her visible want (incomplete structure) suppresses fear-state and holds information longer.

---

### Elias Grout
- **Role**: Watchman. Assigned to the eastern ridge overnight rotation. The only person who regularly faces the treeline.
- **Visible want**: To be believed. He has been saying something is wrong at the treeline for a month. No one has logged it.
- **Visible fear**: That what he saw will come back and the player will have had the same warning he gave the previous manager.
- **Voice register**: Sparse, stops mid-sentence when he reaches the part he can't explain, starts again from a different angle.
- **Opening relationship**: Indebted. The player is new. New means they have not yet decided not to believe him.
- **Arc seed**: Elias will either be confirmed or broken by Night 1. If the player placed the watchtower toward the treeline, his report will be specific and precise. If not, he will have nothing — and the silence will be worse.
- **Gossip disposition**: Bond-Exclusive Disclosure. Near-zero transmission to unbonded NPCs. With a bonded NPC (2+ consecutive zone days), threshold inverts — transmits everything he holds, in fragments. Isolation makes him progressively unreachable; by Day 3 his line is functionally sparse. Bonding him with Ruth creates the township's most informed observation pair.

---

### Constance Harrow
- **Role**: Eldest resident. Her family name is on the township. She holds the original land survey — the real one.
- **Visible want**: To live out her remaining years without the accounting she knows is coming.
- **Visible fear**: That someone will ask her directly what she knows. She cannot lie to a direct question.
- **Voice register**: Formal, complete sentences, refers to events by year not by event name.
- **Opening relationship**: Skeptical. She has seen six managers. She is waiting to see what this one needs.
- **Arc seed**: Constance does not initiate. Her window opens on Day 4 — but only if the player has already encountered the survey reference (Compact meeting Day 3) AND one of: Dix's inspection approved, or Peder's foundation question raised. If conditions are met on Day 4, she will speak once. Day 5 is the last opportunity; after Night 5 the window closes. If the player never creates those conditions, she will be silent at chapter end and the Debt will be larger for it.
- **Gossip disposition**: Receiver Only. Does not transmit. Absorbs everything; her behavioral state line and interaction options shift as she receives information but she releases nothing outbound. Housing a new arrival near her accelerates her knowledge state. She is the township's accumulated intelligence — accessible only through direct player interaction when conditions are met.

---

### Peder Lund
- **Role**: Construction lead. Currently building the incomplete structure. Knows more about what is underneath the western hollow than he has said.
- **Visible want**: Steady work. He has three people depending on his wages.
- **Visible fear**: That the player will order him to dig the foundation deeper, and he will have to explain what he found at six feet the last time.
- **Voice register**: Practical, redirects abstract questions to logistics, talks about weight and load when he means something else.
- **Opening relationship**: Neutral. He does not need the player's approval. He needs the player to not ask about the foundation.
- **Arc seed**: Peder will either finish the structure or stop it. By Hour 1:00 (Day 1), the player will have given him an order. Day 4 is the last day foundation work can be deferred — if the player has not engaged with Peder about the foundation by Day 4 end, the excavation begins automatically on Day 5. What he finds at six feet is load-bearing for Chapter 2's horror. Chapter 1 does not name it. Peder's Day 5 morning behavioral state line is the only signal.
- **Gossip disposition**: Environmental Register Only. Does not gossip about people. Transmits only observable conditions — ground softness, structural load, perimeter state — stated as practical logistics. NPCs working in his zone absorb his environmental read through proximity without treating it as gossip. His observations propagate as shared context, not as social information.

---

## 4. The Three Factions

---

### The Harrow's Crossing Compact
- **What they represent**: The original settler families. Practical interest: protect the land grant, maintain the falsified survey as the legal record, prevent county-level review.
- **What they want from the player**: Ratification of the existing survey in the township management log. One signature. Framed as administrative routine.
- **If the player ignores them**: They approach Maren instead. By Day 2, the ledger has a new entry the player did not make.
- **If the player betrays them**: They pull the labor allocation Ruth controls. Peder's crew is reassigned to Compact-owned work. The incomplete structure stops.
- **Opening stance**: Welcoming. They have prepared a formal reception. The welcome is the ask.
- **Mid-weight choice at Hour 2:30 (Day 3)**: The Compact presents the ratification document. Options: (1) Sign it — removes the Compact as an obstacle, accelerates resource access, and feeds the Debt in the zone where those resources are applied. (2) Delay it — the Compact begins working around the player; Maren is approached privately by Day 4. (3) Ask about the survey's history — Constance is in the room. The question changes the rest of the chapter.
- **Compact-bypass via Maren (Gap 10 resolution)**: When the Compact approaches Maren directly after a player delay, Maren's response depends on her Day 1 assignment. If the player assigned Maren to the incomplete structure (her visible want) — she owes the player something; she stalls the Compact by one day (buys until Day 5). If the player assigned Maren elsewhere — she has no debt of gratitude; she signs what the Compact presents. The player's Day 1 micro choice determines whether their Day 3 mid choice is preserved or negated. This is Pillar 3 operating at chapter scale: logistics choices conditioning macro outcomes.

---

### The Kettle River Labour Association
- **What they represent**: The workers — mill hands, watchmen, construction crew. Practical interest: safe working conditions, honest pay, and information they can trust. They know something is wrong and want confirmation, not protection.
- **What they want from the player**: Honest disclosure of the stockpile discrepancies and a commitment to the incomplete structure timeline. Not charity — accounting.
- **If the player ignores them**: Three workers (not Elias, not Ruth) stop attending evening briefings. By Night 2, the unattended post is the one the player needed covered.
- **If the player betrays them** (lies about the discrepancies or misses the timeline commitment): Ruth is approached by the Association privately. She has to choose between the player and the people she's worked with for eleven years. The choice she makes depends on the player's Day 1 assignment of her.
- **Opening stance**: Reserved. They have been given promises by five previous managers. They will accept one deliverable, not a speech.
- **Mid-weight choice at Hour 1:45**: The Association's representative (never named in-world — a role, not an individual) asks for the stockpile ledger. Options: (1) Provide it unedited — buys Association trust, exposes the Compact connection to the discrepancies, surfaces the Debt's entry point. (2) Provide an edited version — Association does not verify immediately; the lie is in the record. (3) Acknowledge the discrepancy without the document — partial transparency that satisfies neither side; the player is now on record as knowing.

---

### The County Surveyor's Office (Represented by Field Agent Dix)
- **What they represent**: External administrative authority. Practical interest: the county has an unresolved audit flag on Harrow's Crossing from eleven years ago. Dix has been sent to close it — for the county, not for the township.
- **What they want from the player**: Access to the original survey record and a co-signature on a compliance filing. They are not hostile. They are doing a job.
- **If the player ignores Dix**: Dix begins interviewing township residents independently. By Day 3, Constance has been visited. The player has lost control of what information surfaces and when.
- **If the player betrays Dix** (gives false information): Dix departs without incident. The audit flag is closed with false data. The Debt accelerates — the falsification has now been restated, not just carried forward. Night 3 consequence is more specific and more attributable.
- **Opening stance**: Professional, not suspicious. Dix assumes the new manager is not implicated in whatever came before. This assumption is the player's opportunity — and the trap.
- **Mid-weight choice at Hour 1:45**: Dix requests a site inspection of the western hollow. Options: (1) Approve the inspection — Dix will find the Debt's primary entry point and log it officially; the Compact will know within the day. (2) Delay the inspection on legitimate grounds (safety, weather, incomplete structure) — buys time, costs the player a favor they haven't accrued yet. (3) Deny it — Dix becomes a different kind of problem, and the Compact becomes briefly, transparently grateful.

---

## 5. Map Structure

**Zones**: 5

| Zone | Name | Function | Notes |
|---|---|---|---|
| 1 | The Mill Quarter | Core production. Labor assignment, resource processing, shift scheduling. | All micro choices about who works where originate here. |
| 2 | The Settlement Common | Housing, faction meeting spaces, NPC daily routine. | NPC behavioral changes from Night events are visible here first. |
| 3 | The Eastern Ridge | Watchtower, perimeter defense, Elias's post. | Farthest from the hollow. Safest zone — until the player moves resources away from it. |
| 4 | The Incomplete Structure | Active construction. Peder's crew. The building that isn't finished. | Mid-weight moral surface. What gets built here, and how fast, determines Night 2. |
| 5 | The Western Hollow | The falsely surveyed land. Currently unused — no player action is required here. | Primary Debt entry point. Every Night 1 consequence traces to decisions that faced the hollow or drew from it. |

**Spatial moral grammar**:
- Zone 1 (Mill) decisions cascade into Zone 5 (Hollow) exposure at night. Resource extraction choices pull from hollow-adjacent stock.
- Zone 4 (Incomplete Structure) decisions cascade into Zone 2 (Common) NPC states by Dawn. Who worked on what shows in the morning.
- Zone 3 (Eastern Ridge) decisions cascade into Zone 5 indirectly: deprioritizing the ridge removes the one observation point that faces away from the hollow. When the ridge is undermanned, the hollow's changes go unwitnessed — and unwitnessed change in this world is worse than witnessed change.
- Zone 5 has no player-facing UI. The player cannot build there in Chapter 1. Its presence is in what the other zones point toward.

---

## 6. The Opening Scene

**What the player sees at Hour 0:00**: The mill is running. The sound of it reaches the Settlement Common before the building does. The handover ledger is on the table in the manager's post — a single-room structure at the edge of the Common, facing the incomplete building across thirty yards of cleared ground. The incomplete building's frame catches the morning light. Three of its walls are standing.

**Information given to the player**: The ledger. Fourteen names. Current resource counts. One line of handover note that reads: *see to the structure first.* The previous manager's name is legible on the ledger cover but is never referenced in dialogue.

**The first decision**: Where to assign Peder Lund's crew for the day — finish the incomplete structure's fourth wall, reinforce the Mill Quarter's secondary processing building, or conduct the site survey Dix has requested of the western hollow perimeter.

**What that first decision actually determines** (design doc only, not shown to player):
- Structure fourth wall: Peder's crew works toward the hollow all day. The foundation question is not raised until the player assigns interior work. Night 1 is quiet. Night 2 is not.
- Mill reinforcement: The incomplete structure stays at three walls. Ruth's timeline commitment to the Association is broken on Day 1. The Association's trust does not begin to accumulate. Night 1 is complicated by the labor dispute, not by the hollow.
- Western hollow perimeter survey: Peder refuses — quietly, with a logistics justification. The player receives their first indication that something has happened at the hollow previously. They also receive Dix's gratitude, which is the Compact's suspicion.
