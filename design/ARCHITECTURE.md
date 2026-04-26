# Backend Architecture — Hollow Township

> Status: FROZEN (2026-04-26). All pending decisions resolved. Architecture is the moral consequence engine for a real-time horror RPG.
> All decisions here serve `PILLARS.md`. Infra exists to enable Earned Dread, not general-purpose game hosting.

---

## Design Constraints Driving Architecture

From the frozen design pillars:

- **Night outcomes shaped by Day choices** (Pillar 4) → player state must persist reliably between day/night cycles; no event can be random
- **The Watched Feeling** (Pillar 2) → NPC behavior must have memory across sessions, not just the current session
- **Moral Weight at Every Turn** (Pillar 3) → consequence tracing requires a log of player micro choices, queryable at any point
- **Earned Dread** (Pillar 1) → horror generation is not content delivery; it is consequence computation
- **Real-time gameplay** → all backend responses must land under 300ms. Pre-computation is the primary latency strategy; LLM inference never blocks player action.

The backend is a **moral consequence engine**, not a content delivery system.

---

## Frozen Decisions

All four previously-pending decisions are now locked.

| Decision | Resolution | Rationale |
|----------|-----------|-----------|
| Primary model | **Claude Haiku (claude-haiku-4-5)** | Lowest per-token cost within the $0.05/session budget. Prompt caching at 10× amortizes to ~$0.004/session effective LLM cost. Tone constraint system (below) compensates for smaller model expressiveness. |
| Night phase transport | **WebSocket (persistent, per-session)** | Gameplay is real-time. Night horror cannot tolerate REST round-trip latency. WebSocket is opened at day→night transition and held open for the duration of the night phase. Day phase uses REST (decision points are discrete). |
| Consequence Trace Agent | **DynamoDB write inside Lambda** | Dedicated service adds ops overhead with no capability gain at indie scale. A synchronous DynamoDB write in the choice Lambda is simpler, cheaper, and sufficient for audit/replay through 50K DAU. Revisit only if consequence queries become complex (JOIN-style lookups). |
| Session auth / social layer | **Nakama (Heroic Labs) at Phase 2+** | Nakama is deferred to Phase 2 (500+ DAU). Phase 1 uses Cognito for auth (already in Lambda ecosystem). Nakama's $25–100/month adds boilerplate removal only worth it once leaderboard/social features are designed. Not a Day 1 requirement. |

---

## Agent Architecture

### Agent Types

Six agents. Each has a single responsibility. None are generalist.

```
┌─────────────────────────────────────────────────────────┐
│                  MASTER ENFORCER AGENT                   │
│         Warm singleton. Validates all LLM output.        │
│  Checks: tone, pillar compliance, lore consistency.      │
│  Intercepts and reruns any output that violates pillars. │
│  ALSO enforces: cached-prompt freshness, tone profile    │
└────────────────────┬────────────────────────────────────┘
                     │ all output passes through here
          ┌──────────┼──────────┐
          ▼          ▼          ▼
┌──────────────┐ ┌──────────────┐ ┌──────────────┐
│  STORY       │ │  NPC         │ │  CHARACTER   │
│  PROGRESSION │ │  BEHAVIOR    │ │  ARC         │
│  AGENT       │ │  AGENT       │ │  AGENT       │
│  per-player  │ │  faction     │ │  per NPC     │
│  dormant     │ │  logic       │ │  vector mem. │
└──────────────┘ └──────────────┘ └──────────────┘
          ┌──────────┼
          ▼          ▼
┌──────────────┐ ┌──────────────┐
│  CREATURE /  │ │  CONSEQUENCE │
│  HORROR      │ │  TRACE AGENT │
│  AGENT       │ │  (DynamoDB   │
│  night phase │ │  write in λ) │
└──────────────┘ └──────────────┘
```

### Agent Responsibilities

| Agent | Trigger | State | Cost Class |
|-------|---------|-------|------------|
| Master Enforcer | All LLM outputs | Warm singleton (Fargate Phase 2+, Lambda Phase 1) | Medium — always on |
| Story Progression | Player decision point | Dormant, per-player | High — LLM inference |
| NPC Behavior | Day cycle tick, faction event | Dormant, shared templates | Low — mostly rule-based |
| Character Arc | Session boundary, significant event | Vector DB backed | Low — retrieval-heavy |
| Creature/Horror | Night cycle, shaped by day state | Dormant, per-player | Medium — constrained generation |
| Consequence Trace | All micro/mid/macro choices | DynamoDB write inside Lambda | Negligible — audit only |

