extends Node
## AUTOLOAD: GameManager
## Central flow controller: scene transitions and pending payloads for the
## next scene (battle config, event data). Screen order:
## MENU -> (AI: MAP -> BATTLE -> REWARD-FREE MAP LOOP ... -> BOSS -> END)
## MENU -> (PVP: single hotseat chess battle -> rematch/menu)

const SCENE_MENU := "res://scenes/main_menu/main_menu.tscn"
const SCENE_MAP := "res://scenes/map/map.tscn"
const SCENE_BATTLE := "res://scenes/chess/chess_battle.tscn"
const SCENE_EVENT := "res://scenes/event/event_screen.tscn"

var pending_battle: Dictionary = {}
var pending_event: Dictionary = {}
var _busy := false


func _ready() -> void:
        randomize()


func goto_scene(path: String) -> void:
        if _busy:
                return
        _busy = true
        get_tree().change_scene_to_file(path)
        await get_tree().process_frame
        await get_tree().process_frame
        _busy = false


## START RUN (vs AI): fresh roguelike run on the map.
func start_ai_run() -> void:
        RunManager.start_new_run()
        goto_scene(SCENE_MAP)


## 2 PLAYERS: one hotseat chess battle on this phone.
func start_pvp() -> void:
        pending_battle = {"mode": "pvp", "node_id": "pvp", "label": "2P DUEL",
                        "is_boss": false, "base_coins": 0}
        goto_scene(SCENE_BATTLE)


func goto_map() -> void:
        goto_scene(SCENE_MAP)


func goto_main_menu() -> void:
        goto_scene(SCENE_MENU)


func goto_event() -> void:
        goto_scene(SCENE_EVENT)


## Enter a map node: dispatch to battle / boss / event.
func enter_node(id: String) -> void:
        var node: Dictionary = MapDB.node_of(id)
        if node.is_empty():
                return
        RunManager.current_node = id
        match String(node["type"]):
                "battle":
                        pending_battle = _make_battle_config(id, node, false)
                        goto_scene(SCENE_BATTLE)
                "boss":
                        pending_battle = _make_battle_config(id, node, true)
                        goto_scene(SCENE_BATTLE)
                "event":
                        pending_event = EventDB.pick_event(RunManager.events_seen)
                        goto_scene(SCENE_EVENT)


func _make_battle_config(id: String, node: Dictionary, is_boss: bool) -> Dictionary:
        var ai: Dictionary = Balance.ai_config(SaveManager.difficulty, int(node.get("tier", 0)))
        # run upgrades (TERROR / SHARP EYE) make the AI sloppier
        ai["jitter"] = float(ai["jitter"]) + RunManager.mod_jitter
        ai["blunder"] = minf(float(ai["blunder"]) + RunManager.mod_blunder, 0.5)
        return {
                "node_id": id,
                "label": I18n.node_label(node),
                "is_boss": is_boss,
                "mode": "ai",
                "depth": ai["depth"],
                "jitter": ai["jitter"],
                "blunder": ai["blunder"],
                "base_coins": int(node.get("coins", 10)),
                "difficulty": SaveManager.difficulty,
        }


## Called by the battle scene after a normal-battle VICTORY.
## Upgrades now come from captures inside the battle -> straight back to map.
func after_battle_victory() -> void:
        RunManager.complete_node(String(pending_battle.get("node_id", "")))
        goto_scene(SCENE_MAP)
