# PIXEL ROGUE CHESS (MVP v0.3)

A chess + roguelike mobile game built with **Godot 4.3+** (GDScript).
Play real chess battles against an AI — **every enemy piece you capture
grants an upgrade** (stronger pieces -> stronger upgrade tiers) — then
defeat **THE CORRUPTED KING**. Or share the phone and play a friend in the
hotseat **2 PLAYERS** mode. English & Persian (فارسی) included.

- Portrait 1080x1920, touch-first (mouse works for desktop testing)
- Full chess rules: castling, en passant, promotion, check/checkmate/stalemate
- Threaded AI (3 difficulties) that replies the instant your move finishes
- Animated moves: pieces slide, captured pieces fade, castling slides both
- 17 tiered gameplay upgrades earned by captures, 3 events, coins, 1 boss
  with the CORRUPTION modifier
- EN / FA language switch in Settings (Vazirmatn font ships with the game)
- Music + SFX (menu/game themes, move, upgrade, win/lose) with live toggles
- **Perfect piece alignment system** (see below)

## Run it

1. Install **Godot 4.3 or newer** (standard build, no extra plugins needed).
2. Open Godot -> **Import** -> select this folder's `project.godot`.
3. Press **F5** (or the Play button). That's it — desktop window opens at a
   phone-shaped 486x864 test size; on Android it runs full portrait.

## Main menu

- **PLAY VS AI** — pick EASY / NORMAL / HARD, then start the roguelike run.
- **2 PLAYERS** — hotseat chess for two people on one phone (white moves
  first; checkmate/stalemate ends the match with a REMATCH button).
- **SETTINGS** — language (ENGLISH / فارسی), AI difficulty, sound / music /
  vibration, and a dev **DEBUG ALIGNMENT** toggle. Everything is persisted
  locally (user://settings.cfg).

## Perfect piece alignment (system-level)

Piece placement is driven by ONE authoritative coordinate system in
`board_view.gd` — never by manual offsets:

- The `BoardView` control's own rect IS the board. Everything derives from
  it: `square_size() = size / 8` and
  `get_square_center(square: Vector2i) ->
  Vector2((x + 0.5) * w, (y + 0.5) * h)`.
- Every node (tiles, overlays, pieces) is placed through
  `get_square_center()` / `sq_center()`; taps use the inverse
  `square_at()`.
- All 12 sprites are normalized 180x180 canvases whose **visible content is
  centered by contract** (verified by automated alpha-bbox checks), so the
  full-canvas mapping puts the visible piece center exactly on the square
  center. `PieceView` locks its pivot to the node center (center-symmetric
  capture shrink).
- On resize (window / DPI / layout), `resized -> _relayout()` re-derives
  every node from the new rect — pieces can never drift.
- After EVERY animated move the piece is explicitly snapped to the exact
  calculated destination center (a write-guard also blocks straggler tween
  writes), and `refresh()` re-snaps everything on undo / promotion /
  restarts.
- **DEBUG ALIGNMENT** (Settings): draws the mathematical center (cross +
  coordinates) of all 64 squares and each piece's actual pivot (green =
  centered) plus a live `max_dev` summary.
- `validate_alignment()` automates the check for all 64 squares and fails
  above 0.5px — it runs in the test suite after setup, animated moves,
  captures, promotion, forced drift and resize.

## Controls

- Tap one of your pieces -> legal destinations highlight.
- Tap a highlighted square -> the piece slides there (animated), captures
  fade out, and the AI answers immediately in AI mode.
- Tap the selected piece again to cancel selection.
- UNDO (needs a SECOND CHANCE token): reverts your last move + AI reply.
- FORFEIT ends the battle (defeat screen in AI mode / back to menu in PvP).

## Capture = Upgrade

Every capture made by one of YOUR pieces grants an instant upgrade toast in
battle. The captured piece's VALUE picks the tier:

| Captured piece | Value | Tier |
|---|---|---|
| Pawn | 1 | 1 — COMMON |
| Knight / Bishop | 3 | 2 — RARE |
| Rook | 5 | 3 — EPIC |
| Queen | 9 | 4 — LEGENDARY |

When a tier's pool is exhausted you receive fallback coins instead
(8 / 18 / 30 / 60). Stackable upgrades can drop repeatedly and stack ("x2",
"x3"...). Tap an upgrade icon in the ACTIVE panel to read what it does.

### The 17 upgrades (all effects are real, not cosmetic)

| Tier | Upgrade | Effect |
|---|---|---|
| 1 | COIN PURSE (stack) | +8 coins after every victory. |
| 1 | PAWN TAX (stack) | +2 coins every time any of your pieces captures. |
| 1 | BRAVE PAWNS (stack) | +4 coins per capture made by a Pawn. |
| 1 | LUCKY START | +12 coins at the start of every battle. |
| 2 | KNIGHT FURY (stack) | +6 coins per capture made by a Knight. |
| 2 | BISHOP'S TITHE (stack) | +6 coins per capture made by a Bishop. |
| 2 | TREASURE HUNTER | Victory rewards +50%. |
| 2 | SECOND CHANCE (stack) | +1 UNDO token (revert your last move + reply). |
| 2 | SHARP EYE | The enemy AI's evaluation gets noisier (sloppier play). |
| 3 | MOMENTUM | +25% coin multiplier per consecutive victory. |
| 3 | IRON PAWNS | Once per battle: the AI's pawn capture is blocked; it must play elsewhere. |
| 3 | ROYAL GUARD | Once per run: survive a checkmate — the attacker is destroyed. |
| 3 | WAR CHEST (stack) | All coin gains +25%. |
| 3 | TERROR (stack) | Enemy blunder chance +8%. |
| 4 | ROYAL DECREE | Every battle starts with an extra Queen (your h-pawn). |
| 4 | PHOENIX FEATHER | Once per battle: survive a checkmate like Royal Guard. |
| 4 | MIDAS TOUCH | ALL coin gains doubled (x2). |