### Why a Master Enforcer Agent Exists

Without it, LLM-generated content drifts. At 58 inference calls per session, even a 5% pillar-violation rate means ~2.9 violating outputs per play session. The enforcer intercepts all Story Progression and Horror outputs, validates against the five pillars, and retries on failure. Retry rate target: under 2%. Cost of retry: 2× inference cost for ~1% of calls — acceptable.

### Master Enforcer: Retry Policy and Fallback

Retry cap: 3 attempts per generation request.

Attempt 1: Normal generation — full dynamic context (player state + NPC memories + scene history).
Attempt 2: Reduced context — cause_chain items only. Strip NPC memories and scene history.
            Isolates the causal signal, removes noise that may be confusing generation.
Attempt 3: Fallback event library — authored minimum-viable horror events (see below).
            These are not generated. They are human-authored, tone-validated, and require only
            npc_id + day + zone to render.

If all 3 fail: write to error_queue (Phase 1: error log; Phase 2+: PagerDuty alert).
              Serve fallback event. Do not block night phase delivery.

Fallback event template (authored, tone-validated):
{
  "event_text": "[NPC_NAME] did not call out from [ZONE] at the third watch. The post is standing. [NPC_NAME] is simply not at it.",
  "cause_chain": ["[CHOICE_ID]"],
  "horror_intensity": 1,
  "traceable_to_day": "[DAY]",
  "tone_check": "authored"
}

Fallback library size: 20–30 authored events covering core NPC/zone combinations.
Written by human author. Stored in: /backend/enforcer/fallback_events.json
Version-controlled. Never generated at runtime.

---

## LLM Consistency System — Tone Lock

This is the primary defense against tone drift. It is not optional. All LLM calls are structured identically to prevent drift across sessions, agents, and model upgrades.

### Canonical Prompt Structure

Every LLM call follows this exact envelope. Deviation is not permitted.

```
[SYSTEM — CACHED]
  ├── Tone Profile (immutable)
  ├── Pillar Constraints (immutable)
  ├── World State Baseline (immutable per chapter)
  └── Generation Rules (immutable)

[USER — DYNAMIC]
  ├── Current Player State Delta (< 800 tokens)
  ├── Relevant NPC Memories (2–5 retrieved from Qdrant)
  ├── Last 3 Scene Summaries (compressed, < 600 tokens)
  ├── NPC Knowledge State (per NPC: what they currently hold, not how they got it — see Gossip Engine below)
  └── Specific generation task ("generate night event", "advance NPC arc", etc.)

[ASSISTANT — PREFILL]
  └── "{" — forces JSON output, prevents prose preamble
```

The SYSTEM block is **identical across all calls to the same agent type**. This is the cache hit. The USER block carries only the delta. Total prompt budget per call: ~1,500 tokens (system: ~900, user: ~600).

### Tone Profile (Frozen)

The Tone Profile is included verbatim in every SYSTEM block. It is not summarized or paraphrased.

```
TONE PROFILE — HOLLOW TOWNSHIP (DO NOT DEVIATE)

Register: Horror drama. Not horror comedy. Not psychological thriller.
  Not survival anxiety. Horror that comes from consequence, not from danger.

Dread signature: Quiet wrongness. The horror is the realization, not the event.
  The night does not attack the player — the night reveals what they built.

Sentence rhythm: Short. Declarative. No ornament. Never explain the horror.
  Let the image stand.

Forbidden outputs:
  - Comic relief (NPC quips, ironic distance, winking at the darkness)
  - Positive resolution framing ("but at least...", "perhaps this means...")
  - Urgency language (exclamation constructions, time-pressure tone)
  - Abstract horror (unnamed dread without physical correlate)
  - Hope language in night-phase content

Horror must be traceable: Every horror image must reference a player action.
  Format: "[consequence of X] because [player did Y]" — even if only implied in subtext.

Character voice: Each NPC has a frozen voice profile in WORLD_STATE. Never merge voices.
  Never have an NPC speak in a register inconsistent with their profile.

CONDITIONAL PERMISSIONS (once per chapter, must be earned):
  Warmth: Two named NPCs with shared prior consequence may show connection through behavior only.
    Format: working alongside each other without speaking about it. No dialogue about care.
    Trigger: only after both NPCs have experienced a shared consequence event.
  Dark humor: One bitter line per chapter, NPC-specific to that character's voice register.
    Not permitted: NPCs with stoic or formal voice registers.
    Not permitted: humor about the horror itself. Only about the NPC's situation.
    Not permitted: as a response to horror events.
  Explicit loss: One direct statement of what an NPC has lost. Once per chapter.
    Trigger: only AFTER that NPC has experienced a consequence traceable to player choice.
    Not permitted: preemptive grief. Retrospective only.
```

