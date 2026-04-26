# Backend Architecture — Hollow Township

> Status: IN PROGRESS (foundation decided, service selection pending final stack lock).
> All decisions here must serve `PILLARS.md`. Infra exists to enable earned dread, not general-purpose game hosting.

---

## Design Constraints Driving Architecture

From the frozen design pillars:

- **Night outcomes shaped by Day choices** (Pillar 4) → player state must persist reliably between day/night cycles; no event can be random
- **The Watched Feeling** (Pillar 2) → NPC behavior must have memory across sessions, not just the current session
- **Moral Weight at Every Turn** (Pillar 3) → consequence tracing requires a log of player micro choices, queryable at any point
- **Earned Dread** (Pillar 1) → horror generation is not content delivery; it is consequence computation

The backend is a **moral consequence engine**, not a content delivery system.

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
          ┌──────────┼──────────┐
          ▼          ▼          ▼
┌──────────────┐ ┌──────────────┐
│  CREATURE /  │ │  CONSEQUENCE │
│  HORROR      │ │  TRACE AGENT │
│  AGENT       │ │  audit log   │
│  night phase │ │  traceability│
└──────────────┘ └──────────────┘
```

### Agent Responsibilities

| Agent | Trigger | State | Cost Class |
|-------|---------|-------|------------|
| Master Design Enforcer | All LLM outputs | Warm singleton | Medium — always on |
| Story Progression | Player decision point | Dormant, per-player | High — LLM inference |
| NPC Behavior | Day cycle tick, faction event | Dormant, shared templates | Low — mostly rule-based |
| Character Arc | Session boundary, significant event | Vector DB backed | Low — retrieval-heavy |
| Creature/Horror | Night cycle, shaped by day state | Dormant, per-player | Medium — constrained generation |
| Consequence Trace | All micro/mid/macro choices | Write-only log | Negligible — audit only |

### Why a Master Enforcer Agent Exists

Without it, LLM-generated content drifts. At 32 inference calls per session, even a 5% pillar-violation rate means 1.6 violating outputs per play session. The enforcer intercepts all Story Progression and Horror outputs, validates against the five pillars, and retries on failure. Retry rate target: under 2%. Cost of retry: 2× inference cost for ~1% of calls — acceptable.

---

## Dormant Agent Pattern (Core Infra Model)

```
Player Action in Godot
        │
        ▼
   REST / WebSocket
        │
        ▼
  API Gateway → SQS Queue
        │
        ▼
  Lambda (wakes on event)
    - Retrieves player state from DynamoDB
    - Retrieves relevant NPC memories from Qdrant (vector search)
    - Builds LLM context: last 3 scenes + current player state (~1,500 tokens)
    - Calls Claude Haiku (inference)
    - Output → Master Enforcer validation
    - Writes consequence to Consequence Log
    - Updates DynamoDB player state
    - Returns narrative delta to Godot
        │
        ▼
  Godot renders consequence
```

Cold start latency: 200–500ms. Acceptable for decision-point narrative (not real-time combat). If night phase requires near-real-time response, pre-warm the Lambda for the duration of the night cycle.

---

## Memory Architecture

### Why This Matters for This Game

"The Watched Feeling" requires the system to remember what a player did on Day 1 when rendering consequences on Night 3. Standard LLM context windows cannot hold 4 hours of gameplay state (it would be 50K+ tokens and cost ~$1.25/request).

### Three-Tier Memory Model

```
HOT  (in LLM context)    — Last 3 scenes + current player state (~1,500 tokens)
WARM (vector DB)         — Character memories, faction standing, named NPC state
COLD (DynamoDB)          — Full session history, consequence log, all micro choices
```

- **Hot tier**: Built fresh per inference call. Small. Fast. Cheap.
- **Warm tier**: Qdrant vector search retrieves 2–5 most relevant memories per call ("What does the Priest remember about the player?" returns the 3 most relevant entries). Enables the "Watched Feeling" without reading the full log.
- **Cold tier**: Complete audit trail. Queried rarely (session load, chapter end, debugging). Cheap storage.

---

## Cost Model

### Per-Session Estimate

```
4-hour session, ~24 decision points (1 per 10 min), 2 inference calls per decision
(Story Progression + Master Enforcer validation)

Input per call:  ~1,500 tokens
Output per call: ~300 tokens

Claude Haiku pricing (Apr 2026): $0.25/1M input, $1.25/1M output

