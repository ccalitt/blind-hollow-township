# Concept Document — Hollow Township

> Status: FROZEN. Logline, emotional loop, genre position, and structural mechanics.

---

## Logline

A township survival RPG where every act of building is an act of complicity — and the night always knows what you built it for.

---

## Working Title

**Hollow Township**

---

## Core Emotional Nucleus

> *Every right choice arrives already compromised.*

Named: **Earned Dread**.

The player is never the villain. The player is never the hero. The player is someone who keeps making reasonable decisions inside an unreasonable system — and the accumulation of reasonable decisions is what creates the horror.

---

## Target Audience

- Primary: Players who finished Frostpunk and wanted it darker and more personal
- Secondary: This War of Mine players who wanted more systemic depth
- Tertiary: Disco Elysium players who wanted their choices to have physical, spatial consequence

**Age range**: 18–35. Platform fluency: PC-native.

---

## Genre Position

| Genre | This Game | Why |
|-------|-----------|-----|
| Horror | Strong | Night phase is genuinely dangerous; horror traced to player choices |
| Simulation | Strong | Day phase builds real systems with real downstream consequences |
| Narrative Drama | Strong | Named NPCs with arcs; faction politics; moral weight at every turn |

No competitor currently occupies all three at full strength. See `PILLARS.md` Pillar 5.

---

## The Three-Beat Engagement Loop

```
RELIEF      →      UNEASE      →      COMPULSION
(Day Phase)       (Night Phase)       (Dawn Phase)

Build.            What you built      Return. Again.
Manage.           watches you back.   Despite knowing.
Progress.         Something is wrong. Especially because you know.
```

This loop must complete at least once per play session. In Chapter 1 it completes first at approximately the end of Night 1 (hour 0:30–1:00).

---

## Day / Night Structural Mechanics

### Day Phase (Relief)
- Building placement and township management
- Political negotiation with factions
- Narrative drama between named NPCs
- Resource allocation (secretly moral choices in logistics disguise)
- Tone: tense hope, not safety

### Night Phase (Unease)
- Horror events triggered and shaped by Day choices
- Corruption systems spreading through structures built during the day
- Named NPCs threatened by the consequences of day decisions
- Survival mechanics in reactive, not random, horror
- Tone: dread, not panic

### Dawn Phase (Compulsion)
- Survey what the night changed
- Face the cost of yesterday's reasonable decisions
- Be given a clear path forward — that is already compromised
- Tone: can't stop, won't stop, shouldn't continue, will continue

**Critical Rule**: Night outcomes are shaped by Day choices. This is non-negotiable. Random night horror breaks the Watched Feeling (Pillar 2) and removes Earned Dread (Pillar 1).

---

## Platform Strategy

- **Engine**: Godot 4 (GDScript)
- **Launch target**: Steam Early Access (Chapter 1 as a paid chapter, not a free demo)
- **Framing**: Early Access Chapter 1, not prologue/demo — prologue trick effectiveness declined post-2024 Steam algorithm changes
- **Platform sequence**: PC (Steam) → web prototype → mobile port
- **Wishlist conversion benchmark**: 0.15x median (varies by order of magnitude at this genre intersection)

---

## What Success Looks Like at Chapter 1

The player finishes Chapter 1 and:
1. Cannot immediately articulate all the choices that led to the ending they got
2. Wants to replay — not to "win" but to see what would have changed
3. Feels complicit, not victimized
4. Is already dreading Day 1 of Chapter 2

If the player feels satisfied, we failed. The target emotion at chapter end is: **unresolved compulsion**.

---

## Cross-Chapter Retention Architecture

The RELIEF → UNEASE → COMPULSION loop is designed to complete within a single session. That architecture is correct. The gap it does not address: across sessions and chapters, the loop has no designed reentry point. A player returning for Chapter 2 arrives in the same emotional register Chapter 1 ended in — unresolved, implicated, dreading — with no earned breath before the next accumulation begins. Without a designed return to RELIEF at chapter start, every chapter opens at UNEASE. The dread stops being earned and starts being ambient. That is a different game, and a worse one.

The fix is structural, not tonal. It is called the **False Dawn** model.

Chapter 2 opens with one specific, traceable positive outcome from Chapter 1. Something the player could not be certain would survive — that survived. This is the anchor. It is not a cutscene reassurance or a fabricated good news beat. It is a real consequence of what the player chose. The relief is genuine because the player knows they are responsible for it.

The anchor is not arbitrary. It is the NPC with the highest player-investment signal from Chapter 1: the one the player directed the most choices toward protecting. This is not interpretation — it is computable from the choice log. The player made their attachment legible through their decisions. The system reads it back.

The relief is brief and conditional. Within 15–20 minutes of Chapter 2, the survival is complicated. Not reversed — the thing still made it. But a deferred cost surfaces. The thing that survived is now in a new kind of danger because it survived. The player's protection did not prevent the cost. It rerouted it.

This is *Every right choice arrives already compromised* — applied at chapter scale. The player chose to protect this person. That choice was right. The cost of it being right is what Chapter 2 is about.

The model scales forward. Chapter 3's anchor is the thing Chapter 2 made possible. The dread compounds through accumulated attachment, not through escalating spectacle. Each chapter earns its horror from the one before it. The player carries the weight themselves.
