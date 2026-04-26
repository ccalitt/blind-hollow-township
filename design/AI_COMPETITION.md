# AI Generative & Procedural Game Competition — Hollow Township

> Research date: April 2026. Covers shipped games, funded studios, state of the art, failure modes, and player sentiment.

---

## Key Finding Upfront

**No major shipped game currently uses real-time LLM-driven narrative generation as a disclosed core mechanic.** The field is active in academic research and VC-funded asset pipelines, but the specific intersection Hollow Township is building — moral choice computation → procedural horror consequence — is unoccupied in the market.

---

## 1. Games Using AI Narrative Generation in Production

### What Actually Ships

| Game | AI Use | Status | Notes |
|------|--------|--------|-------|
| NVIDIA/Inworld Covert Protocol | LLM-driven NPC personalities, conversational memory | Demo only (GDC 2024) | Not a shipped product |
| Hidden Door (Alice in Wonderland RPG) | AI narrator, generative story | Pre-launch | One of few explicitly building narrative gen as core feature |
| AI People (GoodAI) | Autonomous AI NPCs in sandbox | Shipped | Reviews focus on novelty, not narrative coherence |
| No Man's Sky | Procedural world/quest gen (non-LLM) | Shipped | Players don't perceive AI — it's infrastructure |
| Dwarf Fortress | Deep simulation procedural narrative | Shipped | No LLM; emergent narrative through simulation rules |

**Conclusion**: No shipped commercial game has successfully deployed real-time LLM narrative generation as the primary storytelling engine. Hollow Township would be among the first.

### Why the Gap Exists

Research consistently shows: human-authored narratives outpace LLM output in emotional nuance, genre consistency, and coherence. LLMs confuse tone, produce overly positive resolutions, and fail on genre-specific constraints. The field is moving from "can we generate text?" to "can we ensure logical consistency and emotional arc?" — that second problem is not yet solved at quality parity with authored content.

---

## 2. AI Game Studios and Investment (2024–2026)

**~$1.8B in VC funding** has flowed into gaming × AI startups (2020–2024), accelerating to $1.2–1.5B in 2024–2025 venture rounds alone.

**Critical distribution**: 65% of deal value targets **asset and content production** (art, audio, 3D models, level generation) for live-service F2P games. Real-time narrative generation receives a small fraction of this investment.

| Studio | Focus | Investment |
|--------|-------|------------|
| Kaedim | 3D model generation, asset pipelines | $15M Series A (a16z) |
| Parametrix AI | Procedural narrative and environment gen | Undisclosed |
| Sortium | AI-first game development | $4M+ seed |
| Inworld AI | NPC dialogue and personality systems | $120M+ total |

**Implication for Hollow Township**: The VC market is betting on AI for production efficiency (cheaper assets faster), not for player-facing real-time narrative. This means the player-facing narrative generation space has less competition than the funding numbers suggest — but also less proven market validation.

---

## 3. State of the Art: Procedural Narrative Generation

### Academic Systems

| System | Approach | Relevance to Hollow Township |
|--------|----------|-------------------------------|
| GENEVA (Microsoft Research) | GPT-4o-mini generates branching narrative as directed acyclic graphs with emotional arc guidance | Direct reference for story branching architecture |
| PANGeA | Personality-biased NPC generation using Big Five framework | NPC Behavior Agent design |
| LIGS (LLM-Integrated Game System) | Players describe actions in natural language; LLM determines NPC response and story outcome | Closest to our architecture pattern |
| Story2Game | Iterative story construction ensuring causal logic | Consequence Trace Agent design |

### What's Improving

- Causal logic preservation across generated scenes
- Character intentionality and goal consistency
- Emotional arc modeling (not just mood, but arc structure: tension → release → new tension)
- Small Language Models (SLMs) at quality parity with LLMs for short, contextually-clear content — significant cost implication

### What's Still Broken

- Genre-specific constraint adherence (horror generators drift into comedy or incoherence without hard constraint)
- LLM bias toward positive resolution — needs active counter-forcing for horror/dread tone
- "Player can't tell the difference" — not yet the norm; authored content still has the edge on emotional nuance
- Dynamic game use of SLMs remains unexplored despite theoretical promise

---

## 4. Failure Modes and Backlash (What to Avoid)