### Generation Rules (Frozen)

```
GENERATION RULES

Output format: JSON only. No prose wrapping. No markdown. Schema per agent type (see schemas below).
Token budget: Output ≤ 300 tokens. Concise is correct. Padding is a failure.
Consequence tracing: Every output includes a `cause_chain` field listing the player
  choice IDs that contributed to this output. Minimum 1 item. No consequence without cause.
Tone validation: Before returning, re-read the output. If any Forbidden Output pattern
  is present, rewrite. Do not return a tone-violating response.
Character consistency: NPC name in output must match NPC name in input exactly.
  Do not invent NPCs. Do not merge or rename existing NPCs.
```

### Output Schemas (Per Agent Type)

**Story Progression Agent:**
```json
{
  "scene_text": "string (≤ 200 chars)",
  "npc_state_deltas": [{"npc_id": "string", "state_key": "string", "new_value": "string"}],
  "cause_chain": ["choice_id_1", "choice_id_2"],
  "moral_tier": "micro | mid | macro",
  "tone_check": "passed | flagged"
}
```

**Horror/Creature Agent:**
```json
{
  "event_text": "string (≤ 200 chars)",
  "threat_npc_ids": ["string"],
  "cause_chain": ["choice_id_1", "choice_id_2"],
  "horror_intensity": 1 | 2 | 3,
  "traceable_to_day": "day_1 | day_2 | day_3",
  "tone_check": "passed | flagged"
}
```

**NPC Arc Agent:**
```json
{
  "npc_id": "string",
  "arc_delta": "string (≤ 150 chars — internal state change only)",
  "dialogue_fragment": "string (≤ 100 chars — surface text only)",
  "cause_chain": ["choice_id_1"],
  "skill_domain": "string | null (construction|medicine|logistics|observation|social — present for arrivals only)",
  "settling_path": "string | null (integration|accelerated|rushed — present for arrivals only)",
  "tone_check": "passed | flagged"
}
```

USER block construction for arrival NPCs: the dynamic context builder reads `player_arrivals` for any NPC that has an arrival record and includes `skill_domain`, `skill_depth`, and `settling_path` in the USER block. This ensures behavioral state lines for arrivals reflect domain-appropriate register (see WORLD_STATE.md Section 2b). Original six NPCs are unaffected — these fields are null for them.

### Prompt Cache Implementation

All SYSTEM blocks use Claude's prompt caching API (`cache_control: {"type": "ephemeral"}` on the system message). Cache TTL is 5 minutes; the system prompt is re-sent if cache is cold. Cache hit rate target: ≥ 95% in active sessions.

```python
# Anthropic SDK — canonical call structure
response = client.messages.create(
    model="claude-haiku-4-5",
    max_tokens=300,
    system=[
        {
            "type": "text",
            "text": FROZEN_SYSTEM_PROMPT,  # Tone Profile + Pillars + World Baseline + Generation Rules
            "cache_control": {"type": "ephemeral"}
        }
    ],
    messages=[
        {"role": "user", "content": build_dynamic_context(player_state, npc_memories, scene_history, task)},
        {"role": "assistant", "content": "{"}  # JSON prefill
    ]
)
```

The `FROZEN_SYSTEM_PROMPT` is compiled at server startup and never modified at runtime. Version-pinned in git. Any change to it requires a new deploy — this is intentional.

### Tone Drift Prevention

Tone drift is a production failure, not a content imperfection. Three layers prevent it:

1. **Frozen system prompt**: The Tone Profile is immutable. It cannot drift because it cannot change at runtime.
2. **Master Enforcer validation**: Every output is re-scored before delivery. Enforcer checks `tone_check` field and also re-reads `scene_text`/`event_text` against the Forbidden Outputs list.
3. **Automated regression test**: On every deploy, a suite of 50 adversarial prompts (covering all Forbidden Output patterns) runs against both agents. Deploy fails if any prompt returns a tone-violating output.

---

## Real-Time Architecture

Gameplay is real-time. The architecture is built around this constraint.

### Latency Budget

