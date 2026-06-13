# World Backstory — Hollow Township

> Status: FROZEN (reviewed 2026-06-13). Foundational narrative layer.
> Reviewed against all five pillars (table below), NOT-THIS.md, WORLD_STATE.md, and ARCHITECTURE.md.
> Consistent: NPC tenures/dispositions match WORLD_STATE.md §3/§3b; the false-hope mechanic feeds
> the `anchor_erosion_delta` field defined in WORLD_STATE.md §7; gossip dispositions match
> WORLD_STATE.md and ARCHITECTURE.md. No contradictions found; no edits required beyond this header.

---

## Pillar Compliance

This is the narrative layer. It does not introduce mechanics of its own (those live in
`NPC_INFLOW_PRODUCTIVITY.md`, `WORLD_STATE.md`, and `ARCHITECTURE.md`); it supplies the register
and backstory those mechanics surface through. Major content tagged to the pillar(s) it serves:

- **The trap mythology + escape theories (§1, §5)** → Pillar 1 (Earned Dread) and Pillar 5
  (Genre Whitespace). The horror is ecological/bureaucratic with rules, not arbitrary; the Survey
  Theory is "directionally true" and traces to the falsification THE DEBT collects on. NOT-THIS
  compliance: the origin is deliberately unanswered in Chapter 1 (not an open-world reveal), keeping
  the chapter a contained moral argument.
- **NPC arrival backstories / "what they are trying to get back to" (§3)** → Pillar 2 (The Watched
  Feeling). Each named NPC's anchor is a voice-register constraint, not a stat — it surfaces in how
  they speak about their work. Tenures and registers match WORLD_STATE.md §3/§3b exactly.
- **The inflow mechanic's narrative register (§4)** → Pillar 3 (Moral Weight). Assigning a frightened
  arrival is logistics that is secretly a moral choice; the cost surfaces in the arrival's later arc,
  not at assignment time. Mechanics owned by NPC_INFLOW_PRODUCTIVITY.md.
- **False hope toward arrivals (§6)** → Pillar 2 and Pillar 3. The manager's false hope is weighted
  more heavily (institutional authority) and is tracked through the arrival's trust register and the
  player character's `anchor_erosion_delta` (WORLD_STATE.md §7) — the world responds to the player's
  condition, not just their choices.
- **The gossip culture / three-stage model (§7)** → Pillar 2 and Pillar 4. Information circulates
  before the player is told, and night-phase transmission means Day choices shape what is known by
  Dawn. Seeded-per-run stochasticity (ARCHITECTURE.md replay_salt) prevents an optimal suppression
  path, preserving moral weight. NOT-THIS compliance: no new UI, no transfer notifications, no moral
  framing on transmissions.

**NOT-THIS compliance**: no survival meters (anchors are register, not hunger/sanity bars); no day
recap (gossip and arc surface through behavioral state lines only); no binary good/evil framing on
false hope or gossip.

---

## 1. The Trap Mythology — How People Arrive

**The liminal trigger.** Arrival happens in a between-space: a road between two places, a doorway between two rooms, a platform between two trains. The moment must involve motion that is not the destination. The threshold is not a portal — it is the moment attention lapses between here and there. Specific instances: a driver reaching for the radio on a familiar highway; a person crossing an intersection mid-thought; a person walking through a parking garage stairwell.

**The first 30 seconds.** The path behind them ends. Not fades — ends. Second-growth forest, close and even. The light is wrong for the time of day they remember. Work sounds before voices: the scrape of tools on wood. Air smells like sawdust, damp earth, something faintly chemical that has no name. Phone: no signal, battery percentage they don't remember. They are already walking toward the settlement before they have decided to walk.

**What existing residents experience.** They know before they see. Work sounds pause — not dramatically, the way a building changes when a door opens. Their faces when they meet the arrival: careful, kind, closed. They do not say "you can't leave." They do not say "welcome." They ask the person's name, whether they are hurt, what they were doing before. The practiced quality of this calm is the first information the player receives about what this place is.

**The player character's last sensory memory.** The smell of a rental car's interior deodorizer. They had been driving somewhere they did not particularly want to go.

---

## 2. The Player Character's Backstory

**Ordinary life at arrival.** Mid-level operations manager, facilities or logistics. Driving a rental car between a job site and an airport. A Tuesday in the middle of an ordinary job stretch.

