extends Node
## AUTOLOAD: I18n
## Tiny localization layer: EN / FA (Persian). All UI text goes through t().
## Also installs the project-wide font (Vazirmatn covers Latin + Persian).

const FONT_REGULAR := "res://assets/fonts/Vazirmatn-Regular.ttf"
const FONT_BOLD := "res://assets/fonts/Vazirmatn-Bold.ttf"

var lang: String = "en"

# key -> {"en": ..., "fa": ...}
const STRINGS := {
        # ---- main menu ----
        "menu_tagline": {"en": "Real chess. Capture pieces to gain upgrades.\nDefeat the Corrupted King.",
                "fa": "شطرنج واقعی. با گرفتن مهره‌ها ارتقا بگیر.\nپادشاه فاسد را شکست بده."},
        "menu_play_ai": {"en": "PLAY VS AI", "fa": "بازی با هوش مصنوعی"},
        "menu_play_pvp": {"en": "2 PLAYERS", "fa": "بازی دونفره"},
        "menu_settings": {"en": "SETTINGS", "fa": "تنظیمات"},
        "menu_version": {"en": "v0.2 MVP - touch or mouse", "fa": "نسخه ۰.۲ — لمسی یا موس"},
        "menu_choose_diff": {"en": "CHOOSE DIFFICULTY", "fa": "درجه سختی را انتخاب کن"},
        "diff_easy": {"en": "EASY", "fa": "آسان"},
        "diff_normal": {"en": "NORMAL", "fa": "متوسط"},
        "diff_hard": {"en": "HARD", "fa": "سخت"},
        # ---- settings ----
        "settings_title": {"en": "SETTINGS", "fa": "تنظیمات"},
        "settings_difficulty": {"en": "AI DIFFICULTY", "fa": "سختی هوش مصنوعی"},
        "settings_sound": {"en": "SOUND", "fa": "صدا"},
        "settings_music": {"en": "MUSIC", "fa": "موسیقی"},
        "settings_vibration": {"en": "VIBRATION", "fa": "لرزش"},
        "settings_debug_align": {"en": "DEBUG ALIGNMENT (dev)",
                "fa": "حالت عیب‌یابی چینش مهره‌ها (توسعه‌دهنده)"},
        "settings_language": {"en": "LANGUAGE", "fa": "زبان"},
        "settings_note": {"en": "(Settings are saved automatically.)",
                "fa": "(تنظیمات به‌طور خودکار ذخیره می‌شوند.)"},
        "btn_back": {"en": "BACK", "fa": "بازگشت"},
        # ---- map ----
        "map_battle": {"en": "BATTLE %d", "fa": "نبرد %d"},
        "map_event": {"en": "EVENT", "fa": "رویداد"},
        "map_boss": {"en": "BOSS", "fa": "باوس"},
        "map_start": {"en": "START", "fa": "شروع"},
        "map_menu": {"en": "MENU", "fa": "منو"},
        "map_no_upgrades": {"en": "no upgrades yet", "fa": "هنوز ارتقایی نداری"},
        "node_desc_start": {"en": "Your journey begins.", "fa": "سفر تو از اینجا شروع می‌شود."},
        "node_desc_battle": {"en": "A standard chess battle. Win: +%d coins.",
                "fa": "یک نبرد شطرنج معمولی. برد: +%d سکه."},
        "node_desc_battle_hard": {"en": "A harder battle. Win: +%d coins.",
                "fa": "نبردی سخت‌تر. برد: +%d سکه."},
        "node_desc_event": {"en": "Something happens on the road...", "fa": "در مسیر اتفاقی می‌افتد..."},
        "node_desc_boss": {"en": "THE CORRUPTED KING. Win: +%d coins.",
                "fa": "پادشاه فاسد. برد: +%d سکه."},
        "map_ai_power": {"en": "AI power %d (%s)", "fa": "قدرت هوش مصنوعی %d (%s)"},
        "btn_begin": {"en": "BEGIN", "fa": "شروع"},
        "btn_boss": {"en": "CHALLENGE THE BOSS", "fa": "مبارزه با باوس"},
        "btn_close": {"en": "CLOSE", "fa": "بستن"},
        # ---- battle flow ----
        "pvp_title": {"en": "2P DUEL", "fa": "مبارزه دونفره"},
        "b_you_play_white": {"en": "You play WHITE. Tap a piece to begin.",
                "fa": "تو سفید هستی. برای شروع روی مهره‌ات بزن."},
        "b_pvp_start": {"en": "WHITE moves first. Tap a piece.",
                "fa": "سفید شروع می‌کند. روی مهره بزن."},
        "b_your_turn": {"en": "YOUR TURN - tap a piece", "fa": "نوبت توست — روی مهره بزن"},
        "b_white_turn": {"en": "WHITE'S TURN - tap a piece", "fa": "نوبت سفید — روی مهره بزن"},
        "b_black_turn": {"en": "BLACK'S TURN - tap a piece", "fa": "نوبت سیاه — روی مهره بزن"},
        "b_check_you": {"en": "CHECK! Defend your King!", "fa": "کیش! از شاه دفاع کن!"},
        "b_check_white": {"en": "CHECK! White must defend!", "fa": "کیش! سفید باید دفاع کند!"},
        "b_check_black": {"en": "CHECK! Black must defend!", "fa": "کیش! سیاه باید دفاع کند!"},
        "b_thinking": {"en": "BLACK IS THINKING...", "fa": "سیاه دارد فکر می‌کند..."},
        "b_enemy_piece": {"en": "That piece belongs to the enemy.", "fa": "این مهره مال حریف است."},
        "b_wrong_turn": {"en": "It is not this color's turn.", "fa": "نوبت این رنگ نیست."},
        "b_no_moves": {"en": "No legal moves for that piece.", "fa": "این مهره حرکت مجازی ندارد."},
        "b_moves_hint": {"en": "%d legal moves - tap a highlighted square.",
                "fa": "%d حرکت مجاز — روی خانه روشن بزن."},
        "b_selected": {"en": "Piece selected.", "fa": "مهره انتخاب شد."},
        "b_undo": {"en": "UNDO", "fa": "برگردان"},
        "b_forfeit": {"en": "FORFEIT", "fa": "واگذاری"},
        "b_forfeit_title": {"en": "FORFEIT?", "fa": "واگذاری؟"},
        "b_forfeit_text": {"en": "Abandon this battle and return?", "fa": "این نبرد را رها کنی و برگردی؟"},
        "b_forfeit_pvp": {"en": "End this match and return to menu?", "fa": "این مسابقه تمام شود و به منو برگردی؟"},
        "btn_yes": {"en": "YES", "fa": "بله"},
        "btn_no": {"en": "NO", "fa": "خیر"},
        "btn_continue": {"en": "CONTINUE", "fa": "ادامه"},
        "btn_new_run": {"en": "NEW RUN", "fa": "ران جدید"},
        "btn_main_menu": {"en": "MAIN MENU", "fa": "منوی اصلی"},
        "btn_rematch": {"en": "REMATCH", "fa": "مسابقه مجدد"},
        "log_you": {"en": "You", "fa": "تو"},
        "log_white": {"en": "White", "fa": "سفید"},
        "log_black": {"en": "Black", "fa": "سیاه"},
        "log_enemy": {"en": "Enemy", "fa": "حریف"},
        # ---- results ----
        "res_victory": {"en": "VICTORY!", "fa": "پیروزی!"},
        "res_defeat": {"en": "DEFEAT", "fa": "شکست"},
        "res_mate_win": {"en": "CHECKMATE - the enemy King has fallen!",
                "fa": "کیش و مات — شاه حریف سقوط کرد!"},
        "res_stalemate_win": {"en": "STALEMATE - the enemy has no legal moves!",
                "fa": "پات — حریف حرکت مجازی ندارد!"},
        "res_mate_lose": {"en": "CHECKMATE - your King has fallen.",
                "fa": "کیش و مات — شاه تو سقوط کرد."},
        "res_stalemate_lose": {"en": "STALEMATE - you have no legal moves.",
                "fa": "پات — تو حرکت مجازی نداری."},
        "res_white_wins": {"en": "WHITE WINS!", "fa": "سفید برد!"},
        "res_black_wins": {"en": "BLACK WINS!", "fa": "سیاه برد!"},
        "res_draw": {"en": "DRAW - STALEMATE", "fa": "مساوی — پات"},
        "res_mate_neutral": {"en": "CHECKMATE!", "fa": "کیش و مات!"},
        "res_stalemate_neutral": {"en": "Stalemate - neither side can move.", "fa": "پات — هیچ‌کدام حرکت مجازی ندارد."},
        "res_forfeit": {"en": "You forfeited the battle.", "fa": "نبرد را واگذار کردی."},
        "res_run_complete": {"en": "RUN COMPLETE!", "fa": "ران کامل شد!"},
        "res_run_failed": {"en": "RUN FAILED", "fa": "ران شکست خورد"},
        "res_reward": {"en": "Battle reward: %d coins", "fa": "جایزه نبرد: %d سکه"},
        "res_momentum": {"en": "MOMENTUM x%.2f", "fa": "شتاب x%.2f"},
        "res_treasure": {"en": "TREASURE HUNTER +50%", "fa": "شکارچی گنج +۵۰٪"},
        "res_total": {"en": "TOTAL: +%d coins", "fa": "مجموع: +%d سکه"},
        "res_battles": {"en": "Battles completed: %d", "fa": "نبردهای کامل‌شده: %d"},
        "res_coins_earned": {"en": "Coins earned: %d", "fa": "سکه‌های به‌دست‌آمده: %d"},
        "res_upgrades": {"en": "Upgrades: %s", "fa": "ارتقاها: %s"},
        "res_upgrades_battle": {"en": "Upgrades gained: %s", "fa": "ارتقاهای این نبرد: %s"},
        "res_none": {"en": "none", "fa": "هیچ"},
        "boss_fallen": {"en": "THE CORRUPTED KING HAS FALLEN!", "fa": "پادشاه فاسد سقوط کرد!"},
        "boss_title": {"en": "THE CORRUPTED KING", "fa": "پادشاه فاسد"},
        "boss_intro": {"en": "The final battle. The King's AI is stronger than any foe before it.\n\nCORRUPTION: %d cursed squares (purple) appeared - your pieces may never enter them.",
                "fa": "نبرد نهایی. هوش مصنوعی شاه از همه دشمنان قبلی قوی‌تر است.\n\nفساد: %d خانه نفرین‌شده (بنفش) ظاهر شد — مهره‌های تو هرگز نمی‌توانند وارد آن‌ها شوند."},
        "boss_begin": {"en": "BEGIN BATTLE", "fa": "شروع نبرد"},
        # ---- promotion ----
        "promo_title": {"en": "PROMOTE", "fa": "ارتقای سرباز"},
        "promo_text": {"en": "Your Pawn reaches the final rank!\nChoose a promotion:",
                "fa": "سربازت به آخرین ردیف رسید!\nانتخاب کن:"},
        # ---- capture / upgrades ----
        "cap_new_upgrade": {"en": "NEW UPGRADE: %s", "fa": "ارتقای جدید: %s"},
        "cap_pool_empty": {"en": "pool empty - +%d coins", "fa": "استخر خالی شد — +%d سکه"},
        "cap_coins": {"en": "+%d coins", "fa": "+%d سکه"},
        "cap_tap_icon": {"en": "%s\n%s", "fa": "%s\n%s"},
        "up_active": {"en": "ACTIVE", "fa": "فعال"},
        "up_none": {"en": "ACTIVE UPGRADES: none", "fa": "ارتقاهای فعال: هیچ"},
        "fx_iron_pawns": {"en": "IRON PAWNS! Your Pawn is shielded - the enemy redirects.",
                "fa": "سربازهای آهنی! سرباز تو محافظت شد — حریف مسیرش را عوض کرد."},
        "fx_second_chance": {"en": "SECOND CHANCE! Your last move was reverted.",
                "fa": "شانس دوم! آخرین حرکت تو برگشت."},
        "fx_guard_fired": {"en": "ROYAL GUARD! The Guard strikes down the enemy %s!",
                "fa": "گارد سلطنتی! گارد، %s حریف را نابود کرد!"},
        "fx_guard_saved": {"en": "ROYAL GUARD saved your King!", "fa": "گارد سلطنتی شاه تو را نجات داد!"},
        "fx_phoenix_saved": {"en": "PHOENIX FEATHER saved your King!", "fa": "پر فنیکس شاه تو را نجات داد!"},
        "fx_phoenix_fired": {"en": "PHOENIX FEATHER! The %s burns to ash!",
                "fa": "پر فنیکس! %s حریف خاکستر شد!"},
        "fx_lucky_start": {"en": "LUCKY START +%d coins", "fa": "شروع شانس‌آور +%d سکه"},
        "fx_knight_inspire": {"en": "KNIGHT INSPIRATION +%d coins", "fa": "الهام اسب +%d سکه"},
        "fx_inspire_chip": {"en": "KNIGHT INSPIRED", "fa": "اسب الهام‌یافته"},
        # ---- events ----
        "ev_title": {"en": "EVENT", "fa": "رویداد"},
        "ev_accept": {"en": "ACCEPT", "fa": "قبول"},
        "ev_decline": {"en": "DECLINE", "fa": "رد"},
        "ev_risk": {"en": "RISK", "fa": "ریسک"},
        "ev_safe": {"en": "SAFE", "fa": "امن"},
        "ev_recruit": {"en": "RECRUIT", "fa": "به خدمت بگیر"},
        "ev_leave": {"en": "LEAVE", "fa": "رها کن"},
        "ev_traveler_t": {"en": "MYSTERIOUS TRAVELER", "fa": "مسافر مرموز"},
        "ev_traveler_x": {"en": "A hooded traveler blocks the road.\n\n\"Turns are cheap, victories are not. Care to make a deal?\"",
                "fa": "مسافری با ردایی سرمه‌ای راه را سد می‌کند.\n\n«بخت ارزان است، پیروزی نه. حاضری معامله کنیم؟»"},
        "ev_traveler_ar": {"en": "The traveler tosses you a small pouch of coins and vanishes into the mist.",
                "fa": "مسافر کیسه‌ای سکه به سمتت پرت می‌کند و در مه محو می‌شود."},
        "ev_traveler_dr": {"en": "You keep walking. The traveler's silhouette fades behind you.",
                "fa": "به راهت ادامه می‌دهی. سایهٔ مسافر پشت سرت محو می‌شود."},
        "ev_risky_t": {"en": "RISKY CHALLENGE", "fa": "چالش پرخطر"},
        "ev_risky_x": {"en": "A scarred veteran points at a ruined watchtower.\n\n\"Chest's up there. So is a trap. Feeling lucky?\"",
                "fa": "کهنسالی زخم‌خورده به برج دیده‌بانی خراب اشاره می‌کند.\n\n«صندوق اون بالاست. تله هم هست. شانستو امتحان می‌کنی؟»"},
        "ev_risky_r": {"en": "You dodge the trap by a hair and haul back a heavy chest of coins!",
                "fa": "با نهایت دقت از تله می‌گریزی و صندوق سنگینی از سکه برمی‌گردانی!"},
        "ev_risky_s": {"en": "You circle around the tower. Better safe than sorry.",
                "fa": "از کنار برج دور می‌زنی. احتیاط شرط عقل است."},
        "ev_knight_t": {"en": "LOST KNIGHT", "fa": "اسب گمشده"},
        "ev_knight_x": {"en": "A knight in dented armor kneels in the mud, separated from his army.\n\n\"Let me ride with you. My lance is still sharp.\"",
                "fa": "سربازی با زره‌ی فرورفته در گِل زانو زده، از لشکرش جدا شده.\n\n«بذار با تو بیام. نیزه‌ام هنوز تیز است.»"},
        "ev_knight_r": {"en": "The knight joins your cause! In your NEXT battle, Knight captures earn bonus coins.",
                "fa": "اسب به صف تو می‌پیوندد! در نبرد بعدی‌ات، هر گرفتن با اسب سکهٔ جایزه دارد."},
        "ev_knight_l": {"en": "You point him toward the horizon and ride on alone.",
                "fa": "به سمت افق اشاره می‌کنی و تنها به راهت ادامه می‌دهی."},
        "ev_knight_r_eff": {"en": "KNIGHT INSPIRATION granted for your next battle!",
                "fa": "الهام اسب برای نبرد بعدی فعال شد!"},
        # ---- pieces ----
        "p_pawn": {"en": "Pawn", "fa": "سرباز"},
        "p_knight": {"en": "Knight", "fa": "اسب"},
        "p_bishop": {"en": "Bishop", "fa": "فیل"},
        "p_rook": {"en": "Rook", "fa": "رخ"},
        "p_queen": {"en": "Queen", "fa": "وزیر"},
        "p_king": {"en": "King", "fa": "شاه"},
        # ---- upgrade names ----
        "up_coin_purse": {"en": "COIN PURSE", "fa": "کیسه سکه"},
        "up_pawn_tax": {"en": "PAWN TAX", "fa": "مالیات سرباز"},
        "up_brave_pawns": {"en": "BRAVE PAWNS", "fa": "سربازان دلیر"},
        "up_lucky_start": {"en": "LUCKY START", "fa": "شروع شانس‌آور"},
        "up_knight_fury": {"en": "KNIGHT FURY", "fa": "خشم اسب"},
        "up_bishop_tithe": {"en": "BISHOP'S TITHE", "fa": "نذر فیل"},
        "up_treasure_hunter": {"en": "TREASURE HUNTER", "fa": "شکارچی گنج"},
        "up_second_chance": {"en": "SECOND CHANCE", "fa": "شانس دوم"},
        "up_sharp_eye": {"en": "SHARP EYE", "fa": "چشم تیزبین"},
        "up_momentum": {"en": "MOMENTUM", "fa": "شتاب"},
        "up_iron_pawns": {"en": "IRON PAWNS", "fa": "سربازهای آهنی"},
        "up_royal_guard": {"en": "ROYAL GUARD", "fa": "گارد سلطنتی"},
        "up_war_chest": {"en": "WAR CHEST", "fa": "خزانه جنگ"},
        "up_terror": {"en": "TERROR", "fa": "هراس"},
        "up_royal_decree": {"en": "ROYAL DECREE", "fa": "فرمان سلطنتی"},
        "up_phoenix": {"en": "PHOENIX FEATHER", "fa": "پر فنیکس"},
        "up_midas": {"en": "MIDAS TOUCH", "fa": "دست میداس"},
        # ---- upgrade descriptions ----
        "up_coin_purse_d": {"en": "+8 coins after every battle victory.", "fa": "بعد از هر پیروزی +۸ سکه."},
        "up_pawn_tax_d": {"en": "+2 coins every time any of your pieces captures.", "fa": "هر بار که هر کدام از مهره‌هایت بگیرد +۲ سکه."},
        "up_brave_pawns_d": {"en": "+4 coins for each capture made by a Pawn.", "fa": "برای هر گرفتن با سرباز +۴ سکه."},
        "up_lucky_start_d": {"en": "+12 coins at the start of every battle.", "fa": "در شروع هر نبرد +۱۲ سکه."},
        "up_knight_fury_d": {"en": "+6 coins for each capture made by a Knight.", "fa": "برای هر گرفتن با اسب +۶ سکه."},
        "up_bishop_tithe_d": {"en": "+6 coins for each capture made by a Bishop.", "fa": "برای هر گرفتن با فیل +۶ سکه."},
        "up_treasure_hunter_d": {"en": "Coins from battle victories are increased by 50%.", "fa": "سکه‌های پیروزی نبرد ۵۰٪ بیشتر می‌شود."},
        "up_second_chance_d": {"en": "Grants 1 UNDO token. Use it to revert your last move.", "fa": "۱ توکن برگرداندن می‌دهد تا آخرین حرکتت را برگردانی."},
        "up_sharp_eye_d": {"en": "The enemy AI becomes sloppier (noisier evaluation).", "fa": "هوش مصنوعی حریف بی‌دقت‌تر می‌شود."},
        "up_momentum_d": {"en": "Each consecutive victory raises your coin multiplier by +25%.", "fa": "هر پیروزی پشت‌سرهم، ضریب سکه‌ات را ۲۵٪ زیاد می‌کند."},
        "up_iron_pawns_d": {"en": "Once per battle: the enemy's pawn capture is blocked and it must play elsewhere.", "fa": "هر نبرد یک بار: گرفتن سربازت توسط حریف مسدود می‌شود و باید جای دیگر بازی کند."},
        "up_royal_guard_d": {"en": "Once per run: survive a checkmate - the attacking piece is destroyed.", "fa": "هر ران یک بار: از کیش‌ومات جان سالم به در می‌بری — مهره مهاجم نابود می‌شود."},
        "up_war_chest_d": {"en": "All coin gains are increased by +25%.", "fa": "همه سکه‌های به‌دست‌آمده ۲۵٪ بیشتر می‌شود."},
        "up_terror_d": {"en": "Enemy blunder chance +8%. Fear clouds their judgment.", "fa": "شانس اشتباه حریف +۸٪. ترس داوری‌شان را تار می‌کند."},
        "up_royal_decree_d": {"en": "Every battle, one of your pawns takes the field as an extra QUEEN.", "fa": "در هر نبرد، یکی از سربازهایت به‌جای سرباز، وزیر اضافه است."},
        "up_phoenix_d": {"en": "Once per BATTLE: survive a checkmate - the attacker burns to ash.", "fa": "هر نبرد یک بار: از کیش‌ومات جان سالم به در می‌بری — مهاجم می‌سوزد."},
        "up_midas_d": {"en": "ALL coin gains are doubled (x2).", "fa": "همه سکه‌های به‌دست‌آمده دو برابر (×۲) می‌شود."},
}