| Phase | Operation | Target Latency | Strategy |
|-------|-----------|----------------|----------|
| Day phase — micro choice | Acknowledge + log | < 50ms | Fire-and-forget to SQS. No LLM on critical path. |
| Day phase — narrative trigger | NPC dialogue, faction response | < 300ms | Lambda warm + cached prompt. LLM on critical path but fast. |
| Day → Night transition | Pre-compute night events | 2–5s (background) | Computed at transition moment, not on player click. Player sees "night falls" animation while computation runs. |
| Night phase — horror event | Push to client | < 100ms | Pre-computed. WebSocket push from DynamoDB read, not LLM call. |
| Night phase — reactive horror | Player action triggers consequence | < 300ms | Only if player takes an unscripted action during night. Rare. |

**Critical rule**: LLM inference never blocks a player action in real-time. The night phase is pre-computed at transition. Day phase LLM calls are triggered only at deliberate decision points (not on movement or building hover).

### Day → Night Pre-Computation Pipeline

```
Day Phase Ends (player triggers night)
        │
        ▼
  POST /transition/night { player_id, day_summary_delta }
        │
        ▼
  Lambda: Night Computation Job
    1. Load full player state from DynamoDB
    2. Load all micro/mid choices from current day (Consequence Log)
    3. Retrieve relevant NPC memories from Qdrant
    4. Call Story Progression Agent → generate Night Event Queue (3–7 events)
    5. Call Horror Agent → generate Horror Sequence (shaped by event queue)
    6. Master Enforcer validates all outputs
    7. Write Night Event Queue to DynamoDB (player_night_queue table)
    8. Return { queue_id, eta_ms } to Godot
        │
        ▼
  Godot renders night transition animation (~2–4s)
  Backend computation completes during animation
        │
        ▼
  WebSocket push: { event: "night_ready", queue_id }
  Night phase begins — all events served from pre-computed queue
```

Night events are served from DynamoDB reads over WebSocket — no LLM inference during active night phase. Latency is I/O only (< 50ms).

### Transport Architecture

```
Day Phase:   Godot → REST (HTTPClient) → API Gateway → Lambda
             Response: 200 OK + narrative delta

Night Phase: Godot ↔ WebSocket (wss://api.hollowtownship.com/night-feed)
             Direction: bidirectional
             Opened: at day→night transition
             Closed: at night→dawn transition
             Events pushed: pre-computed horror queue, NPC state changes
             Events received: player reactions during night (rare)

State sync:  Delta only. Gzip compressed. Budget: < 4KB per payload.
```

---

## Player-Level Logging — Scalable Design

Every player action that carries moral weight is logged. This log is the source of truth for the consequence engine.

### What Gets Logged

```
ALL choices, always. Moral tier assigned at write time.

micro:  Building placement, NPC job assignment, resource allocation, 
        patrol route, first response to NPC dialogue (these feel mechanical)
mid:    Faction negotiation outcome, resource prioritization under scarcity,
        who gets assigned to dangerous role
macro:  Explicit moral forks, sacrifice choices, promise/betrayal events

NOT logged: movement, UI interactions, camera, settings, anything 
            without downstream NPC or consequence impact.
```

### DynamoDB Schema

