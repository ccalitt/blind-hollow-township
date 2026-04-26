# Hollow Township — Project Instructions

## What This Is

A Horror + Simulation + Drama RPG. Working title: **Hollow Township**.

PC-first (Steam Early Access) → web prototype → mobile port. Engine: Godot 4 (GDScript).

## Philosophy Lock

**The concept is frozen before mechanics, assets, or code.**
All design decisions flow from the pillars in `/design/PILLARS.md`.
Do not propose gameplay depth, mechanics, or assets unless pillars are satisfied first.

## Core Emotional Nucleus

> *Every right choice arrives already compromised.*

Named: **Earned Dread**. This is the game's soul. Every feature must serve it or be cut.

## Design Documents (Source of Truth)

| File | Contents | Status |
|------|----------|--------|
| `design/PILLARS.md` | Five frozen design pillars with kills/enables | FROZEN |
| `design/CONCEPT.md` | Logline, emotional loop, genre position, day/night structure | FROZEN |
| `design/CHAPTER_ONE.md` | Chapter 1 beat structure + moral choice weight system | FROZEN |
| `design/ARCHITECTURE.md` | Backend agent architecture + infra + cost model | FROZEN |
| `design/TONE.md` | Aesthetic/mood bible (3+3+3 rule) | FROZEN |
| `design/NOT-THIS.md` | Explicit exclusions — what this game is not | FROZEN |
| `design/GRAPHICS.md` | Visual system, TPS/top-down view, art direction, asset pipeline | IN PROGRESS |
| `design/WORLD_STATE.md` | Township name, NPCs, factions, horror nature, map, opening scene | FROZEN |
| `design/REVEAL_MECHANIC.md` | How causal connections surface to the player (dawn thread model) | FROZEN |
| `design/INTERACTION_MODEL.md` | Player cursor, building, NPC assignment, faction UI | FROZEN |
| `design/CRITICAL_GAPS_PLAN.md` | Resolution plan for all critical review gaps | RESOLVED — Gap 9 (sprite readability) is a prototype gate, not a doc |
| `design/NIGHT_SURVIVAL.md` | Creature system, night survival rules, day evolution loop, brutality parameters | IN PROGRESS — pending review |
| `design/WORLD_BACKSTORY.md` | Trap mythology, NPC arrival backstories, inflow mechanic, escape theories, FROM-inspired layer | IN PROGRESS — pending review |
| `design/TIME_SYSTEM.md` | Day/night/season timer logic, Godot implementation, GoT-inspired debt-driven seasonal clock | IN PROGRESS — pending review |
| `design/NPC_INFLOW_PRODUCTIVITY.md` | Fallout Shelter-inspired NPC skill matching, settling curves, bonding, silver lining productivity system | IN PROGRESS — pending review |

## Working Branch

`claude/horror-rpg-design-1vuLY`

## Session Rules for Claude

- Refer to frozen docs before answering any design question.
- Tag every proposal with which pillar it satisfies.
- If a proposal violates a pillar, say so and stop.
- Keep documentation current — every frozen decision gets written to `/design/`.
- Manage token/memory efficiency: write decisions to files, reference files, do not re-explain frozen decisions inline.
