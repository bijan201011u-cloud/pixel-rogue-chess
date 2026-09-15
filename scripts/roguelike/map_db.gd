class_name MapDB
## Predefined MVP map (linear with one branch):
##
##   BOSS        (row 4)
##     |
##   BATTLE 3    (row 3)
##    /   \
##   B2    EVENT  (row 2)
##    \   /
##   BATTLE 1    (row 1)
##     |
##   START       (row 0)
##
## tier selects the AI strength entry from Balance.DIFFICULTIES.
## Labels are i18n keys built at the call sites (I18n.node_label(node)).

const COLS := 3
const ROWS := 5

const NODES := {
        "start": {"type": "start", "row": 0, "col": 1, "next": ["b1"]},
        "b1": {"type": "battle", "n": 1, "row": 1, "col": 1, "next": ["b2", "e1"], "tier": 0, "coins": 10, "hard": false},
        "b2": {"type": "battle", "n": 2, "row": 2, "col": 0, "next": ["b3"], "tier": 1, "coins": 10, "hard": false},
        "e1": {"type": "event", "row": 2, "col": 2, "next": ["b3"]},
        "b3": {"type": "battle", "n": 3, "row": 3, "col": 1, "next": ["boss"], "tier": 2, "coins": 15, "hard": true},
        "boss": {"type": "boss", "row": 4, "col": 1, "next": [], "tier": 3, "coins": 50},
}


static func node_of(id: String) -> Dictionary:
        return NODES.get(id, {})


## Nodes the player may enter next, given the completed list.
static func available_nodes(completed: Array) -> Array:
        var result: Array = []
        for id in NODES:
                if completed.has(id):
                        for nxt in NODES[id]["next"]:
                                if not completed.has(nxt) and not result.has(nxt):
                                        result.append(nxt)
        return result