```
Table: player_choices
  PK:  player_id              (string)
  SK:  choice_id              (ulid — sortable, time-ordered)
  
  Attributes:
    day_cycle:      number    (1, 2, 3...)
    phase:          string    ("day" | "night" | "dawn")
    moral_tier:     string    ("micro" | "mid" | "macro")
    action_type:    string    ("build" | "assign" | "negotiate" | "sacrifice" | ...)
    npc_ids:        list      (all NPCs affected — enables NPC-centric queries)
    world_coords:   map       (x, y — building placement choices)
    choice_payload: map       (action-specific detail, < 1KB)
    consequence_ids: list     (populated retroactively when consequence fires)
    chapter:        number    (1, 2, 3...)

GSI-1: npc_id → choice_id    (all choices affecting a specific NPC, time-ordered)
GSI-2: day_cycle → choice_id (all choices on a given day, for night pre-computation)
GSI-3: moral_tier → choice_id (all macro choices, for chapter summary and arc agent)

Table: player_night_queue
  PK:  player_id
  SK:  queue_id (ulid)
  TTL: 24 hours (auto-delete after session)
  Attributes: [pre-computed event list, cause_chain refs, delivery status]

Table: player_session_state
  PK:  player_id
  Attributes: [current day/night, NPC relationship map, faction standings,
               chapter, last_save_timestamp, hot_state (≤ 2KB)]

Table: player_arrivals
  PK:  player_id
  SK:  arrival_id (ulid — sortable, time-ordered)
  Attributes:
    arrival_day:     number
    archetype:       string  ("practical" | "dependent" | "theorist")
    skill_domain:    string  ("construction" | "medicine" | "logistics" | "observation" | "social")
    skill_depth:     string  ("surface" | "practiced" | "deep")
    settling_path:   string  ("integration" | "accelerated" | "rushed")
    arc_state:       string  ("settling" | "present" | "contributing" | "functional" | "fragile" | "broken")
    bond_npc_ids:    list    (IDs of NPCs this arrival is bonded with)
    bond_depth:      number  (0–4; deepens with consecutive shared-zone days)
    output_modifier: float   (current productivity multiplier: 0.4–1.6)
    chapter:         number

GSI: skill_domain → arrival_id  (query all active arrivals by domain for productivity computation)

Bond state inclusion: NPC Behavior Agent receives bonded NPCs' arc states in the USER block alongside the
primary NPC. Bond vulnerability is computed server-side — a Walker targeting a bonded pair's zone triggers
a named horror variant specific to the bond. Bond depth and bond partner arc_state are included in the
pre-computation payload at day→night transition.

**Arrival event mirroring to player_choices (Gap 9 resolution)**: All arrival-management events
(housing assignment, role assignment, first conversation, bond acknowledgment) write a mirror entry
to `player_choices` with the arrival's internal NPC ID in `npc_ids`. The `player_arrivals` table
remains authoritative for productivity and arc computation. The mirror entry in `player_choices`
carries the investment signal for GSI-1 queries and the `chapter_1_investment_anchor` computation.
Arrivals are now eligible for anchor designation. Action types for mirror entries:
  "arrival_housing", "arrival_role", "arrival_conversation", "arrival_bond_acknowledge"
These are logged as micro-tier choices. A player who invested across 4 days in one arrival
will have 4 micro entries for that NPC ID — captured in the anchor computation.
```

**Gossip Engine — NPC Knowledge State (Amendment)**

The gossip system runs as a server-side propagation pass between day phase end and night pre-computation. It does not require an additional LLM call — it is a rule-based computation that updates the `knowledge_state` field for each NPC in `player_session_state`.

```
Table: player_session_state
  Attributes (additions):
    npc_knowledge_states: map
      {
        "ruth":      { held_observations: [...], trust_weights: {...}, gossip_stage: 1|2|3 },
        "thomas":    { ... },
        "maren":     { ... },
        "elias":     { ... },
        "constance": { ... },
        "peder":     { ... },
        "[arrival_id]": { ... }
      }
```

**Gossip propagation pass** (Lambda, runs synchronously at day → night transition before night pre-computation):

```python
# Pseudocode — full implementation in /backend/gossip/propagation.py
def run_gossip_pass(player_id: str, day: int) -> None:
    state = load_session_state(player_id)
    bond_pairs = query_bond_pairs(player_id)          # from player_arrivals + player_choices
    zone_pairs = query_same_zone_npcs(player_id, day) # from today's assign choices

    for npc_id, knowledge in state.npc_knowledge_states.items():
        if knowledge.gossip_stage < 2:
            continue  # nothing held to transmit
        disposition = NPC_GOSSIP_DISPOSITIONS[npc_id]  # from WORLD_STATE gossip_disposition
        for candidate_id in get_transmission_candidates(npc_id, bond_pairs, zone_pairs):
            trust_weight = compute_trust(npc_id, candidate_id, bond_pairs, day)
            roll = seeded_random(player_id, day, npc_id, candidate_id)  # deterministic per run
            if roll < trust_weight * disposition.base_threshold:
                transfer_observation(
                    from_npc=npc_id,
                    to_npc=candidate_id,
                    observation=knowledge.held_observations,
                    credibility_weight=disposition.credibility_weight
                )
                knowledge.gossip_stage = 3  # transmitted
    write_session_state(player_id, state)
```

**Disposition constants** (derived from WORLD_STATE gossip_disposition field):
```python
NPC_GOSSIP_DISPOSITIONS = {
    "ruth":      GossipDisposition(base_threshold=0.25, credibility_weight=1.4, trigger="safety_concern"),
    "thomas":    GossipDisposition(base_threshold=0.70, credibility_weight=0.85, trigger="fear_state"),
    "maren":     GossipDisposition(base_threshold=0.00, credibility_weight=1.0,  trigger="fear_activated"),
    "elias":     GossipDisposition(base_threshold=0.05, credibility_weight=1.2,  trigger="bond_only"),
    "constance": GossipDisposition(base_threshold=0.00, credibility_weight=0.0,  trigger="receiver_only"),
    "peder":     GossipDisposition(base_threshold=0.15, credibility_weight=1.1,  trigger="environmental_only"),
}
```

