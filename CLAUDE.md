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
| `design/ARCHITECTURE.md` | Backend agent architecture + infra + cost model | IN PROGRESS |
| `design/TONE.md` | Aesthetic/mood bible (3+3+3 rule) | PENDING |
| `design/NOT-THIS.md` | Explicit exclusions — what this game is not | PENDING |

## Working Branch

`claude/horror-rpg-design-1vuLY`

## Session Rules for Claude

- Refer to frozen docs before answering any design question.
- Tag every proposal with which pillar it satisfies.
- If a proposal violates a pillar, say so and stop.
- Keep documentation current — every frozen decision gets written to `/design/`.
- Manage token/memory efficiency: write decisions to files, reference files, do not re-explain frozen decisions inline.
