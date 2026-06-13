extends Node3D
## Main.gd — root of the slice. Instantiates the world + UI + camera + systems,
## prints the opening scene to the log, and starts the clock.
##
## Wiring summary (the loop, end to end):
##   GameState (autoload)   — session state, choice log, NPCs, factions, zones
##   TimeManager (autoload) — Day -> Dusk -> Night -> Dawn phase clock
##   EventBus (autoload)    — global signals connecting everything
##   GameDirector (child)   — runs Gossip + NightDirector at night, Significance +
##                            ConsequenceThread at dawn (mirrors backend SessionEngine)
##   Township (child)       — zones, NPCs, building placement
##   GameUI (child)         — build menu, NPC/faction panels, narrative log, dawn thread


func _ready() -> void:
	_opening_scene()
	# Start the clock after a beat so the opening lines land first.
	await get_tree().create_timer(0.5).timeout
	TimeManager.start()


func _opening_scene() -> void:
	# WORLD_STATE §6 — what the player sees at Hour 0:00. The UI shows the Day banner;
	# the handover note is logged to stdout for the prototype (no recap screen — NOT-THIS).
	print("Harrow's Crossing. Morning. The mill is running.")
	print("The handover ledger is on the table. Fourteen names. 'see to the structure first.'")
	print("First decision: where Peder's crew works today. Click an NPC to begin.")