**Knowledge state in the NPC Behavior Agent USER block**: The dynamic context builder reads `npc_knowledge_states` and includes, per NPC, a compact summary of what they currently hold — without specifying provenance. Format: `"ruth_knowledge": "treeline movement Night 1; ledger discrepancy; player signed Compact document"`. The NPC Behavior Agent uses this to generate behavioral state lines that reflect what the NPC knows. It does not generate gossip acts; it generates state lines consistent with a person who holds this knowledge.

**Gossip chain logging to player_choices**: When a Stage 3 transfer fires, a `gossip_chain` entry is written to `player_choices`:
```
action_type: "gossip_transfer"
moral_tier:  "micro"
npc_ids:     [transmitting_npc_id, receiving_npc_id]
choice_payload: { observation_type: string, trigger: string, credibility_weight: float }
consequence_ids: []  # populated retroactively if gossip-mediated belief causes downstream event
```
This enables the Consequence Trace Agent to include gossip chains in the dawn thread when a night event is traceable to gossip-mediated belief shifts. The dawn thread entry names the original player choice that created the condition, not the gossip act itself.

**Cost impact**: Gossip pass is rule-based computation, no LLM inference. Adds ~15ms to day→night transition Lambda. Does not affect per-session LLM cost. The knowledge_state field in the USER block adds ~80–120 tokens per NPC Behavior Agent call — within the existing 600-token USER budget across the full NPC set.

### Scaling Properties

