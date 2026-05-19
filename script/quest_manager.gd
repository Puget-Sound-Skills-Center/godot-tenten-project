extends Node

# Central service for all quest state mutations.
# Owns: global.quest_state, global.items, global.unlocks writes.
# No other script should mutate these dicts directly.

# ---------------- Quest lifecycle ----------------

func accept_quest(qid: String) -> bool:
	if active_quest_count() >= 3:
		return false
	var template: Dictionary = quest_data.get_quest(qid)
	if template.is_empty():
		return false
	if global.quest_state.has(qid) and global.quest_state[qid].get("status", "") in ["active", "ready_to_complete"]:
		return false
	var entry: Dictionary = template.duplicate(true)
	entry["status"] = "active"
	match entry.get("type", ""):
		"kill":
			entry["progress"] = 0
		"reach_floor":
			entry["reached"] = false
		"story_chain":
			entry["step"] = 0
	global.quest_state[qid] = entry
	return true

func complete_quest(qid: String) -> bool:
	if not global.quest_state.has(qid):
		return false
	var q: Dictionary = global.quest_state[qid]
	if q.get("status", "") == "complete":
		return false
	var gold: int = int(q.get("reward_gold", 0))
	global.money += gold
	var item_id: String = String(q.get("reward_item", ""))
	if item_id != "":
		global.items[item_id] = int(global.items.get(item_id, 0)) + 1
	var unlock_id: String = String(q.get("reward_unlock", ""))
	if unlock_id != "":
		global.unlocks[unlock_id] = true
	q["status"] = "complete"
	return true

# ---------------- Event hooks ----------------

func on_enemy_killed(enemy_type: String) -> void:
	for qid in global.quest_state.keys():
		var q: Dictionary = global.quest_state[qid]
		if q.get("type") != "kill":
			continue
		if q.get("status") != "active":
			continue
		if q.get("target_type", "") != enemy_type:
			continue
		q["progress"] = int(q.get("progress", 0)) + 1
		if q["progress"] >= int(q.get("required", 0)):
			q["status"] = "ready_to_complete"

func on_floor_reached(floor_no: int) -> void:
	for qid in global.quest_state.keys():
		var q: Dictionary = global.quest_state[qid]
		if q.get("type") != "reach_floor":
			continue
		if q.get("status") != "active":
			continue
		if floor_no >= int(q.get("target_floor", 0)):
			q["reached"] = true
			q["status"] = "ready_to_complete"

func advance_story_chain() -> void:
	if not global.quest_state.has("story_chain"):
		push_warning("advance_story_chain: story_chain quest not in quest_state — call accept_quest first")
		return
	var q: Dictionary = global.quest_state["story_chain"]
	if q.get("status", "") != "active":
		return
	q["step"] = int(q.get("step", 0)) + 1

# ---------------- Queries ----------------

func has_active_fetch_quest() -> bool:
	for qid in global.quest_state.keys():
		var q: Dictionary = global.quest_state[qid]
		if q.get("type") != "fetch":
			continue
		if q.get("status") != "active":
			continue
		var item_id: String = String(q.get("item_id", ""))
		if int(global.items.get(item_id, 0)) == 0:
			return true
	return false

func get_active_fetch_item_id() -> String:
	for qid in global.quest_state.keys():
		var q: Dictionary = global.quest_state[qid]
		if q.get("type") == "fetch" and q.get("status") == "active":
			return String(q.get("item_id", ""))
	return ""

func quest_ready(qid: String) -> bool:
	if not global.quest_state.has(qid):
		return false
	var q: Dictionary = global.quest_state[qid]
	if q.get("status", "") == "ready_to_complete":
		return true
	# Fetch shortcut: if player carries the item, treat as ready
	if q.get("type", "") == "fetch" and q.get("status", "") == "active":
		var item_id: String = String(q.get("item_id", ""))
		if int(global.items.get(item_id, 0)) >= 1:
			return true
	return false

func active_quest_count() -> int:
	var count := 0
	for qid in global.quest_state.keys():
		var s: String = String(global.quest_state[qid].get("status", ""))
		if s == "active" or s == "ready_to_complete":
			count += 1
	return count

func get_objective_string(qid: String) -> String:
	if not global.quest_state.has(qid):
		return qid
	var q: Dictionary = global.quest_state[qid]
	match q.get("type", ""):
		"kill":
			var t: String = String(q.get("target_type", ""))
			var prog: int = int(q.get("progress", 0))
			var req: int = int(q.get("required", 0))
			return "Kill %s Enemies (%d/%d)" % [t.capitalize(), prog, req]
		"fetch":
			var item_id: String = String(q.get("item_id", ""))
			var pretty: String = item_id.replace("_", " ").capitalize()
			if int(global.items.get(item_id, 0)) >= 1:
				return "Return: %s (Got it!)" % [pretty]
			return "Find: %s" % [pretty]
		"reach_floor":
			var tf: int = int(q.get("target_floor", 0))
			if q.get("reached", false):
				return "Reach Floor %d (Done!)" % [tf]
			return "Reach Floor %d" % [tf]
		"story_chain":
			var step: int = int(q.get("step", 0))
			var seq: Array = q.get("npc_sequence", [])
			if step >= seq.size():
				return "The Lost Fragment: Complete!"
			var next_npc: String = String(seq[step])
			return "Talk to: %s (step %d/3)" % [next_npc.capitalize(), step + 1]
	return qid