Cost per call: ($0.25 × 1.5K / 1M) + ($1.25 × 0.3K / 1M) = $0.000375 + $0.000375 = ~$0.00075
Cost per session (48 calls): ~$0.036
```

**LLM cost per player session: ~$0.04** (less than 4 cents).

### Monthly Infrastructure Cost by Scale

| Tier | DAU | Concurrent Peak | Monthly LLM | Monthly Infra | Monthly Total | Per DAU |
|------|-----|-----------------|-------------|---------------|---------------|---------|
| Indie | 100 | 20–30 | ~$120 | ~$100 | **~$220** | $2.20 |
| Early Access | 1,000 | 150–200 | ~$1,200 | ~$400 | **~$1,600** | $1.60 |
| Growth | 10,000 | 1,500–2,000 | ~$4,800 | ~$1,500 | **~$6,300** | $0.63 |

Infrastructure breakdown (indie scale):
- Lambda + SQS: $10–20/month
- ECS Fargate (Master Enforcer, 0.5vCPU): $20–30/month
- Qdrant Cloud (NPC memory): $25–50/month
- DynamoDB (player state): $5–10/month
- API Gateway: $2–5/month

### Cost Reduction Levers

1. **Claude Prompt Caching**: System prompt (design pillars, world state) is identical across all calls. Cache it at 10× savings. Reduces effective LLM cost to ~$0.004/session.
2. **Model downgrade for NPC behavior**: Haiku or rule-based logic for low-stakes NPC interactions (not story-critical path). NPC behavior agent rarely needs full LLM inference.
3. **Batch night-cycle computation**: Night phase events can be computed in batch at day→night transition (not per-click), reducing call frequency.
4. **Self-hosted Qdrant at 1K+ DAU**: Qdrant on a $25/month VPS replaces $150–200/month managed cluster.

---

## Godot 4 Integration

### Communication Pattern

**Decision points (turn-based narrative)**: REST via Godot `HTTPClient`.
```
await http_client.request(HTTPClient.METHOD_POST, "/narrative/advance", headers, payload)
```

**Night cycle events (near-real-time)**: WebSocket for bidirectional event streaming.
```
websocket.connect_to_url("wss://api.hollowtownship.com/night-feed")
websocket.poll()  # called in _process()
```

**State sync**: Never send full world state. Send deltas only. Compress with gzip. Payload budget: under 4KB per call.

### Consequence Feedback Loop (Godot ↔ Backend)

```
Player places building (Godot)
    → POST /choice { type: "micro", npc_id: "sarah", action: "assigned_north_post" }
    ← 200 OK (acknowledged, consequence scheduled)
    ← WebSocket push on Night 1: { event: "sarah_exposed", cause: "north_post_assignment" }
Godot renders: "Sarah shivers at the northern wall she was assigned to watch."
```

The player does not see "micro choice recorded." They see Sarah. They made the connection already.

---

## Scaling Path

```
Phase 1 (0–500 DAU): Lambda + Qdrant Cloud + Claude Haiku + DynamoDB
    → No ops overhead, minimal cost (~$220–800/month)
    → No container management

Phase 2 (500–5K DAU): Add dedicated Fargate for Master Enforcer
    → Warm enforcer avoids cold-start validation delays
    → Self-host Qdrant on $25/month VPS
    → Enable Claude prompt caching (10× LLM cost reduction)

Phase 3 (5K–50K DAU): Switch to lighter model for non-story calls
    → NPC behavior → rule engine + Haiku flavor-only
    → Regional Lambda deployment for latency
    → Qdrant Kubernetes cluster (EKS or self-managed)
    → Consider fine-tuned model on Hollow Township's tone/lore
```

---

## Decisions Pending

- Final model selection: Claude Haiku vs. GPT-4o-mini vs. Gemini 2.5 Flash at launch (all within $0.05/session budget)
- WebSocket vs. REST for night phase (depends on how real-time night horror needs to feel)
- Whether Consequence Trace Agent is a dedicated service or a DynamoDB write in the Lambda function (latter is simpler, sufficient for indie scale)
- Nakama (Heroic Labs) evaluation: handles auth, leaderboards, social. Adds $25–100/month but removes significant backend boilerplate.

---

## References

- Emotional Arc Guided Procedural Generation — arxiv.org/html/2508.02132
- LLM-Driven Agent Narratives — arxiv.org/html/2512.20550
- GENEVA: Branching Narrative Generation — arxiv.org/pdf/2311.09213
- Godot 4 WebSocket Docs — docs.godotengine.org/en/stable/tutorials/networking/websocket.html
- Heroic Labs Nakama — heroiclabs.com/nakama
- Qdrant Cloud Pricing — qdrant.tech/pricing
- AWS Lambda vs ECS Fargate — mkdev.me/posts/processing-background-jobs-on-aws-lambda-vs-ecs-vs-ecs-fargate