### Immersion Failures
- **Latency**: Unoptimized cloud LLM inference introduces 800–1,200ms delays. In a horror game, 800ms between a player action and a horror response breaks the atmosphere entirely. This is non-negotiable to solve.
- **Tone drift**: Horror narrative generators produce off-tone results without hard genre constraints. LLMs will generate "quirky" horror if not aggressively constrained.
- **Repetition**: Without memory architecture, players encounter the same generated responses. Breaks the "Watched Feeling" instantly.

### Design Failures
- **Hollow narrative**: Over-reliance on procedural content produces text that lacks authored emotional depth. "Procedurally unique" is not the same as "meaningfully different."
- **Random-feeling consequences**: If players perceive night horror as arbitrary rather than consequential, the moral weight system collapses. The causal chain must be visible enough to feel earned — even if the exact form surprises them.

### Backlash Cases
- **Crimson Desert** (2024–2025): AI-content scandal damaged credibility and press coverage.
- **Baldur's Gate 3, Jurassic World Evolution 3, Little Droid**: Player backlash on disclosure of AI-generated assets forced rollbacks or public apologies.
- **Pattern**: Backlash hits hardest when AI replaces *authored care* that players expected. It does not hit as hard when AI generates variety within a constrained system (No Man's Sky, Dwarf Fortress are not criticized for procedural content).

---

## 5. Player Sentiment

**The numbers are stark.**

- 85% of players hold negative views of generative AI in games
- 63% select "very negative" in surveys
- Sentiment has worsened: AI-generated quest/dialogue negativity rose from 46% (Q2–Q4 2024) to 77–83% (current)
- Female and non-binary players are 25–30% more likely to select the most negative option
- Despite this: 50% of game studios now use AI in production, up from negligible in early 2024

**Key nuance**: Players don't object to procedural systems abstractly. They object to *disclosed* AI generation when it replaces authored content. Hidden procedural systems (Dwarf Fortress, No Man's Sky) don't trigger backlash because players don't perceive the trade-off as "less human care." The objection is to *substitution*, not *generation*.

---

## 6. Implications for Hollow Township

### What the Backend AI Is and Isn't

The AI-agent backend is **not the product**. The product is the experience of earning dread. The AI agents are infrastructure for making player consequences feel real and unique.

Frame it that way internally. Do not build features that require the AI to be impressive — build features that require the *consequences* to feel earned.

### Positioning Strategy

**Do not lead with "AI-generated narrative."** Lead with:
- "Your choices shape what hunts you tonight"
- "Every player's township decays differently"
- "The game remembers what you built"

The AI is invisible infrastructure. Exactly like No Man's Sky and Dwarf Fortress — the system is sophisticated, the player experience is "this world feels alive."

**If disclosure becomes necessary** (press, Steam description): frame as "dynamic AI agents compute how your choices propagate through the township." Technologically accurate, human-framing, not "AI replaces writers."

### What Must Be Right for This to Work

1. **Latency under 300ms** for narrative responses. Pre-compute night-phase events at day→night transition, not on-click. The horror response cannot feel like a loading screen.
2. **Constraint-based generation enforced by Master Enforcer Agent** — horror tone, character arc consistency, pillar compliance — on every single output. No exceptions.
3. **Consequence authenticity** — players must be able to trace night horror back to their day choices. If it feels random, the entire value proposition collapses.
4. **Session memory persistence** — what the player did on Day 1 must be retrievable and relevant on Night 3. No amnesia. This is the technical embodiment of The Watched Feeling.
5. **Quality bar above "procedural"** — the generated content must feel authored. The test: would a playtester assume this was written by a human writer who understood the character? If not, rewrite the constraints.

### Competitive Position

You are not competing against other AI narrative games. There are none at this quality level. You are competing against the player *expectation* that AI narrative is hollow, based on their prior experiences with Crimson Desert, BG3 asset controversy, and low-quality AI games. If you execute on quality, latency, and earned consequence — you break that expectation. That is the launch story.

---

## References

- GENEVA (Microsoft Research): microsoft.com/en-us/research/blog/geneva-uses-large-language-models
- PANGeA: arxiv.org/abs/2404.19721
- LIGS: dl.acm.org/doi/10.1145/3706599.3720212
- Quantic Foundry player sentiment study: quanticfoundry.com/2025/12/18/gen-ai/
- AI backlash cases: aiandgames.com/p/when-generative-ai-backlash-dominates
- Crimson Desert AI scandal: gamespot.com/articles/crimson-deserts-ai-scandal-should-bother-you-more
- VC investment data: investgame.net/news/ai-s-ever-growing-presence-in-gaming-1-8b-in-vc-investments