**What they remember and what they don't.** They remember the car, the smell, the approximate time of day. The exact road is gone. The name of the airport is gone. The name of whoever they were driving back to is present but unstable — they know the face, they cannot always hold the name. This is not amnesia as a condition. The trap takes the most motivating thing a person carries and makes it slightly unreliable.

**Why they are the manager.** The previous manager, Sorell, walked into the western forest during Night 6 of his tenure and did not come back. In the morning Thomas Vael handed the supply ledger to the player character because they were standing next to it. Not a promotion. The immediate, practical passing of a problem to whoever was present.

**What they want.** To go home. To remember the name. The managerial role makes this worse: they are responsible for other people's survival, which makes leaving feel like abandonment even if it were possible. The more they learn the township's systems and debt, the more they understand why no one has left. The competence that made them useful is now what keeps them here.

---

## 3. NPC Arrival Backstories

**Ruth Callan.** Unloading groceries in her driveway, approximately 7 PM. In Harrow's Crossing: four months. Anchor: her daughter, eleven, who was presumably in the house. She maintains her belief that she will return as a discipline, not because it is organic — she has seen what happens to people who stop. She does not speak about her daughter to other residents.

**Thomas Vael.** Waiting at a bus stop in a city he had lived in for twenty years. In Harrow's Crossing: seven months. Anchor: a specific apartment — not a person, but the accumulated objects of a person who lives alone and built something careful out of that. He does not believe he will get back. He has made no peace with this. His practicality is a grief response.

**Maren Voss.** On a run through a city park, earbuds in. In Harrow's Crossing: three months — the most recently arrived of the six. Anchor: the end of a graduate program she was six weeks from completing. The anchor is not really the program but the person she was going to become. She is still in the phase where she catalogues inconsistencies as evidence toward a solution.

**Elias Grout.** Driving a delivery route between his second and third stop. In Harrow's Crossing: nine months. Anchor: his brother, with whom he had an unresolved argument the morning he arrived. He does not know what his brother thinks happened to him. This uncertainty is the texture of his daily dread. He is the most productive person in the township and uses productivity the way other people use drinking.

**Constance Harrow.** No single arrival story she can accurately tell. She remembers a gravel road. She remembers it was summer. She does not remember where she was going. She does not remember the name of the town she came from. In Harrow's Crossing: approximately three to four years. Anchor: foreclosed. She stopped asking it because she observed, over years, that the asking produces nothing. She found the original land survey in the settlement's records shortly after arriving and recognized the falsification through her background (surveying or civil records — specifics pending). She has not shared what she found. The township name attached itself to her the way names attach to people who stay: practically, then officially, then without anyone remembering when it happened. This frightens her in a way she does not examine.

**Peder Lund.** In a hospital waiting room — not as a patient, waiting for news about someone else. In Harrow's Crossing: two years. Anchor: whoever was in that hospital. The face is clear, the relation is clear, the name is intact. The trap has not taken any of it. He does not know why. He treats this as either protection or debt. He oscillates.

---

## 4. The NPC Inflow Mechanic

> Narrative layer only. Mechanical specification — skill domains, settling curves, productivity outputs, cooperative bonding, season-modulated arrival quality, and productivity floors — is in `NPC_INFLOW_PRODUCTIVITY.md`. This section owns the narrative register of arrival.

**Arrival trigger.** Not random, not fully player-controlled. Baseline frequency is season-modulated: one arrival per 6 days in Late Summer, accelerating to one per 2 days in Deep Winter. Rate increases when THE DEBT is high — the land under pressure draws more people through. The player can influence the rate but cannot prevent arrivals. This is one of the few events that operates independently of player choice.

**Arrival state.** New arrivals have their former-life skills, their former-life clothes, and whatever they were holding or wearing when they crossed. They are not injured. They are frightened in a specific way: not panicked, but precise, the fear of a person who understands that something has happened but not what. They are lucid and capable within hours.

Three archetype arrival types:

- **The Practical** (tradesperson, first responder, medical worker): useful immediately. Micro moral choice: assign to urgent work before they have processed arriving, or wait. Efficiency requires treating their crisis as secondary. Waiting costs something real. Maps to immediate deployment (Path C) vs. full integration (Path A) in the settling mechanic.

- **The Dependent** (arrived alongside someone who did not come through — a parent, a partner): not disoriented, but damaged. Skills exist but are not accessible. The player can wait (has costs), undertask them, or ask them to set the loss aside. The game does not label the third option as a moral choice. Settling arc begins damaged regardless of path — the loss is prior to the player's first decision.

