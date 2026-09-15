class_name UpgradeDB
## CAPTURE-BASED UPGRADE SYSTEM (v2).
## Every enemy piece the player captures grants an upgrade. The captured
## piece's VALUE decides the upgrade tier: better pieces -> better upgrades.
##   Pawn (1) -> TIER 1 | Knight/Bishop (3) -> TIER 2
##   Rook (5) -> TIER 3 | Queen (9) -> TIER 4
## Stackable upgrades may be granted repeatedly (stacks increase the effect).
## When a tier's pool is exhausted the player receives fallback coins.
## All text lives in I18n (keys "up_<id>" name, "up_<id>_d" description).

const TIER_UPGRADES := {
        1: ["coin_purse", "pawn_tax", "brave_pawns", "lucky_start"],
        2: ["knight_fury", "bishop_tithe", "treasure_hunter", "second_chance", "sharp_eye"],
        3: ["momentum", "iron_pawns", "royal_guard", "war_chest", "terror"],
        4: ["royal_decree", "phoenix", "midas"],
}

const ALL := {
        # ---------------- TIER 1 (pawn captures) ----------------
        "coin_purse": {"tier": 1, "icon": "res://assets/ui/up_coin_purse.png", "stackable": true},
        "pawn_tax": {"tier": 1, "icon": "res://assets/ui/up_pawn_tax.png", "stackable": true},
        "brave_pawns": {"tier": 1, "icon": "res://assets/ui/up_brave_pawns.png", "stackable": true},
        "lucky_start": {"tier": 1, "icon": "res://assets/ui/up_lucky_start.png", "stackable": false},
        # ---------------- TIER 2 (knight / bishop captures) ----------------
        "knight_fury": {"tier": 2, "icon": "res://assets/ui/up_knight_fury.png", "stackable": true},
        "bishop_tithe": {"tier": 2, "icon": "res://assets/ui/up_bishop_tithe.png", "stackable": true},
        "treasure_hunter": {"tier": 2, "icon": "res://assets/ui/up_treasure_hunter.png", "stackable": false},
        "second_chance": {"tier": 2, "icon": "res://assets/ui/up_second_chance.png", "stackable": true},
        "sharp_eye": {"tier": 2, "icon": "res://assets/ui/up_sharp_eye.png", "stackable": false},
        # ---------------- TIER 3 (rook captures) ----------------
        "momentum": {"tier": 3, "icon": "res://assets/ui/up_momentum.png", "stackable": false},
        "iron_pawns": {"tier": 3, "icon": "res://assets/ui/up_iron_pawns.png", "stackable": false},
        "royal_guard": {"tier": 3, "icon": "res://assets/ui/up_royal_guard.png", "stackable": false},
        "war_chest": {"tier": 3, "icon": "res://assets/ui/up_war_chest.png", "stackable": true},
        "terror": {"tier": 3, "icon": "res://assets/ui/up_terror.png", "stackable": true},
        # ---------------- TIER 4 (queen captures) ----------------
        "royal_decree": {"tier": 4, "icon": "res://assets/ui/up_royal_decree.png", "stackable": false},
        "phoenix": {"tier": 4, "icon": "res://assets/ui/up_phoenix.png", "stackable": false},
        "midas": {"tier": 4, "icon": "res://assets/ui/up_midas.png", "stackable": false},
}


static func get_upgrade(id: String) -> Dictionary:
        var u: Dictionary = ALL.get(id, {})
        if u.is_empty():
                return {}
        # name/desc are i18n KEYS (callers translate via I18n.t(key)) so this
        # static helper never touches an autoload directly.
        return {"id": id, "tier": u["tier"], "icon": u["icon"],
                        "stackable": u["stackable"],
                        "name_key": "up_" + id, "desc_key": "up_" + id + "_d"}


static func tier_of(id: String) -> int:
        return int(ALL.get(id, {}).get("tier", 0))


## Pick a random grant for the given tier based on the run's current state.
## Returns {"id": "..."} or {"coins": int} when the tier pool is exhausted.
static func grant_for_tier(tier: int, run) -> Dictionary:
        var ids: Array = TIER_UPGRADES.get(tier, [])
        var candidates: Array = []
        for id in ids:
                var u: Dictionary = ALL.get(id, {})
                if u.is_empty():
                        continue
                if u["stackable"] or not run.has_upgrade(id):
                        candidates.append(id)
        if candidates.is_empty():
                return {"coins": int(Balance.FALLBACK_COINS.get(tier, 10))}
        return {"id": candidates.pick_random()}


## Human-readable tier color tag used by toasts.
static func tier_color(tier: int) -> String:
        match tier:
                1: return "#9a9ab0"
                2: return "#7fd98a"
                3: return "#e8c84a"
                _: return "#e5646c"
