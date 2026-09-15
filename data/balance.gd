class_name Balance
## Central tuning constants for the MVP run.

## --- capture -> upgrade tier mapping -------------------------------------
## Chess piece values: P=1, N=3, B=3, R=5, Q=9. The captured piece's value
## decides which TIER of upgrade the player is granted:
##   Pawn  (1) -> TIER 1   Knight/Bishop (3) -> TIER 2
##   Rook  (5) -> TIER 3   Queen (9)          -> TIER 4
const CAPTURE_TIER := {1: 1, 2: 2, 3: 2, 4: 3, 5: 4}
const FALLBACK_COINS := {1: 8, 2: 18, 3: 30, 4: 60}  # tier pool exhausted

## --- upgrade stack values --------------------------------------------------
const COIN_PURSE_COINS := 8        # +coins after every victory (per stack)
const PAWN_TAX_COINS := 2          # +coins per capture (per stack)
const BRAVE_PAWNS_COINS := 4       # +coins per pawn capture (per stack)
const KNIGHT_FURY_COINS := 6       # +coins per knight capture (per stack)
const BISHOP_TITHE_COINS := 6      # +coins per bishop capture (per stack)
const SECOND_CHANCE_TOKENS := 1    # undo tokens granted (per stack)
const WAR_CHEST_STEP := 0.25       # +25% coin gains (per stack)
const TERROR_BLUNDER := 0.08       # +8% enemy blunder (per stack)
const SHARP_EYE_JITTER := 0.45     # extra AI evaluation noise (unique)
const LUCKY_START_COINS := 12      # granted when a battle begins
const KNIGHT_INSPIRE_COINS := 6    # lost-knight event, next battle only

## --- legacy / general ------------------------------------------------------
const MOMENTUM_STEP := 0.25          # +25% multiplier per consecutive win
const TREASURE_MULT := 1.5           # treasure hunter battle reward bonus
const EVENT_TRAVELER_COINS := 10
const EVENT_RISK_COINS := 20
const CORRUPTED_SQUARES := 6         # boss battle corrupted squares
const HEXBREAKER_CLEANSE := 2        # corrupted squares cleansed by HEXBREAKER

## Per-difficulty AI setup per battle tier: 0=BATTLE 1, 1=BATTLE 2,
## 2=BATTLE 3, 3=BOSS. depth = search depth, jitter = centipawn noise,
## blunder = chance to pick a random 2nd-5th best move.
const DIFFICULTIES := {
        "easy": {
                "depths": [1, 1, 2, 2],
                "jitters": [1.4, 1.2, 0.9, 0.5],
                "blunders": [0.35, 0.30, 0.20, 0.10],
        },
        "normal": {
                "depths": [1, 2, 2, 3],
                "jitters": [0.9, 0.6, 0.5, 0.0],
                "blunders": [0.18, 0.10, 0.08, 0.0],
        },
        "hard": {
                "depths": [2, 3, 3, 3],
                "jitters": [0.5, 0.3, 0.2, 0.0],
                "blunders": [0.08, 0.04, 0.02, 0.0],
        },
}


static func ai_config(difficulty: String, tier: int) -> Dictionary:
        var d: Dictionary = DIFFICULTIES.get(difficulty, DIFFICULTIES["normal"])
        tier = clampi(tier, 0, 3)
        return {
                "depth": d["depths"][tier],
                "jitter": d["jitters"][tier],
                "blunder": d["blunders"][tier],
        }