func _ready() -> void:
        lang = SaveManager.language
        _install_font()


func set_language(code: String) -> void:
        lang = code if code in ["en", "fa"] else "en"


func is_rtl() -> bool:
        return lang == "fa"


## Display label for a map node (battle number, event, boss, start).
func node_label(node: Dictionary) -> String:
        match String(node.get("type", "battle")):
                "battle":
                        return String(t("map_battle")) % int(node.get("n", 0))
                "event":
                        return t("map_event")
                "boss":
                        return t("map_boss")
                _:
                        return t("map_start")


## Description paragraph for a map node.
func node_desc(node: Dictionary) -> String:
        var typ := String(node.get("type", "battle"))
        if typ == "battle":
                var key := "node_desc_battle_hard" if bool(node.get("hard", false)) else "node_desc_battle"
                return fmt(key, [int(node.get("coins", 10))])
        if typ == "boss":
                return fmt("node_desc_boss", [int(node.get("coins", 50))])
        if typ == "event":
                return t("node_desc_event")
        return t("node_desc_start")


## Translate a key. Falls back to English, then to the key itself.
func t(key: String) -> String:
        var entry: Dictionary = STRINGS.get(key, {})
        if entry.is_empty():
                return key
        return String(entry.get(lang, entry.get("en", key)))


## Translate + format.
func fmt(key: String, args: Array) -> String:
        return String(t(key)) % args


func font_regular() -> FontFile:
        return load(FONT_REGULAR)


func font_bold() -> FontFile:
        return load(FONT_BOLD)


func _install_font() -> void:
        var theme := Theme.new()
        theme.default_font = load(FONT_REGULAR)
        get_tree().root.theme = theme
