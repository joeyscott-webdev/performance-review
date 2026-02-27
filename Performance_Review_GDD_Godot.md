# Performance Review

## Technical Game Design Document (Godot 4.x - GDScript)

Generated: 2026-02-27

------------------------------------------------------------------------

# 1. Project Overview

**Genre:** Psychological Horror\
**Perspective:** First-Person\
**Engine:** Godot 4.x\
**Language:** GDScript\
**Scope:** 30--90 minute narrative loop experience\
**Core Mechanic:** Repeating performance review sessions with escalating
distortion

Player is silent. Manager is fully voiced.

------------------------------------------------------------------------

# 2. Core Architecture

## 2.1 Scene Structure

res:// - main.tscn - scenes/ - office.tscn - ui_document.tscn -
ui_dialogue.tscn - scripts/ - game_state.gd - dialogue_manager.gd -
loop_manager.gd - corruption_manager.gd - document_system.gd - data/ -
dialogue.json - mutations.json - audio/ - manager_voice/

------------------------------------------------------------------------

# 3. Singleton Autoload

Create `GameState` as an Autoload singleton.

## game_state.gd

Tracks:

-   loop_count: int
-   compliance_score: float (0.0--1.0)
-   resistance_score: float (0.0--1.0)
-   corruption_tier: int
-   flags: Dictionary
-   ending_unlocked: String

Responsibilities:

-   Reset loop
-   Update metrics
-   Calculate corruption tier
-   Store persistent meta progression

------------------------------------------------------------------------

# 4. Loop System

## loop_manager.gd

Flow:

1.  Load office scene
2.  Trigger intro dialogue
3.  Enable document interaction
4.  Enable dialogue phase
5.  Trigger signature event
6.  Call GameState.advance_loop()
7.  Reload scene

No randomness. All mutations state-driven.

------------------------------------------------------------------------

# 5. Dialogue System (Data-Driven)

## dialogue.json Example

{ "manager_intro": { "base": "Let's begin your annual review.",
"variants": \[ { "condition": "loop_count \>= 2", "text": "Let's begin
again." }, { "condition": "compliance_score \< 0.3", "text": "You seem
hesitant." } \] } }

## dialogue_manager.gd Responsibilities

-   Load JSON at runtime
-   Evaluate condition strings safely
-   Return correct dialogue line
-   Emit signal when dialogue finishes
-   Play associated audio file

------------------------------------------------------------------------

# 6. Condition Evaluation

Avoid eval().

Instead: - Parse known keys (loop_count, compliance_score,
corruption_tier) - Use small expression parser - OR predefine condition
types: - LOOP_GTE - COMPLIANCE_LT - FLAG_TRUE

------------------------------------------------------------------------

# 7. Compliance System

Increase compliance when: - Player agrees - Signs quickly - Avoids
confrontation

Decrease compliance when: - Delays - Questions rating - Refuses
signature

Clamp between 0.0 and 1.0.

------------------------------------------------------------------------

# 8. Corruption Tier System

Recalculated each loop:

corruption_tier = min(loop_count + int(resistance_score \* 3), 6)

Tiers trigger:

0 = normal\
1 = light flicker\
2 = dialogue shift\
3 = prop movement\
4 = document mutation\
5 = exit disappears\
6 = heavy distortion

------------------------------------------------------------------------

# 9. Environment Mutation

## corruption_manager.gd

Each tier activates:

-   Lighting changes
-   Audio layers
-   Object transforms
-   Material overrides

Use exported NodePaths for easy setup.

------------------------------------------------------------------------

# 10. Document System

## ui_document.tscn

Features:

-   ScrollContainer
-   RichTextLabel (BBCode enabled)
-   Signature Button

Text dynamically replaced via:

document_system.gd

Support word substitution based on corruption tier.

------------------------------------------------------------------------

# 11. Audio System

Use AudioStreamPlayer nodes.

Manager voice variants:

-   normal
-   disappointed
-   distorted
-   glitched

Select variant based on corruption tier.

Ambient layers added progressively.

------------------------------------------------------------------------

# 12. Ending System

Triggered when:

-   corruption_tier reaches threshold
-   compliance_score extreme values
-   hidden flag activated

Endings:

-   COMPLIANT
-   PROMOTED
-   TERMINATED
-   SELF_REALIZATION
-   SYSTEM_FAILURE

------------------------------------------------------------------------

# 13. Save System

Use:

FileAccess.open("user://save_data.json", FileAccess.WRITE)

Two layers:

Runtime Save: - current loop - scores - flags

Meta Save: - endings unlocked - total playthroughs

------------------------------------------------------------------------

# 14. MVP Requirements

Minimum viable build includes:

-   3 loops
-   3 corruption tiers
-   1 ending
-   Working dialogue system
-   Working document UI
-   Compliance tracking

------------------------------------------------------------------------

# 15. Implementation Order

1.  GameState singleton
2.  Basic office scene
3.  Dialogue system
4.  Document UI
5.  Loop reset system
6.  Compliance tracking
7.  Corruption tier effects
8.  Audio layering
9.  Ending triggers
10. Save system

------------------------------------------------------------------------

# 16. Design Rules

-   No hardcoded dialogue
-   No random procedural logic
-   Fully deterministic escalation
-   Data-driven branching
-   Modular systems

------------------------------------------------------------------------

End of Technical GDD
