extends Node

# All quest definitions as nested GDScript dicts.
# Accessed globally via quest_data.get_quest(quest_id).
#
# Schema fields (per-quest dict):
#   type         : String  - "kill" | "fetch" | "reach_floor" | "story_chain"
#   display_name : String  - Human-readable quest title shown in quest log
#   npc_id       : String  - NPC to return to for completion
#   reward_gold  : int     - Gold awarded on complete_quest()
#   reward_item  : String  - item_id added to global.items ("" = none)
#   reward_unlock: String  - unlock_id set in global.unlocks ("" = none)
#
# Type-specific fields:
#   kill         : target_type (String), required (int)
#   fetch        : item_id (String)
#   reach_floor  : target_floor (int)
#   story_chain  : npc_sequence (Array[String])

const QUESTS := {
	"kill_melee_10": {
		"type": "kill",
		"display_name": "Dungeon Cleanse",
		"target_type": "melee",
		"required": 10,
		"reward_gold": 500,
		"reward_item": "",
		"reward_unlock": "",
		"npc_id": "blacksmith",
	},
	"fetch_ancient_relic": {
		"type": "fetch",
		"display_name": "Lost Relic",
		"item_id": "ancient_relic_fragment",
		"reward_gold": 300,
		"reward_item": "",
		"reward_unlock": "",
		"npc_id": "elder",
	},
	"reach_floor_10": {
		"type": "reach_floor",
		"display_name": "Into the Deep",
		"target_floor": 10,
		"reward_gold": 400,
		"reward_item": "",
		"reward_unlock": "cliff_secret_door",
		"npc_id": "elder",
	},
	"story_chain": {
		"type": "story_chain",
		"display_name": "The Lost Fragment",
		"npc_sequence": ["elder", "blacksmith", "dungeon_merchant"],
		"reward_gold": 1000,
		"reward_item": "ancient_map_fragment",
		"reward_unlock": "cliff_secret_door",
		"npc_id": "dungeon_merchant",
	},
}

func get_quest(qid: String) -> Dictionary:
	return QUESTS.get(qid, {})