| Property | Design Decision |
|----------|----------------|
| Write throughput | Async DynamoDB write. Choice acknowledgment returns before write completes. |
| Read pattern | Night pre-computation queries GSI-2 (day choices). All other reads are PK lookups. No scans. |
| Retention | Full choice log retained per-player indefinitely (it's the replay/traceability backbone). ~200KB/player for a full Chapter 1 playthrough. Negligible at indie scale. |
| Horizontal scale | DynamoDB scales automatically. No ops work required through Phase 3. |
| Consequence backfill | When a night event fires, the Lambda retroactively writes `consequence_ids` back to the originating micro choices. Enables post-hoc player trace: "what night event did my Day 1 micro choice cause?" |
| Query cost | GSI-2 query (all day choices for night pre-computation) returns ≤ 30 items at Chapter 1 scale. Read unit cost: negligible. |

### Player-Facing Traceability (Design Intent)

The log is not shown to the player directly. But it powers the visibility of consequence:

```
Night 2 horror event fires → Lambda reads cause_chain → ["choice_abc123", "choice_def456"]
→ Retrieves choice_abc123: { action: "assigned_north_post", npc_id: "sarah", day: 1 }
→ Godot renders: "Sarah shivers at the northern wall she was assigned to watch."
```

The player does not see the log. They see Sarah. They made the connection already.

---

## Memory Architecture

### Why This Matters for This Game

"The Watched Feeling" requires the system to remember what a player did on Day 1 when rendering consequences on Night 3. Standard LLM context windows cannot hold 4 hours of gameplay state (~50K+ tokens, ~$1.25/request).

### Three-Tier Memory Model

```
HOT  (in LLM context)    — Last 3 scenes + current player state (~600 tokens)
WARM (vector DB)         — Character memories, faction standing, named NPC state
COLD (DynamoDB)          — Full choice log, consequence audit, all micro choices
```

- **Hot tier**: Built fresh per inference call. Small. Fast. Cheap.
- **Warm tier**: Qdrant vector search retrieves 2–5 most relevant memories per call. "What does the Priest remember about the player?" returns the 3 most relevant entries. Enables the Watched Feeling without reading the full log.
- **Cold tier**: Complete audit trail. Queried at night pre-computation (batch read) and chapter end. Cheap storage.

---

## AI Research Integration — Procedural Narrative

This section maps the state-of-the-art research findings from `AI_COMPETITION.md` onto concrete architecture decisions. Each known failure mode has a named countermeasure.

### Research Gaps Addressed

| Research Finding | Failure Mode | Hollow Township Countermeasure |
|-----------------|--------------|-------------------------------|
| LLM bias toward positive resolution | Dread evaporates; horror softens into comfort | Tone Profile explicitly forbids hope language and positive framing in night-phase content. Master Enforcer re-scores every output. |
| Genre constraint drift (horror → comedy/incoherence) | Tone breaks immersion | Frozen Tone Profile in system prompt. Forbidden Outputs list. 50-prompt automated regression suite on every deploy. |
| Causal logic loss across scenes | Night horror feels random | `cause_chain` field is mandatory in every LLM output. Night events that have no `cause_chain` are rejected at Enforcer, not delivered. |
| Character voice inconsistency | Named NPCs feel interchangeable | Each NPC has a frozen voice profile in WORLD_STATE. NPC Arc Agent is the only agent authorized to write NPC dialogue. All others reference NPC state, not voice. |
| Latency (800–1,200ms) breaks atmosphere | Player notices the AI | Pre-computation pipeline. Night events served from DynamoDB (< 50ms), not live inference. Day LLM calls target < 300ms with warm Lambda + cached prompt. |
| Repetition (same responses, no memory) | Breaks Watched Feeling | Three-tier memory. Qdrant retrieves relevant but non-repeated memories. Consequence Trace prevents re-firing the same event for the same cause. |
| "Procedurally unique ≠ meaningfully different" | Content feels hollow | Every generated event is grounded in a specific named NPC and specific player choice. The constraint of specificity is enforced by the output schema. No abstract horror allowed. |

### GENEVA Architecture Influence

GENEVA (Microsoft Research) generates narrative as directed acyclic graphs with emotional arc guidance. Hollow Township adapts this pattern:

- The Night Event Queue is a DAG of horror events, not a flat list.
- Each event has edges to the player choices that caused it (cause_chain) and to the events it enables (consequence propagation).
- Emotional arc guidance is enforced by moral tier: micro → mid → macro events must escalate within a session. The Story Progression Agent cannot generate a macro-intensity event before Hour 2:30 (see CHAPTER_ONE.md beat structure).
- The Master Enforcer validates arc escalation, not just tone.

### PANGeA / Character Intentionality

PANGeA uses Big Five personality profiles to constrain NPC behavior generation. Hollow Township adapts this:

- Each named NPC has a frozen profile: primary want, primary fear, behavioral register, relationship to player.
- The NPC Behavior Agent receives this profile in the USER block of each call (not the SYSTEM block — NPC profiles are dynamic, some NPCs die or change state).
- Character arc changes update the profile in DynamoDB. The arc cannot change faster than one state-key update per day cycle.

### Competitive Positioning Against Research Baseline

Academic systems (LIGS, Story2Game, GENEVA) operate in research contexts: isolated demos, short sessions, no persistence, no real-time constraint. Hollow Township's technical contribution is operating all of these simultaneously under production conditions:

- Real-time (< 300ms)
- Persistent memory across sessions
- Tone-locked genre constraint (no drift)
- Traceable causality (audit log as gameplay mechanic)
- Scalable player-level logging (consequence replay)

No shipped game does this. The research shows it's possible. Hollow Township is the first commercial proof.

---

## Cost Model

### Per-Session Estimate (with Prompt Caching)

```
Decision density calibrated from CHAPTER_ONE.md beat structure (5-day arc, April 2026 revision).

Decision point breakdown (per session):
  Micro choices:           ~18  (3–4 per day phase × 5 day phases)
  Mid choices:             ~5   (total across session — 1 per day except Day 1 and Day 5 has macro)
  Macro choices:           ~1
  Night consequence events ~18  (2–3 Night 1, 3–4 Night 2, 3–4 Night 3, 4–5 Night 4, 5–6 Night 5)
  NPC arc updates:         ~20  (6 original NPCs × 2 updates + 4 arrivals × 2 updates)
  Master Enforcer mirrors all above (1 validation call per generation call)
  Total:                   ~88 calls per session

Without caching:
  Input per call: ~1,500 tokens
  Output per call: ~300 tokens
  Claude Haiku pricing (Apr 2026): $0.25/1M input, $1.25/1M output
  Cost per call: ~$0.00075
  Cost per session (58 calls): ~$0.044

With prompt caching (95% cache hit rate, ~900 token system prompt):
  Cached input cost: $0.025/1M (10× reduction on system tokens)
  Effective cost per call: ~$0.00012
  Cost per session (88 calls): ~$0.011

Effective LLM cost per player session: ~$0.011 (still under 2 cents)
```

### Monthly Infrastructure Cost by Scale

| Tier | DAU | Concurrent Peak | Monthly LLM | Monthly Infra | Monthly Total | Per DAU |
|------|-----|-----------------|-------------|---------------|---------------|---------|
| Indie | 100 | 20–30 | ~$18 | ~$100 | **~$118** | $1.18 |
| Early Access | 1,000 | 150–200 | ~$180 | ~$400 | **~$580** | $0.58 |
| Growth | 10,000 | 1,500–2,000 | ~$840 | ~$1,500 | **~$2,340** | $0.23 |

Infrastructure breakdown (indie scale):
- Lambda + SQS + API Gateway: $15–25/month
- ECS Fargate (Master Enforcer, warm): $20–30/month (Phase 1: Lambda cold-start acceptable)
- Qdrant Cloud (NPC memory): $25–50/month
- DynamoDB (player choices, session state, night queue): $5–15/month
- WebSocket via API Gateway: $3–8/month

---

## Scaling Path

```
Phase 1 (0–500 DAU): Lambda + Qdrant Cloud + Claude Haiku + DynamoDB + Cognito
    → Master Enforcer on Lambda (cold start acceptable at this scale)
    → Prompt caching active from Day 1 (no incremental cost to enable)
    → Full choice log in DynamoDB from Day 1 (retroactive traceability)
    → Monthly cost: ~$118–400

Phase 2 (500–5K DAU): Add Fargate for Master Enforcer + Nakama for auth/social
    → Warm enforcer eliminates validation latency spikes
    → Self-host Qdrant on $25/month VPS (replaces $150–200/month managed)
    → Nakama added: auth, leaderboards, session management
    → Monthly cost: ~$400–1,200

Phase 3 (5K–50K DAU): Model routing + regional distribution
    → NPC Behavior Agent → rule engine + Haiku for flavor-only output
    → Story Progression + Horror Agent remain on Haiku (cached)
    → Regional Lambda for latency (EU, APAC)
    → Qdrant Kubernetes cluster (EKS or self-managed)
    → Monthly cost: ~$1,500–5,000
    → Consider fine-tuned model on Hollow Township tone/lore corpus at Phase 3+
```

---

## Godot 4 Integration

### Communication Pattern

```gdscript
# Day phase — discrete decision points
await http_client.request(HTTPClient.METHOD_POST, "/choice", headers, payload)

# Day → Night transition — triggers pre-computation
await http_client.request(HTTPClient.METHOD_POST, "/transition/night", headers, payload)
# Godot plays transition animation while backend computes

# Night phase — open WebSocket at transition
websocket.connect_to_url("wss://api.hollowtownship.com/night-feed")
websocket.poll()  # called in _process() during night phase only
# Backend pushes pre-computed events over this connection

# Dawn phase — close WebSocket, resume REST
websocket.close()
```

### State Sync Rules

- Never send full world state. Send deltas only.
- Compress all payloads with gzip. Budget: < 4KB per payload.
- Client is always the rendering layer. Backend is always the consequence layer.
- If Godot and backend state diverge, backend wins. Client re-syncs on next REST call.

### Consequence Feedback Loop

```
Player places building (Godot)
    → POST /choice { type: "micro", npc_id: "sarah", action: "assigned_north_post" }
    ← 200 OK (acknowledged; DynamoDB write in flight)
    ← WebSocket push at Night 1: { event: "sarah_exposed", cause: "north_post_assignment" }
Godot renders: "Sarah shivers at the northern wall she was assigned to watch."
```

The player does not see "micro choice recorded." They see Sarah. They made the connection already.

---

## References

- GENEVA (Microsoft Research): microsoft.com/en-us/research/blog/geneva-uses-large-language-models
- PANGeA: arxiv.org/abs/2404.19721
- LIGS: dl.acm.org/doi/10.1145/3706599.3720212
- Emotional Arc Guided Procedural Generation: arxiv.org/html/2508.02132
- LLM-Driven Agent Narratives: arxiv.org/html/2512.20550
- Story2Game: Causal narrative construction: arxiv.org/pdf/2311.09213
- Claude Prompt Caching Docs: docs.anthropic.com/en/docs/build-with-claude/prompt-caching
- Godot 4 WebSocket Docs: docs.godotengine.org/en/stable/tutorials/networking/websocket.html
- Heroic Labs Nakama: heroiclabs.com/nakama
- Qdrant Cloud Pricing: qdrant.tech/pricing
- AWS Lambda vs ECS Fargate: mkdev.me/posts/processing-background-jobs-on-aws-lambda-vs-ecs-vs-ecs-fargate
- Quantic Foundry player sentiment on AI: quanticfoundry.com/2025/12/18/gen-ai/
