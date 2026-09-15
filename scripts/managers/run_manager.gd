extends Node
## AUTOLOAD: RunManager
## Holds all roguelike run data: coins, upgrades, map progress, streaks and
## the per-run/per-battle ability states. Reset by start_new_run().
##
## CAPTURE-BASED UPGRADES (v2): every enemy piece captured by the player
## grants an upgrade whose TIER depends on the captured piece's value
## (P->1, N/B->2, R->3, Q->4). See UpgradeDB / Balance.CAPTURE_TIER.

signal coins_changed(coins: int)
signal upgrades_changed

var coins: int = 0
var coins_earned: int = 0
var upgrades: Array = []             # active upgrade ids (unique)
var upgrade_stacks: Dictionary = {}  # id -> stack count (>=1 when owned)
var current_node: String = "start"
var completed_nodes: Array = []
var win_streak: int = 0
var battles_completed: int = 0
var boss_status: String = "pending"  # pending / defeated
var undo_tokens: int = 0             # SECOND CHANCE tokens (undo player+ai move)
var guard_charges: int = 0           # ROYAL GUARD mate-saves left (this run)
var iron_pawns_used: bool = false    # once per battle
var phoenix_used: bool = false       # PHOENIX FEATHER: once per battle
var knight_inspire_battles: int = 0  # lost-knight event: next N battles
var events_seen: Array = []
var upgrades_gained_battle: Array = []  # names gained in the current battle

# run-wide AI/coin modifiers granted by upgrades
var mod_blunder: float = 0.0         # TERROR stacks
var mod_jitter: float = 0.0          # SHARP EYE


func start_new_run() -> void:
        coins = 0
        coins_earned = 0
        upgrades = []
        upgrade_stacks = {}
        current_node = "start"
        completed_nodes = ["start"]
        win_streak = 0
        battles_completed = 0
        boss_status = "pending"
        undo_tokens = 0
        guard_charges = 0
        iron_pawns_used = false
        phoenix_used = false
        knight_inspire_battles = 0
        events_seen = []
        upgrades_gained_battle = []
        mod_blunder = 0.0
        mod_jitter = 0.0
        coins_changed.emit(coins)
        upgrades_changed.emit()


func has_upgrade(id: String) -> bool:
        return upgrade_stacks.has(id)


func stacks(id: String) -> int:
        return int(upgrade_stacks.get(id, 0))


func add_upgrade(id: String) -> void:
        if upgrade_stacks.has(id):
                upgrade_stacks[id] = int(upgrade_stacks[id]) + 1
        else:
                upgrade_stacks[id] = 1
                upgrades.append(id)
        _apply_upgrade_effect(id)
        upgrades_changed.emit()


func _apply_upgrade_effect(id: String) -> void:
        match id:
                "second_chance":
                        undo_tokens += Balance.SECOND_CHANCE_TOKENS
                "royal_guard":
                        guard_charges += 1
                "sharp_eye":
                        mod_jitter += Balance.SHARP_EYE_JITTER
                "terror":
                        mod_blunder += Balance.TERROR_BLUNDER
                _:
                        pass


## Called by the battle scene when a battle begins (per-battle resets +
## per-battle coin effects). Returns lucky-start coins gained (0 if none).
func begin_battle() -> int:
        iron_pawns_used = false
        phoenix_used = false
        upgrades_gained_battle = []
        var lucky := 0
        if has_upgrade("lucky_start"):
                lucky = gain_multiplied(Balance.LUCKY_START_COINS)
        return lucky


## Player captured an enemy piece: per-capture coin bonuses + tiered
## upgrade grant. `cap` = captured piece code (decides the TIER),
## `capturer` = the player's piece that made the capture (decides
## per-capture coin bonuses like KNIGHT FURY). Returns a UI breakdown.
func on_player_capture(cap: int, capturer := 0) -> Dictionary:
        var t := absi(int(cap))
        var tier := int(Balance.CAPTURE_TIER.get(t, 1))
        # per-capture coins depend on WHO captured (the player's piece)
        var base := stacks("pawn_tax") * Balance.PAWN_TAX_COINS
        match absi(int(capturer)):
                ChessState.PAWN:
                        base += stacks("brave_pawns") * Balance.BRAVE_PAWNS_COINS
                ChessState.KNIGHT:
                        base += stacks("knight_fury") * Balance.KNIGHT_FURY_COINS
                ChessState.BISHOP:
                        base += stacks("bishop_tithe") * Balance.BISHOP_TITHE_COINS
        var coins_gained := 0
        if base > 0:
                coins_gained = gain_multiplied(base)
        # tiered upgrade grant
        var grant: Dictionary = UpgradeDB.grant_for_tier(tier, self)
        var upgrade_id := ""
        if grant.has("id"):
                upgrade_id = String(grant["id"])
                add_upgrade(upgrade_id)
                upgrades_gained_battle.append(I18n.t(UpgradeDB.get_upgrade(upgrade_id).get("name_key", upgrade_id)))
        else:
                var fb := int(grant["coins"])
                coins_gained += _add_raw(fb)
                upgrades_gained_battle.append(I18n.fmt("cap_pool_empty", [fb]))
        return {"tier": tier, "coins": coins_gained, "upgrade": upgrade_id}


func _add_raw(amount: int) -> int:
        if amount <= 0:
                return 0
        coins += amount
        coins_earned += amount
        coins_changed.emit(coins)
        return amount


## Total coin multiplier: momentum streak x war chest stacks x midas.
func multiplier() -> float:
        var m := 1.0
        if has_upgrade("momentum"):
                m *= 1.0 + Balance.MOMENTUM_STEP * win_streak
        if stacks("war_chest") > 0:
                m *= 1.0 + Balance.WAR_CHEST_STEP * stacks("war_chest")
        if has_upgrade("midas"):
                m *= 2.0
        return m


func add_coins(amount: int) -> void:
        _add_raw(amount)


## Adds amount * multiplier(), returns the total actually granted.
func gain_multiplied(base: int) -> int:
        var total := int(round(base * multiplier()))
        return _add_raw(total)


## Called when a battle is won. Applies the reward (base x multipliers x
## treasure hunter + coin purse stacks), updates streaks, returns breakdown.
func on_battle_won(base_coins: int, is_boss: bool) -> Dictionary:
        win_streak += 1
        battles_completed += 1
        if is_boss:
                boss_status = "defeated"
        var mult := multiplier()
        var th := Balance.TREASURE_MULT if has_upgrade("treasure_hunter") else 1.0
        var total := int(round(base_coins * mult * th))
        total += stacks("coin_purse") * Balance.COIN_PURSE_COINS
        _add_raw(total)
        iron_pawns_used = false
        return {"base": base_coins, "mult": mult, "treasure": th, "total": total}


func complete_node(id: String) -> void:
        if not completed_nodes.has(id):
                completed_nodes.append(id)
        current_node = id


func upgrades_text() -> String:
        if upgrades.is_empty():
                return I18n.t("res_none")
        var names: Array = []
        for id in upgrades:
                var n := I18n.t(String(UpgradeDB.get_upgrade(id).get("name_key", id)))
                if stacks(id) > 1:
                        n += " x%d" % stacks(id)
                names.append(n)
        return ", ".join(names)