- **The Theorist** (any background, responds to the incomprehensible by generating explanations): disruptive to morale because theories spread and raise hope. Skills are mixed. Primary impact is Social domain — a Theorist assigned to the Settlement Common accelerates faction trust accumulation but also accelerates false-hope spread. A Broken Theorist spreads despair instead. Managing them requires deciding how much false hope the township is allowed, and who decides that.

**Integration mechanic.** The player assigns three things within the first in-game day: housing (places them near specific NPCs, affecting those NPCs' behavior), a role (activates their skill set, determines who they work alongside), and a first conversation (sets relationship register with the player). None labeled as moral. Housing is the most consequential: near Constance means she must interact with their raw hope; near Elias means they are immediately put to work. The moral weight surfaces in the arrival's arc over the following days.

**The hope and its failure.** When a new arrival appears, named NPC dialogue registers shift for approximately half an in-game day — questions become slightly more open, small practical information is shared more readily. The disproof happens quietly: the arrival's answers confirm only that the world is still out there, not that there is a way back. NPC tone does not collapse after this. It returns to baseline. The baseline is permanent. The hope was temporary. Everyone present has done this before.

---

## 5. The Escape Mythology

**Three circulating theories:**

- *The Survey Theory*: The land was taken fraudulently and the trap is a consequence — legal, ecological, or something older. If the falsification could be corrected or the debt paid, the trap might release. Circulates in fragments. No one has the full shape of it. Constance has not shared what she knows. This theory is directionally true.

- *The Threshold Theory*: People can leave the same way they arrived — through inattention in motion. The trap only closes when you are trying to leave. Several people have tested this. None returned to report. The township interprets this as either success or death. The ambiguity is load-bearing.

- *The Debt Theory*: Something is owed — personal and non-transferable. Each person owes something specific; when it is paid, they go. No one agrees on what or to whom. Popular because it gives individuals agency. Emotionally functional. Factually unverifiable.

**What the Compact knows.** They have watched multiple escape attempts fail and multiple theories cycle. They have stopped engaging with them — their silence reads as skepticism. What they hold privately: at least two people have left the visible boundaries of the township and not come back, and those departures did not look like escape. They looked like disappearance. The Compact does not share this because sharing it would cause harm without providing remedy.

**What Constance Harrow actually knows.** She has correlated the survey boundaries with where the trap operates — Zone 5 is precisely the falsified parcel. THE DEBT intensifies in proximity to that zone and during periods of high resource pressure. Her working theory, unconfirmed: the trap is not punitive, it is adhesive. The land is drawing what it needs to sustain a fraudulent claim. People are the substance of that claim. Not imprisoned — collateral. She has not shared this because she has no remedy to attach to it.

**What Chapter 1 will not answer.** The origin of the trap — ecological, supernatural, bureaucratic, or without category — is not answered. Whether escape is possible is not answered. What THE DEBT is owed to and by whom is not answered. The survey falsification and its relationship to the trap is legible as a pattern in Chapter 1 but not confirmed as mechanism. Chapter 1 ends with the player knowing the land's history is wrong and consequential. Nothing else is closed.

---

## 6. The Emotional Register of Trapped People

**How the "going home" motive surfaces without being stated.** Residents handle objects with more care than the objects warrant. A person eating pauses before the first bite — not religious, just deliberate. Someone repairing a tool works past functional repair. When a resident receives something new, they hold it before putting it to use. The tell is not nostalgia. It is the action of a person who has learned that ordinary things can be lost without warning.

**Specific objects that carry weight.** Things arrived with, worn past original purpose but not discarded: a jacket worn in all weather, a wallet with nothing left in it that matters, a piece of paper soft at the creases from refolding. Things built in the township that replicate something from before: a shelf arrangement, an organizational habit, a food preparation approximating something from home without the right ingredients. Residents do not speak about these objects. They are not shrines. They are the residue of a continuous effort to remain a person who exists somewhere specific.

**Hope for escape as moral weight.** When the player offers a new arrival false hope about escape — implies knowledge of a way out, suggests the arrival's information might be the key, makes a promise contingent on what the player cannot deliver — this is a micro or mid moral choice depending on specificity. The cost surfaces not in the arrival's immediate reaction, which is relief, but in their later behavior when the promise fails. The manager's false hope is weighted more heavily than the same hope from any other resident: the manager's word is institutional. When the manager offers false hope, they are spending an authority they did not earn and cannot replenish. The system tracks this through the arrival's trust register. The depletion is quiet and total.

---

## 7. NPC Gossip Culture — How Information Moves Without the Player

> Mechanical integration: `NPC_INFLOW_PRODUCTIVITY.md` (bond depth as gossip threshold), `ARCHITECTURE.md` (knowledge_state field in USER block, gossip_chain logging), `WORLD_STATE.md` (per-NPC gossip disposition). This section owns the narrative register and three-stage model.

Harrow's Crossing is small enough that nothing stays private, but damaged enough that no one speaks directly. Information moves laterally — through implication, adjacency, and the specific weight of what someone does not say when they could. The player is embedded in this network whether they intend to be or not. Their choices about who works beside whom, who sleeps near whom, and who is allowed to speak first condition the shape of what gets known and when.

The gossip network is not a system the player manages. It is a system the player creates the conditions for, and then lives inside.

---

### The Three-Stage Model

Every piece of information that moves between NPCs follows this sequence. The player does not see the stages. They see only the behavioral state changes that result.

**Stage 1 — Witnessed.** An NPC observes something: a night horror from their post, another NPC's behavioral shift, the player's visible choices in the Settlement Common, a faction exchange they were adjacent to. The observation is logged internally. It immediately affects their own behavioral state line — their register becomes slightly more closed, or slightly more alert, or slightly more deliberate.

**Stage 2 — Held.** The NPC holds the observation. They have not decided whether to pass it along. Whether they do depends on three factors: how much they trust the potential recipient, how much the observation threatens something they care about, and whether the player has created proximity between them and someone they trust. An NPC in isolation holds everything. An NPC who has worked beside a trusted colleague for two days holds almost nothing.

**Stage 3 — Maybe Told.** At transition points — shift change, shared zone time, dusk or dawn adjacency — an NPC with a held observation may transmit it. The transmission is stochastic but seeded by relationship strength: the same two NPCs with the same observation produce the same transfer outcome in a given run, but different relationship conditions produce different outcomes. The player cannot memorize the optimal suppression path. They can only shape relationships.

When Stage 3 fires, the receiving NPC's behavioral state line shifts before the next player-facing interaction. The player does not see the transfer. They see Ruth, whose line yesterday read "Working the early shift, watching the mill" and today reads "Working the early shift. Hasn't gone near the eastern window." Something changed. What changed is the player's inference problem.

---

### Per-NPC Gossip Disposition

Each NPC has a distinct threshold and transmission register determined by their voice profile and visible want/fear. These are not stats. They are behavioral constraints on LLM generation — the NPC Behavior Agent reads these dispositions from `WORLD_STATE.md` to ensure gossip transmission registers match voice.

**Ruth Callan — Selective Disclosure.** High threshold. Will not gossip casually. Transmits only what the crew needs to survive. If she holds something about the player, she keeps it. If she holds something about the treeline or the structure, it goes to whoever is most capable of acting on it. Information from Ruth carries more weight with recipients — they trust her calibration. A transmission from Ruth changes the receiver's behavior more than the same information from Thomas.

**Thomas Vael — Pressure Valve Disclosure.** Low threshold. When nervous, he tells whoever is in the room — not because he wants the information known, but because holding it makes him more nervous and he has not learned to distinguish between relieving anxiety and creating risk. His transmissions always include framing and causation ("I think it's because..."). Recipients discount his register slightly, which means his leaks are less immediately impactful — but they still move the information.

**Maren Voss — Fear-Activated Disclosure.** Does not initiate. When cornered — when her fear-state is elevated by what she knows — she moves information outward as a pressure release. She does not choose her recipient strategically; she tells whoever is nearest or whoever she last had a meaningful exchange with. The player who cornered Maren about the ledger will find that information in an unexpected place by the following morning. The player who assigned Maren to her visible want has reduced her fear-state; she holds information longer.

**Elias Grout — Bond-Exclusive Disclosure.** Near-zero transmission threshold to anyone except a bonded NPC (2+ consecutive days, same zone). With a bonded NPC, the threshold inverts: he transmits almost everything he holds, in fragments across shifts, at a pace the recipient absorbs without realizing they have been briefed. A player who bonds Elias with Ruth will find Ruth knowing about the treeline before she should, watching the eastern edge instead of the mill, working with a specific focused quality that was not there before. A player who keeps Elias isolated will find him holding everything — which has its own behavioral consequence. He becomes quieter. His line becomes sparser. By Day 3 he is functionally unreachable.

**Constance Harrow — Receiver Only.** Constance does not transmit. She has been in the township long enough to understand that information, once released, cannot be recalled — and she has seen what recalled information costs. She listens. She absorbs. Her behavioral state line updates when she receives something significant, and her interaction options shift (new inquiry options unlock, existing options close). She is the township's accumulated intelligence: everything flows in, nothing flows out until the player creates conditions for direct speech. She is not a vault. She is a person who learned, through years, the cost of speaking.

**Peder Lund — Environmental Register Only.** Peder does not gossip about people. He observes conditions: the soil is softer than yesterday, the fourth wall is settling faster than the frame supports, the torchline at Zone 4 is lower than it should be. His "gossip" is environmental specificity stated as practical logistics. NPCs in his zone absorb these observations through adjacency — working beside Peder means slowly accumulating his read of the ground conditions, the structural state, the perimeter. He does not know he is transmitting. They do not know they are receiving. The information moves because competent people working together share context without naming it as sharing.

---

### How the Player Conditions the Network

The gossip system requires no new player-facing mechanics. It runs entirely on choices the player is already making.

**Zone assignment (who works beside whom)**: Two NPCs assigned to the same zone for 2 consecutive days form a bond. Bonds lower transmission threshold to near-zero for bond-exclusive NPCs (Elias) and raise the credibility weight of transmissions between all bonded pairs. The player who assigns Elias and Ruth together has created the township's most reliable intelligence channel. The player who keeps them separated has created two isolated observation posts that never compare notes.

**Housing placement (night adjacency)**: NPCs housed near each other can transmit during the night phase — at shift change, at dusk, at dawn. Night-phase transmission is the primary route for observations that happened after the player lost input control. An NPC who witnessed a horror event at third watch and is housed near a trusted NPC will have transmitted by dawn. An NPC housed in isolation holds what they saw until the next shared zone shift.

**First conversation with arrivals**: The player's first conversation choice sets the arrival's initial trust register. An arrival who had their first conversation interrupted or skipped has a lower initial trust threshold — they transmit observations more readily because they have not calibrated who to trust. An arrival who had a genuine first conversation transmits more selectively, and their transmissions carry more credibility weight when they do.

**The Compact interaction (public vs. private)**: Faction interactions in the Settlement Common are observed by whoever is present. Signing or refusing the ratification document in the Common is witnessed by Ruth (if assigned to Zone 2). Elias is not present. Ruth does not speak about it immediately — but if bonded with Elias, he will know by dusk. The player who handles faction business in private (scheduling it during a shift window when Zone 2 is clear) reduces the number of observers. The player who never considers who is in the room when they negotiate is building a network of witnesses they did not account for.

---

### Gossip During Night Phase

The player cannot issue orders at night, but the gossip network does not pause. NPCs on adjacent posts or in shared housing continue the transmission process. What fires at night is primarily Stage 3 for observations that were held through the day — fear-state observations, treeline reports, witnessed faction choices.

The dawn consequence thread (see `REVEAL_MECHANIC.md`) names what the night changed. The gossip network creates a second layer: when the player clicks on Ruth at dawn, her behavioral state line has already processed what the thread is about to report. Ruth knew. She has been sitting with it since third watch. The thread tells the player what happened. Ruth's line tells the player the township has already begun to respond.

This is the Watched Feeling operating at network scale: not one creature observing the player, but six people drawing their own conclusions — and those conclusions have already circulated before the player is told the facts.

---

### What the Gossip System Does Not Do

- Show the transfer. No "Ruth told Peder that..." notification. No log entry for the player.
- Label the consequence. If Maren leaked to the Compact and their Day 3 stance is different, the game does not explain why.
- Make transmission deterministic. The player cannot memorize the optimal isolation path and achieve information suppression. The randomness is seeded per run; different relationship choices produce different outcomes.
- Add moral framing. Information moving between NPCs is not labeled as good or bad. Ruth telling Elias what she saw may be exactly what the player needed. The weight is in not knowing which until the consequence surfaces.
- Require new UI. The gossip network is invisible as a system. Its effects appear exclusively through behavioral state lines and faction stance shifts — interfaces that already exist.
- Make NPCs articulate about what they received. An NPC who received a transmission does not say "I heard from Elias that..." They show the effect. The cause is the player's inference problem.
