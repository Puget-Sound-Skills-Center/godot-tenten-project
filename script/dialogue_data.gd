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
			"next": "",
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
		},
		"fetch_quest_offer": {
			"speaker": "Elder",
			"text": "I lost an Ancient Relic Fragment deep in the dungeon. Will you bring it back?",
			"next": "",
			"choices": [
				{"label": "Accept", "next": "fetch_quest_accepted", "action": "quest_offer", "quest_id": "fetch_ancient_relic"},
				{"label": "Decline", "next": "fetch_quest_declined", "action": ""}
			]
		},
		"fetch_quest_accepted": {
			"speaker": "Elder",
			"text": "Search the dungeon depths. The Fragment will glow faintly when nearby.",
			"next": "",
			"choices": []
		},
		"fetch_quest_declined": {
			"speaker": "Elder",
			"text": "Very well. The Fragment will wait.",
			"next": "",
			"choices": []
		},
		"fetch_quest_complete": {
			"speaker": "Elder",
			"text": "You found it! Take this gold — it's the least I can offer.",
			"next": "",
			"choices": [
				{"label": "(Hand over the Fragment)", "next": "", "action": "quest_complete", "quest_id": "fetch_ancient_relic"}
			]
		},
		"story_chain_offer": {
			"speaker": "Elder",
			"text": "I've lost something precious — an Ancient Map Fragment. The Blacksmith near the forge may know who took it. Will you help me find it?",
			"next": "",
			"choices": [
				{"label": "Accept", "next": "story_chain_accepted", "action": "quest_offer", "quest_id": "story_chain"},
				{"label": "Decline", "next": "story_chain_declined", "action": ""}
			]
		},
		"story_chain_accepted": {
			"speaker": "Elder",
			"text": "Start with the Blacksmith. He knows more than he lets on.",
			"next": "",
			"choices": [
				{"label": "(Set out)", "next": "", "action": "story_chain_advance"}
			]
		},
		"story_chain_reminder": {
			"speaker": "Elder",
			"text": "Find the Blacksmith by the forge. He knows where the Map Fragment went.",
			"next": "",
			"choices": []
		},
		"story_chain_declined": {
			"speaker": "Elder",
			"text": "The Fragment will wait. Return when you are ready.",
			"next": "",
			"choices": []
		},
		"reach_floor_complete": {
			"speaker": "Elder",
			"text": "Floor ten! Few return from there. Here is your reward — and a path opens by the cliffside.",
			"next": "",
			"choices": [
				{"label": "(Accept reward)", "next": "", "action": "quest_complete", "quest_id": "reach_floor_10"}
			]
		},
		"quest_cap_reached": {
			"speaker": "Elder",
			"text": "I have no new quests for you right now.",
			"next": "",
			"choices": []
		},
	},
	"blacksmith": {
		"greeting": {
			"speaker": "Blacksmith",
			"text": "What is it, traveler?",
			"next": "",
			"choices": []
		},
		"kill_quest_offer": {
			"speaker": "Blacksmith",
			"text": "Those melee brutes in the dungeon — clear ten of them and there's gold in it for you.",
			"next": "",
			"choices": [
				{"label": "Accept", "next": "kill_quest_accepted", "action": "quest_offer", "quest_id": "kill_melee_10"},
				{"label": "Decline", "next": "kill_quest_declined", "action": ""}
			]
		},
		"kill_quest_accepted": {
			"speaker": "Blacksmith",
			"text": "Good. Ten melee enemies. Return when it's done.",
			"next": "",
			"choices": []
		},
		"kill_quest_declined": {
			"speaker": "Blacksmith",
			"text": "Suit yourself. The job will be here.",
			"next": "",
			"choices": []
		},
		"kill_quest_complete": {
			"speaker": "Blacksmith",
			"text": "Ten melee down! Here — earned every coin.",
			"next": "",
			"choices": [
				{"label": "(Take the reward)", "next": "", "action": "quest_complete", "quest_id": "kill_melee_10"}
			]
		},
		"kill_quest_followup": {
			"speaker": "Blacksmith",
			"text": "Keep at it. Those brutes won't clear themselves.",
			"next": "",
			"choices": []
		},
		"kill_quest_cap_reached": {
			"speaker": "Blacksmith",
			"text": "I have no new quests for you right now.",
			"next": "",
			"choices": []
		},
		"story_chain_step1": {
			"speaker": "Blacksmith",
			"text": "The Elder's map? Yes, I held it once. But a merchant who wanders the dungeon — he asked to borrow it. You'll find him somewhere in the depths.",
			"next": "",
			"choices": [
				{"label": "(Note the merchant)", "next": "", "action": "story_chain_advance"}
			]
		},
		"story_chain_step1_done": {
			"speaker": "Blacksmith",
			"text": "Find that wandering merchant in the dungeon. He has what the Elder seeks.",
			"next": "",
			"choices": []
		},
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
		},
		"story_chain_step2": {
			"speaker": "Dungeon Merchant",
			"text": "The Elder sent you? I've kept this safe. Here — take the Map Fragment back to him. And tell him the map shows a passage near the cliffside... if one knows where to look.",
			"next": "",
			"choices": [
				{"label": "(Take the Fragment)", "next": "", "action": "quest_complete", "quest_id": "story_chain"}
			]
		},
		"story_chain_complete": {
			"speaker": "Dungeon Merchant",
			"text": "Safe travels, friend.",
			"next": "",
			"choices": []
		}
	},
	"lore_object": {
		"fragment_1": {
			"speaker": "Ancient Inscription",
			"text": "These halls were carved by hands that sought to reach what lies beneath. The first delvers came for treasure. Most did not return.",
			"next": "",
			"choices": []
		},
		"fragment_2": {
			"speaker": "Ancient Inscription",
			"text": "The walls grow older here. Marks of tools give way to marks of claws. Something was already here when the delvers arrived.",
			"next": "",
			"choices": []
		},
		"fragment_3": {
			"speaker": "Crumbling Tablet",
			"text": "Floor thirty-four. The expedition leader recorded: 'We found ruins of a civilization that preceded our own. They built downward, not up. Why?'",
			"next": "",
			"choices": []
		},
		"fragment_4": {
			"speaker": "Crumbling Tablet",
			"text": "The ruins speak of a gate sealed long ago. The builders carved warnings around it in a language no one could read. No one tried to.",
			"next": "",
			"choices": []
		},
		"fragment_5": {
			"speaker": "Worn Journal",
			"text": "Day unknown. The dark here is different — it pushes back. My torch burns but the light does not reach. I can hear something below. I will not go further.",
			"next": "",
			"choices": []
		},
		"fragment_6": {
			"speaker": "Worn Journal",
			"text": "You have reached the deepest point any have recorded. The builders' gate is here. It was not sealed to keep something in. It was sealed to keep us out.",
			"next": "",
			"choices": []
		},
	},
}

func get_dialogue_node(npc_id: String, node_id: String) -> Dictionary:
	if DIALOGUES.has(npc_id) and DIALOGUES[npc_id].has(node_id):
		return DIALOGUES[npc_id][node_id]
	return {}
