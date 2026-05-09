extends Node

# All NPC dialogue trees as nested GDScript dicts.
# Accessed globally via dialogue_data.get_dialogue_node(npc_id, node_id).
#
# Schema fields (per-node dict):
#   speaker  : String  - NPC display name shown in panel header
#   text     : String  - Dialogue body text
#   next     : String  - Next node id when advance-only (choices empty); "" closes
#   choices  : Array   - Up to 2 choice dicts: {label, next, action, quest_id}
#                        Empty array = advance-only node (uses `next`).

const DIALOGUES := {
	"elder": {
		"greeting": {
			"speaker": "Elder",
			"text": "Welcome, adventurer. The dungeon grows darker each day.",
			"next": "quest_offer",
			"choices": []
		},
		"quest_offer": {
			"speaker": "Elder",
			"text": "Will you venture to floor 10 for me? The answers I seek lie in its depths.",
			"next": "",
			"choices": [
				{"label": "Accept Quest", "next": "quest_accepted", "action": "quest_offer", "quest_id": "reach_floor_10"},
				{"label": "Decline Quest", "next": "quest_declined", "action": ""}
			]
		},
		"quest_accepted": {
			"speaker": "Elder",
			"text": "Brave soul. Return when you have reached floor 10.",
			"next": "",
			"choices": []
		},
		"quest_declined": {
			"speaker": "Elder",
			"text": "Perhaps another time. I will wait.",
			"next": "",
			"choices": []
		},
		"quest_follow_up": {
			"speaker": "Elder",
			"text": "I remember you. How fare the depths?",
			"next": "",
			"choices": []
		}
	},
	"dungeon_merchant": {
		"greeting": {
			"speaker": "Merchant",
			"text": "Supplies, deep in the dark? You must be serious about going further.",
			"next": "merchant_offer",
			"choices": []
		},
		"merchant_offer": {
			"speaker": "Merchant",
			"text": "I have nothing to sell. But I can tell you this: the creatures below grow stronger after floor 5.",
			"next": "",
			"choices": []
		}
	}
}

func get_dialogue_node(npc_id: String, node_id: String) -> Dictionary:
	if DIALOGUES.has(npc_id) and DIALOGUES[npc_id].has(node_id):
		return DIALOGUES[npc_id][node_id]
	return {}
