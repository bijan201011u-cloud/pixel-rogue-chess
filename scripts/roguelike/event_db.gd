class_name EventDB
## The 3 MVP events. All text lives in I18n (keys below); effects are
## applied by EventScreen through RunManager.

const EVENTS := [
        {
                "id": "traveler", "title_key": "ev_traveler_t", "text_key": "ev_traveler_x",
                "icon": "res://assets/ui/ev_question.png",
                "choices": [
                        {"label_key": "ev_accept", "result_key": "ev_traveler_ar", "effect": "coins_traveler"},
                        {"label_key": "ev_decline", "result_key": "ev_traveler_dr", "effect": "none"},
                ],
        },
        {
                "id": "risky", "title_key": "ev_risky_t", "text_key": "ev_risky_x",
                "icon": "res://assets/ui/ui_sword.png",
                "choices": [
                        {"label_key": "ev_risk", "result_key": "ev_risky_r", "effect": "coins_risk"},
                        {"label_key": "ev_safe", "result_key": "ev_risky_s", "effect": "none"},
                ],
        },
        {
                "id": "lost_knight", "title_key": "ev_knight_t", "text_key": "ev_knight_x",
                "icon": "res://assets/ui/up_knight_fury.png",
                "choices": [
                        {"label_key": "ev_recruit", "result_key": "ev_knight_r", "effect": "knight_inspire"},
                        {"label_key": "ev_leave", "result_key": "ev_knight_l", "effect": "none"},
                ],
        },
]


static func pick_event(exclude: Array) -> Dictionary:
        var pool: Array = EVENTS.filter(func(e): return not exclude.has(e["id"]))
        if pool.is_empty():
                pool = EVENTS.duplicate(true)
        return pool.pick_random()