## The run

```
MENU -> PLAY VS AI -> MAP -> BATTLE 1 (captures grant upgrades)
                     -> BATTLE 2 (or EVENT) -> BATTLE 3 -> BOSS
                     -> RUN COMPLETE / RUN FAILED
```

- Coins: Battle 1/2 = +10, Battle 3 = +15, Boss = +50, events give more.
- Coins are an MVP resource for a future shop; check the HUD on map & battle.

## Boss: THE CORRUPTED KING

Deeper AI search plus CORRUPTION: 6 random squares turn purple at battle
start. **Your (white) pieces may never land on them** — black plays freely.

## Difficulty

| Setting | Battles 1 / 2 / 3 / Boss (AI search depth) |
|---|---|
| EASY   | 1 / 1 / 2 / 2 + heavy noise & blunders |
| NORMAL | 1 / 2 / 2 / 3 + light noise |
| HARD   | 2 / 3 / 3 / 3, nearly deterministic |

The AI (negamax + alpha-beta, material & piece-square evaluation) starts
searching the moment your move is committed — in parallel with the move
animation — so the reply lands the instant your piece lands. A safety
timeout guarantees the game never soft-locks.

## Prebuilt builds & Exporting

Ready-made builds live in `../builds/` (next to this folder):

| File | Target | Notes |
|---|---|---|
| `PixelRogueChess.apk` | Android (arm64-v8a) | Signed with `keys/release.keystore`, installable on any 64-bit Android 7+ phone |
| `PixelRogueChess.exe` | Windows x86_64 | Single file, pck embedded — just run it |
| `PixelRogueChess-Web.zip` | Web / HTML5 | Unzip, serve the folder with any static server (e.g. `python -m http.server`) and open in a browser |

### Exporting yourself (Godot 4.3+ editor)

1. **Android**: Editor Settings -> install/point to the **Android build template**
   (JDK 17 + Android SDK; Godot can install the export templates for you).
   `Project -> Export...` — the **Android** preset is already configured
   (portrait, immersive, arm64, package `com.pixelroguechess.game`).
   A test keystore ships at `keys/release.keystore`
   (alias `pixelroguechess`, password `pixelroguechess`) — **generate your own
   keystore before publishing to Google Play**.
2. **Windows**: the **Windows Desktop** preset exports a single self-contained EXE.
3. **Web**: the **Web** preset ships with thread support OFF, so it runs on any
   static host without COOP/COEP headers (the AI falls back to a synchronous
   compute automatically).
4. Export templates must match your Godot version exactly (4.3-stable).

## Project layout

```
project.godot            portrait 1080x1920, touch emulation, 5 autoloads
scenes/                  one lightweight .tscn per screen (UI built in code)
  main_menu/ map/ chess/ event/
scripts/
  chess/                 chess_state.gd (pure position data)
                         chess_rules.gd (full rules + perft + FEN)
  ai/                    chess_ai.gd (thread-safe negamax engine)
  roguelike/             upgrade_db.gd (tiered pool), event_db.gd, map_db.gd
  managers/              save_manager.gd, i18n.gd, audio_manager.gd,
                         run_manager.gd, game_manager.gd (autoloads)
  ui/                    ui_kit.gd, board_view.gd (authoritative coordinates),
                         piece_view.gd (center-pivot piece node), one per screen
data/balance.gd          all tuning constants (capture tiers, coins, AI levels)
assets/pixel/            pieces (normalized 180x180), tiles, highlights, nodes
assets/ui/               buttons, cards, icons, backgrounds
assets/audio/            menu/game music + move/upgrade/win/lose SFX (mp3)
assets/fonts/            Vazirmatn Regular/Bold (Latin + Persian)
tests/validate.gd        headless test suite
tests/screenshots.gd     visual QA renderer (Xvfb)
```

Chess logic is fully separated from rendering: `ChessRules`/`ChessAI` never
touch the scene tree, and `BoardView` only reads a `ChessState`.

## Tests

The rules engine is verified against published perft numbers (start position
20/400/8902, Kiwipete 48/2039, position 3 14/191/2812), plus unit tests for
castling, en passant, promotion, mate/stalemate, corruption, AI legality,
capture-tier upgrades, i18n completeness (every key EN+FA), the full animated
battle flow (parallel AI reply, undo token, knight-fury coins), the PvP
hotseat flow and the perfect-alignment suite (sprite centering contract,
coordinate math, 64-square validation after moves/captures/promotion/drift/
resize) — 187 checks total.

```bash
godot --headless --path . --import
godot --headless --path . -s res://tests/validate.gd
```

`tests/screenshots.gd` renders key screens to PNG for visual QA (requires a
display or Xvfb; not exported with the game).

## Expanding it

- New upgrades: add an entry in `scripts/roguelike/upgrade_db.gd`
  (+ its `up_<id>` / `up_<id>_d` strings in `i18n.gd`) and hook the effect in
  `run_manager.gd` / `chess_battle.gd`.
- New events: append to `event_db.gd`, add strings + an effect branch in
  `event_screen.gd`.
- New languages: add a column to `i18n.gd` STRINGS and a button in settings.
- Bigger maps: edit `map_db.gd` — nodes, rows/cols and connections are data.
- Balance: everything numeric lives in `data/balance.gd`.
