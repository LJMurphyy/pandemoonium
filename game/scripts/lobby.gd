extends Control
## Host lobby for the laptop / TV screen, following the "PandeMOOnium Lobby" design:
## title -> connecting -> room (waiting / all ready) -> lost connection.
## Built in code (like main.gd). Talks to NetworkManager directly. Main only hears
## `create_requested`, so it can clear the old round, and hides nothing itself:
## the lobby hides on game_started and comes back if the connection is lost.

signal create_requested

const ONLINE_SERVER := "wss://pandemoonium.onrender.com/ws"
const LOCAL_SERVER := "ws://127.0.0.1:3000/ws"
## The server holds a dropped phone's slot this long (RECONNECT_MS in server/index.js).
const RECONNECT_SECS := 30.0

# Palette from the design's style sheet.
const BG := Color("24150E")
const BLOB := Color("2E1B12")
const PANEL := Color("3A2418")
const LINE := Color("5A3A28")
const CREAM := Color("FFF6E8")
const LATTE := Color("F6D9A8")
const MUTED := Color("B89A82")
const LEDGE := Color("C9A57A")
const INK := Color("120A06")
const RED := Color("FF6B5B")
const PLAYER_COLORS := [Color("ffbd69"), Color("72d6ba"), Color("8eafff"), Color("ff8ab0")]
const BREW_STEPS := ["Grinding the beans…", "Steaming the milk…", "Pulling the shot…", "Frothing the foam…"]

const COW_SVG := """<svg xmlns="http://www.w3.org/2000/svg" width="200" height="190" viewBox="0 0 200 190">
<path d="M66 50 C54 40 46 30 48 16 C58 22 66 30 76 42 Z" fill="#F6D9A8" stroke="#120A06" stroke-width="5" stroke-linejoin="round"/>
<path d="M134 50 C146 40 154 30 152 16 C142 22 134 30 124 42 Z" fill="#F6D9A8" stroke="#120A06" stroke-width="5" stroke-linejoin="round"/>
<ellipse cx="34" cy="86" rx="30" ry="16" transform="rotate(-18 34 86)" fill="#FFF6E8" stroke="#120A06" stroke-width="5"/>
<ellipse cx="166" cy="86" rx="30" ry="16" transform="rotate(18 166 86)" fill="#FFF6E8" stroke="#120A06" stroke-width="5"/>
<ellipse cx="37" cy="86" rx="15" ry="6" transform="rotate(-18 37 86)" fill="#FF8AB0"/>
<ellipse cx="163" cy="86" rx="15" ry="6" transform="rotate(18 163 86)" fill="#FF8AB0"/>
<rect x="52" y="40" width="96" height="120" rx="46" fill="#FFF6E8" stroke="#120A06" stroke-width="5"/>
<path d="M57 74 C58 58 76 52 88 60 C96 68 90 84 76 88 C64 91 56 86 57 74 Z" fill="#24150E"/>
<path d="M122 56 C134 52 144 60 143 72 C136 76 125 72 122 64 Z" fill="#24150E"/>
<circle cx="80" cy="102" r="7" fill="#120A06"/>
<circle cx="120" cy="102" r="7" fill="#120A06"/>
<circle cx="82" cy="99" r="2.5" fill="#FFF6E8"/>
<circle cx="122" cy="99" r="2.5" fill="#FFF6E8"/>
<rect x="58" y="120" width="84" height="54" rx="27" fill="#FFB3C7" stroke="#120A06" stroke-width="5"/>
<ellipse cx="84" cy="142" rx="6" ry="8" fill="#120A06"/>
<ellipse cx="116" cy="142" rx="6" ry="8" fill="#120A06"/>
<path d="M88 160 Q100 168 112 160" stroke="#120A06" stroke-width="4" fill="none" stroke-linecap="round"/>
<path d="M64 46 L136 46 L128 20 L72 20 Z" fill="#8A5A3B" stroke="#120A06" stroke-width="5" stroke-linejoin="round"/>
<rect x="88" y="27" width="24" height="10" rx="5" fill="#FFBD69"/>
</svg>"""

const MACHINE_SVG := """<svg xmlns="http://www.w3.org/2000/svg" width="220" height="220" viewBox="0 0 220 220">
<defs><clipPath id="glassClip"><path d="M88 140 H132 L127 188 Q126 192 122 192 H98 Q94 192 93 188 Z"/></clipPath></defs>
<rect x="46" y="6" width="128" height="14" rx="7" fill="#8A5A3B" stroke="#120A06" stroke-width="4"/>
<rect x="24" y="16" width="172" height="198" rx="24" fill="#FFF6E8" stroke="#120A06" stroke-width="5"/>
<path d="M36 46 C38 32 58 28 66 37 C72 46 63 57 51 57 C41 57 35 53 36 46 Z" fill="#24150E"/>
<path d="M172 150 C180 145 189 156 185 168 C177 172 168 164 172 150 Z" fill="#24150E"/>
<circle cx="84" cy="48" r="5" fill="#ffbd69" stroke="#120A06" stroke-width="2.5"/>
<circle cx="98" cy="48" r="5" fill="#72d6ba" stroke="#120A06" stroke-width="2.5"/>
<circle cx="112" cy="48" r="5" fill="#8eafff" stroke="#120A06" stroke-width="2.5"/>
<circle cx="126" cy="48" r="5" fill="#ff8ab0" stroke="#120A06" stroke-width="2.5"/>
<circle cx="154" cy="48" r="17" fill="#F6D9A8" stroke="#120A06" stroke-width="4"/>
<line x1="154" y1="48" x2="162" y2="38" stroke="#FF6B5B" stroke-width="4" stroke-linecap="round"/>
<circle cx="154" cy="48" r="3.5" fill="#120A06"/>
<rect x="54" y="74" width="112" height="128" rx="16" fill="#3A2418" stroke="#120A06" stroke-width="5"/>
<path d="M104 100 V176" stroke="#C98A55" stroke-width="4" stroke-linecap="round" stroke-dasharray="6 5"/>
<path d="M116 100 V176" stroke="#C98A55" stroke-width="4" stroke-linecap="round" stroke-dasharray="6 5"/>
<rect x="84" y="74" width="52" height="14" rx="3" fill="#5A3A28" stroke="#120A06" stroke-width="4"/>
<rect x="78" y="88" width="64" height="12" rx="6" fill="#24150E" stroke="#120A06" stroke-width="4"/>
<rect x="140" y="90" width="46" height="8" rx="4" fill="#120A06"/>
<rect x="66" y="192" width="88" height="6" rx="3" fill="#5A3A28"/>
<g clip-path="url(#glassClip)"><rect x="86" y="160" width="48" height="34" fill="#8A5A3B"/><rect x="86" y="160" width="48" height="7" fill="#E8C49A"/></g>
<path d="M88 140 H132 L127 188 Q126 192 122 192 H98 Q94 192 93 188 Z" fill="#FFF6E8" fill-opacity="0.08" stroke="#FFF6E8" stroke-width="4" stroke-linejoin="round"/>
<path d="M95 148 L98 180" stroke="#FFF6E8" stroke-width="3" stroke-linecap="round" opacity="0.6"/>
</svg>"""

const SPILL_SVG := """<svg xmlns="http://www.w3.org/2000/svg" width="270" height="160" viewBox="0 0 270 160">
<ellipse cx="80" cy="140" rx="70" ry="13" fill="#8A5A3B"/>
<ellipse cx="22" cy="148" rx="9" ry="4" fill="#8A5A3B"/>
<circle cx="40" cy="116" r="5" fill="#8A5A3B"/>
<circle cx="58" cy="104" r="3.5" fill="#8A5A3B"/>
<g transform="translate(150 104) rotate(-90) scale(1.8) translate(-32 -46)">
<path d="M13 28 H51 L46.6 64 Q46.2 68 42.2 68 H21.8 Q17.8 68 17.4 64 Z" fill="#FFF6E8" stroke="#120A06" stroke-width="3" stroke-linejoin="round"/>
<path d="M38 32 c2 -2.5 6.5 -1.5 6 1.5 c-0.5 3 -6.5 2.5 -6 -1.5 z" fill="#24150E"/>
<path d="M14.4 39 H49.6 L47.8 54 H16.2 Z" fill="#FF6B5B" stroke="#120A06" stroke-width="3" stroke-linejoin="round"/>
<path d="M20.5 58 c1.5 -3 7.5 -2.5 7 0.5 c-0.5 3.5 -6.5 3.5 -7 -0.5 z" fill="#24150E"/>
</g>
<ellipse cx="114" cy="104" rx="7" ry="33" fill="#24150E" stroke="#120A06" stroke-width="4"/>
<path d="M110 120 Q106 134 90 140 L122 141 Q118 132 116 122 Z" fill="#8A5A3B"/>
<g transform="translate(228 146) rotate(16) scale(1.5) translate(-32 -22)">
<path d="M18 22 L20.5 16 H43.5 L46 22 Z" fill="#5A3A28" stroke="#120A06" stroke-width="3" stroke-linejoin="round"/>
<rect x="10" y="21" width="44" height="8" rx="4" fill="#5A3A28" stroke="#120A06" stroke-width="3"/>
<rect x="27" y="17.5" width="10" height="2.5" rx="1.25" fill="#120A06"/>
</g>
</svg>"""

const CHECK_SVG := """<svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 20 20"><path d="M4 10.5 L8.5 15 L16 6" stroke="{color}" stroke-width="3.5" fill="none" stroke-linecap="round" stroke-linejoin="round"/></svg>"""
const LOCK_SVG := """<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24"><rect x="4" y="10" width="16" height="12" rx="3" fill="#B89A82"/><path d="M8 10 V7 a4 4 0 0 1 8 0 V10" stroke="#B89A82" stroke-width="2.6" fill="none"/></svg>"""
const PLAY_SVG := """<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24"><path d="M7 4.5 L19 12 L7 19.5 Z" fill="#24150E" stroke="#24150E" stroke-width="2.5" stroke-linejoin="round"/></svg>"""
const RETRY_SVG := """<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24"><path d="M19 12 a7 7 0 1 1 -2.05 -4.95" stroke="#24150E" stroke-width="3" fill="none" stroke-linecap="round"/><path d="M19.5 3.5 V8 H15" stroke="#24150E" stroke-width="3" fill="none" stroke-linecap="round" stroke-linejoin="round"/></svg>"""
const CHEVRON_SVG := """<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 16 16"><path d="{path}" stroke="#B89A82" stroke-width="2.5" fill="none" stroke-linecap="round" stroke-linejoin="round"/></svg>"""

var f_medium: Font
var f_semi: Font
var f_bold: Font
var f_caps: Font
var f_title: Font
var f_mono: Font

var screens: Dictionary = {}
var server_url := ""
var got_room := false
var roster: Array = []
var disc_since: Dictionary = {} # player number -> time (sec) we first saw them offline
var error_text := ""
var error_until := 0.0
var connect_started := 0.0
var start_sent := false
var cow_textures: Array[Texture2D] = []
var cow_grey: Array[Texture2D] = []
var cow_empty: Texture2D

# Title
var address: LineEdit
var adv_button: Button
var adv_panel: Control
var chevron_down: Texture2D
var chevron_up: Texture2D
# Connecting
var brew_text: Label
var brew_bar: ProgressBar
var brew_step: Label
var brew_time: Label
# Room
var url_label: Label
var code_labels: Array[Label] = []
var slots: Array[Dictionary] = []
var hint_label: Label
var count_label: Label
var start_locked: Button
var start_halo: Control
var reconnect_pill: Control
# Lost connection
var lost_heading: Label
var lost_text: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_load_assets()
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	# Soft coffee-stain blobs behind everything.
	_blob(Rect2(-60, -40, 260, 200), false, [110, 90, 100, 80])
	_blob(Rect2(-180, 120, 220, 260), true, [90, 110, 120, 80])
	_blob(Rect2(80, 610, 300, 190), false, [120, 70, 90, 110])
	_blob(Rect2(-250, 600, 110, 80), true, [40, 40, 30, 45])
	_build_title()
	_build_connecting()
	_build_room()
	_build_lost()
	NetworkManager.message_received.connect(_on_message)
	NetworkManager.disconnected.connect(_on_disconnected)
	_show("title")


func _process(_delta: float) -> void:
	if screens["connecting"].visible:
		var t := _now() - connect_started
		brew_bar.value = 100.0 * (1.0 - exp(-t / 20.0)) * 0.95
		brew_step.text = BREW_STEPS[int(t / 4.0) % BREW_STEPS.size()]
		brew_time.text = "%d:%02d" % [int(t) / 60, int(t) % 60]
	elif screens["room"].visible:
		reconnect_pill.visible = NetworkManager.retrying
		for n in disc_since.keys():
			var secs := maxi(0, ceili(RECONNECT_SECS - (_now() - float(disc_since[n]))))
			var s: Dictionary = slots[int(n) - 1]
			(s["pill_label"] as Label).text = "RECONNECTING · %ds" % secs
			(s["bar"] as ProgressBar).value = 100.0 * secs / RECONNECT_SECS
		if not error_text.is_empty() and _now() > error_until:
			error_text = ""
			_refresh_room()


# --- Network ---------------------------------------------------------------

func _create_room() -> void:
	server_url = address.text.strip_edges()
	if server_url.is_empty():
		server_url = _default_server()
		address.text = server_url
	got_room = false
	roster = []
	disc_since.clear()
	error_text = ""
	start_sent = false
	create_requested.emit()
	var err := NetworkManager.connect_to_server(server_url)
	if err != OK:
		_show_lost("Couldn't reach the server", "That server address didn't work (%s). Check it under Advanced." % error_string(err))
		return
	connect_started = _now()
	if server_url.contains("onrender.com"):
		brew_text.text = "The CoHo server naps when it's quiet. Waking it up can take up to a minute."
	else:
		brew_text.text = "Connecting to " + server_url.get_slice("://", 1).get_slice("/", 0) + "…"
	_show("connecting")


func _cancel_connect() -> void:
	NetworkManager.leave()
	_show("title")


func _start_game() -> void:
	start_sent = true
	NetworkManager.send_message({"type": "start_game"})
	_refresh_room()


func _on_message(msg: Dictionary) -> void:
	match str(msg.get("type", "")):
		"room_created":
			got_room = true
			var code := str(msg.get("code", ""))
			for i in range(code_labels.size()):
				code_labels[i].text = code[i] if i < code.length() else "-"
			url_label.text = _phone_url()
			_show("room")
			_refresh_room()
		"players":
			roster = msg.get("players", [])
			_refresh_room()
		"game_started":
			visible = false
		"error":
			error_text = str(msg.get("message", "Something went wrong."))
			error_until = _now() + 5.0
			start_sent = false
			_refresh_room()


func _on_disconnected() -> void:
	visible = true
	if got_room:
		_show_lost("Lost connection to server", "The room has closed. Check this laptop's Wi-Fi, then make a new room.")
	elif server_url.contains("127.0.0.1") or server_url.contains("localhost"):
		_show_lost("Couldn't reach the server", "Start it with npm start in the server folder, then retry.")
	else:
		_show_lost("Couldn't reach the server", "Check this laptop's Wi-Fi and the server address under Advanced, then retry.")


func _show_lost(heading: String, text: String) -> void:
	lost_heading.text = heading
	lost_text.text = text
	_show("lost")


## Where phones should go, based on the server this game connected to.
func _phone_url() -> String:
	var host := server_url.get_slice("://", 1).get_slice("/", 0)
	if host.begins_with("127.0.0.1") or host.begins_with("localhost"):
		var port := host.get_slice(":", 1) if ":" in host else "3000"
		return "http://%s:%s" % [_lan_ip(), port]
	return host if server_url.begins_with("wss://") else "http://" + host


func _lan_ip() -> String:
	var fallback := "YOUR-PC-IP"
	for ip in IP.get_local_addresses():
		if ip.contains(":") or ip.begins_with("127.") or ip.begins_with("169.254."):
			continue
		if ip.begins_with("192.168.") or ip.begins_with("10.") or ip.begins_with("172."):
			return ip
		if fallback == "YOUR-PC-IP":
			fallback = ip
	return fallback


## Always the online server, even from the editor. For a local relay (`npm start` in server/),
## type LOCAL_SERVER into Advanced.
func _default_server() -> String:
	return ONLINE_SERVER


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


# --- Room state ------------------------------------------------------------

func _refresh_room() -> void:
	var by_number := {}
	for entry in roster:
		by_number[int(entry.get("number", 0))] = entry
	var ready_count := 0
	var offline := 0
	var everyone_ready := true
	for i in range(4):
		var n := i + 1
		var state := "empty"
		if by_number.has(n):
			var e: Dictionary = by_number[n]
			if not e.get("connected", false):
				state = "disc"
			elif e.get("ready", false):
				state = "ready"
			else:
				state = "joined"
		if state == "disc":
			offline += 1
			if not disc_since.has(n):
				disc_since[n] = _now()
		else:
			disc_since.erase(n)
		if state == "ready":
			ready_count += 1
		elif state != "empty":
			everyone_ready = false
		_apply_slot(i, state)
	var can_start := roster.size() >= 2 and everyone_ready and not start_sent
	start_locked.visible = not can_start
	start_halo.visible = can_start
	count_label.visible = roster.size() > 0
	count_label.text = "%d / %d ready" % [ready_count, roster.size()]
	if not error_text.is_empty():
		hint_label.text = error_text
	elif start_sent:
		hint_label.text = "Starting…"
	elif roster.is_empty():
		hint_label.text = "Waiting for players. You need 2 to 4."
	elif roster.size() == 1:
		hint_label.text = "Need at least one more player."
	elif offline > 0:
		hint_label.text = "Waiting for a player to reconnect."
	elif not everyone_ready:
		hint_label.text = "Waiting for everyone to tap I'm Ready."
	else:
		hint_label.text = "Everyone's ready!"


func _apply_slot(i: int, state: String) -> void:
	var s: Dictionary = slots[i]
	var c: Color = PLAYER_COLORS[i]
	var card: StyleBoxFlat
	var badge: StyleBoxFlat
	var badge_color := c
	match state:
		"empty":
			card = _bordered(_box(BLOB, 24), 4, PANEL)
			badge = _box(PANEL, 16)
		"joined":
			card = _bordered(_box(PANEL, 24), 4, c)
			badge = _box(c, 16)
			badge_color = BG
		"ready":
			card = _ledge(_box(c, 24), 8, INK)
			badge = _box(BG, 16)
		_:
			card = _bordered(_box(BLOB, 24), 4, LINE)
			badge = _box(PANEL, 16)
			badge_color = MUTED
	(s["panel"] as Panel).add_theme_stylebox_override("panel", card)
	(s["badge"] as PanelContainer).add_theme_stylebox_override("panel", _pad(badge, 10, 0))
	(s["badge_label"] as Label).add_theme_color_override("font_color", badge_color)
	# Pixel-art cows drawn at 3x. Offline players get a dimmed grey cow.
	var cow: TextureRect = s["cow"]
	cow.texture = cow_empty if state == "empty" else cow_grey[i] if state == "disc" else cow_textures[i]
	cow.custom_minimum_size = cow.texture.get_size() * 3.0
	cow.modulate = Color(0.6, 0.6, 0.6, 0.75) if state == "disc" else Color.WHITE
	(s["empty_label"] as Label).visible = state == "empty"
	var name_label: Label = s["name_label"]
	name_label.visible = state != "empty"
	name_label.add_theme_color_override("font_color", BG if state == "ready" else MUTED if state == "disc" else CREAM)
	var pill: PanelContainer = s["pill"]
	var pill_label: Label = s["pill_label"]
	var pill_icon: TextureRect = s["pill_icon"]
	pill.visible = state != "empty"
	pill_icon.visible = state == "ready"
	(s["bar"] as ProgressBar).visible = state == "disc"
	pill_label.add_theme_font_size_override("font_size", 16 if state == "disc" else 17)
	match state:
		"joined":
			pill.add_theme_stylebox_override("panel", _pad(_bordered(_box(Color.TRANSPARENT, 18), 3, LINE), 14, 0))
			pill_label.text = "NOT READY"
			pill_label.add_theme_color_override("font_color", MUTED)
		"ready":
			var st := _box(BG, 18)
			st.content_margin_left = 10
			st.content_margin_right = 14
			pill.add_theme_stylebox_override("panel", st)
			pill_label.text = "READY"
			pill_label.add_theme_color_override("font_color", c)
			pill_icon.texture = _svg(CHECK_SVG.format({"color": "#" + c.to_html(false)}))
		"disc":
			pill.add_theme_stylebox_override("panel", _pad(_box(PANEL, 18), 12, 0))
			pill_label.text = "RECONNECTING · %ds" % int(RECONNECT_SECS)
			pill_label.add_theme_color_override("font_color", RED)


func _show(which: String) -> void:
	for key in screens.keys():
		screens[key].visible = key == which


# --- Screens ---------------------------------------------------------------

func _build_title() -> void:
	var screen := _screen("title")
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.add_child(center)
	var col := _vbox(0)
	center.add_child(col)
	_bobbing(col, _svg(COW_SVG), Vector2(150, 142), 8.0, 2.4)
	_gap(col, 6)
	col.add_child(_centered(_label("PandeMOOnium", f_title, 104, CREAM, 8)))
	_gap(col, 14)
	col.add_child(_centered(_label("Three baristas. One saboteur. Hella fun.", f_semi, 26, LATTE)))
	_gap(col, 40)
	var create := _button("Create Room", f_title, 42, BG, _ledge(_box(CREAM, 24), 8, LEDGE), Vector2(400, 96))
	create.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	create.pressed.connect(_create_room)
	col.add_child(create)
	_gap(col, 22)
	col.add_child(_centered(_label("2–4 players", f_semi, 18, MUTED)))
	_gap(col, 6)
	chevron_down = _svg(CHEVRON_SVG.format({"path": "M3 6 L8 11 L13 6"}))
	chevron_up = _svg(CHEVRON_SVG.format({"path": "M3 10 L8 5 L13 10"}))
	adv_button = _button("Advanced", f_semi, 18, MUTED, _box(Color.TRANSPARENT, 12), Vector2(140, 44), chevron_down, 16, true)
	adv_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	adv_button.pressed.connect(func():
		adv_panel.visible = not adv_panel.visible
		(adv_button.get_meta("icon_rect") as TextureRect).texture = chevron_up if adv_panel.visible else chevron_down)
	col.add_child(adv_button)
	_gap(col, 6)
	adv_panel = PanelContainer.new()
	adv_panel.add_theme_stylebox_override("panel", _pad(_box(PANEL, 20), 20, 16))
	adv_panel.custom_minimum_size.x = 540
	adv_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	adv_panel.visible = false
	col.add_child(adv_panel)
	var adv := _vbox(8)
	adv_panel.add_child(adv)
	adv.add_child(_label("SERVER ADDRESS", f_caps, 16, LATTE))
	var row := _hbox(10)
	adv.add_child(row)
	address = LineEdit.new()
	address.text = _default_server()
	address.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	address.custom_minimum_size.y = 48
	address.add_theme_font_override("font", f_mono)
	address.add_theme_font_size_override("font_size", 16)
	address.add_theme_color_override("font_color", CREAM)
	address.add_theme_color_override("caret_color", CREAM)
	address.add_theme_stylebox_override("normal", _pad(_bordered(_box(BG, 12), 3, LINE), 14, 0))
	address.add_theme_stylebox_override("focus", _pad(_bordered(_box(BG, 12), 3, LATTE), 14, 0))
	address.text_submitted.connect(func(_t: String): _create_room())
	row.add_child(address)
	var reset := _button("Reset", f_semi, 16, LATTE, _pad(_bordered(_box(Color.TRANSPARENT, 12), 3, LINE), 18, 0), Vector2(0, 48))
	reset.pressed.connect(func(): address.text = _default_server())
	row.add_child(reset)


func _build_connecting() -> void:
	var screen := _screen("connecting")
	var col := _page(screen)
	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(center)
	var body := _vbox(0)
	center.add_child(body)
	_bobbing(body, _svg(MACHINE_SVG), Vector2(184, 184), 4.0, 1.6)
	_gap(body, 22)
	body.add_child(_centered(_label("Brewing the server…", f_title, 64, CREAM, 6)))
	_gap(body, 18)
	brew_text = _centered(_label("", f_medium, 24, LATTE))
	brew_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	brew_text.custom_minimum_size.x = 620
	body.add_child(brew_text)
	_gap(body, 28)
	var progress := _vbox(10)
	progress.custom_minimum_size.x = 520
	progress.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	body.add_child(progress)
	brew_bar = _bar(CREAM, PANEL, 20)
	progress.add_child(brew_bar)
	var row := _hbox(0)
	progress.add_child(row)
	brew_step = _label("", f_semi, 18, MUTED)
	brew_step.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(brew_step)
	brew_time = _label("0:00", f_mono, 18, MUTED)
	row.add_child(brew_time)
	_gap(body, 28)
	var cancel := _button("Cancel", f_semi, 22, CREAM, _pad(_bordered(_box(Color.TRANSPARENT, 20), 4, LINE), 36, 0), Vector2(0, 64))
	cancel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cancel.pressed.connect(_cancel_connect)
	body.add_child(cancel)
	_gap(col, 40)


func _build_room() -> void:
	var screen := _screen("room")
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in [["left", 32], ["top", 28], ["right", 32], ["bottom", 32]]:
		margin.add_theme_constant_override("margin_" + side[0], side[1])
	screen.add_child(margin)
	var col := _vbox(16)
	margin.add_child(col)

	var header := _hbox(16)
	header.custom_minimum_size.y = 52
	col.add_child(header)
	header.add_child(_logo())
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	reconnect_pill = PanelContainer.new()
	reconnect_pill.add_theme_stylebox_override("panel", _pad(_box(PANEL, 18), 16, 6))
	reconnect_pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	reconnect_pill.add_child(_label("Reconnecting to server…", f_bold, 18, RED))
	reconnect_pill.visible = false
	header.add_child(reconnect_pill)

	var join := PanelContainer.new()
	var join_style := _box(PANEL, 28)
	join_style.content_margin_left = 26
	join_style.content_margin_top = 20
	join_style.content_margin_right = 24
	join_style.content_margin_bottom = 22
	join.add_theme_stylebox_override("panel", join_style)
	col.add_child(join)
	var steps := _vbox(12)
	join.add_child(steps)
	var row1 := _hbox(14)
	steps.add_child(row1)
	row1.add_child(_step("1"))
	row1.add_child(_label("Go to", f_semi, 22, LATTE))
	url_label = _label("", f_bold, 30, CREAM)
	url_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	url_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row1.add_child(url_label)
	var row2 := _hbox(14)
	steps.add_child(row2)
	row2.add_child(_step("2"))
	row2.add_child(_label("Enter the room code", f_semi, 22, LATTE))
	var code_margin := MarginContainer.new()
	code_margin.add_theme_constant_override("margin_left", 50)
	code_margin.add_theme_constant_override("margin_bottom", 6)
	steps.add_child(code_margin)
	var code_row := _hbox(12)
	code_margin.add_child(code_row)
	for i in range(6):
		var tile := PanelContainer.new()
		tile.custom_minimum_size = Vector2(76, 96)
		tile.add_theme_stylebox_override("panel", _ledge(_box(CREAM, 16), 6, LEDGE))
		code_row.add_child(tile)
		var letter := _label("-", f_mono, 60, BG)
		letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		tile.add_child(letter)
		code_labels.append(letter)

	var players := _hbox(16)
	players.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(players)
	for i in range(4):
		slots.append(_make_slot(players, i))

	var footer := _hbox(24)
	footer.custom_minimum_size.y = 112
	col.add_child(footer)
	hint_label = _label("", f_semi, 19, LATTE)
	hint_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	footer.add_child(hint_label)
	count_label = _label("", f_title, 38, CREAM)
	count_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	footer.add_child(count_label)
	start_locked = _button("Start Game", f_title, 34, MUTED, _bordered(_box(BLOB, 24), 4, LINE), Vector2(320, 80), _svg(LOCK_SVG), 26)
	start_locked.disabled = true
	start_locked.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	footer.add_child(start_locked)
	start_halo = PanelContainer.new()
	start_halo.add_theme_stylebox_override("panel", _pad(_box(Color(CREAM, 0.16), 32), 8, 8))
	start_halo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	start_halo.visible = false
	footer.add_child(start_halo)
	var start := _button("Start Game", f_title, 46, BG, _ledge(_box(CREAM, 24), 8, LEDGE), Vector2(400, 92), _svg(PLAY_SVG), 34)
	start.pressed.connect(_start_game)
	start_halo.add_child(start)
	start_halo.resized.connect(func(): start_halo.pivot_offset = start_halo.size / 2.0)
	var pulse := start_halo.create_tween().set_loops()
	pulse.tween_property(start_halo, "scale", Vector2(1.04, 1.04), 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse.tween_property(start_halo, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _make_slot(parent: Control, i: int) -> Dictionary:
	var panel := Panel.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)
	var body := _vbox(6)
	body.alignment = BoxContainer.ALIGNMENT_CENTER
	body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.offset_left = 12
	body.offset_top = 12
	body.offset_right = -12
	body.offset_bottom = -12
	panel.add_child(body)
	var cow := _pic(null, Vector2.ZERO)
	cow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST # crisp pixel art
	cow.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	body.add_child(cow)
	var empty_label := _centered(_label("Waiting for player…", f_semi, 19, MUTED))
	empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(empty_label)
	var name_label := _centered(_label("Player %d" % (i + 1), f_bold, 28, CREAM))
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	body.add_child(name_label)
	var pill := PanelContainer.new()
	pill.custom_minimum_size.y = 36
	pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	body.add_child(pill)
	var pill_row := _hbox(6)
	pill.add_child(pill_row)
	var pill_icon := _pic(null, Vector2(20, 20))
	pill_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pill_row.add_child(pill_icon)
	var pill_label := _label("", f_caps, 17, MUTED)
	pill_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pill_row.add_child(pill_label)
	var bar := _bar(RED, PANEL, 8)
	body.add_child(bar)
	var badge := PanelContainer.new()
	badge.position = Vector2(12, 12)
	badge.custom_minimum_size = Vector2(44, 32)
	panel.add_child(badge)
	var badge_label := _label("P%d" % (i + 1), f_bold, 18, PLAYER_COLORS[i])
	badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_child(badge_label)
	return {"panel": panel, "badge": badge, "badge_label": badge_label, "cow": cow, "empty_label": empty_label,
		"name_label": name_label, "pill": pill, "pill_icon": pill_icon, "pill_label": pill_label, "bar": bar}


func _build_lost() -> void:
	var screen := _screen("lost")
	var col := _page(screen)
	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(center)
	var body := _vbox(0)
	center.add_child(body)
	var spill := _pic(_svg(SPILL_SVG), Vector2(270, 160))
	spill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	body.add_child(spill)
	_gap(body, 24)
	lost_heading = _centered(_label("", f_title, 60, CREAM, 6))
	body.add_child(lost_heading)
	_gap(body, 18)
	lost_text = _centered(_label("", f_medium, 24, LATTE))
	lost_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lost_text.custom_minimum_size.x = 600
	body.add_child(lost_text)
	_gap(body, 36)
	var buttons := _hbox(20)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(buttons)
	var retry := _button("Retry", f_title, 40, BG, _ledge(_box(CREAM, 24), 8, LEDGE), Vector2(300, 88), _svg(RETRY_SVG), 32)
	retry.pressed.connect(_create_room)
	buttons.add_child(retry)
	var back := _button("Back", f_semi, 24, CREAM, _pad(_bordered(_box(Color.TRANSPARENT, 24), 4, LINE), 32, 0), Vector2(0, 88))
	back.pressed.connect(func(): _show("title"))
	buttons.add_child(back)
	_gap(col, 48)


# --- Building blocks -------------------------------------------------------

func _load_assets() -> void:
	var fredoka: FontFile = load("res://assets/fonts/Fredoka.ttf")
	f_medium = _weight(fredoka, 500)
	f_semi = _weight(fredoka, 600)
	f_bold = _weight(fredoka, 700)
	var caps := _weight(fredoka, 700)
	caps.spacing_glyph = 1
	f_caps = caps
	f_title = load("res://assets/fonts/LilitaOne-Regular.ttf")
	f_mono = _weight(load("res://assets/fonts/JetBrainsMono.ttf"), 800)
	for n in range(1, 5):
		var tex: Texture2D = load("res://assets/sprites/lobby/cow_p%d.png" % n)
		cow_textures.append(tex)
		var img := tex.get_image()
		img.convert(Image.FORMAT_RGBA8)
		for y in img.get_height():
			for x in img.get_width():
				var c := img.get_pixel(x, y)
				var l := c.r * 0.2126 + c.g * 0.7152 + c.b * 0.0722
				img.set_pixel(x, y, Color(l, l, l, c.a))
		cow_grey.append(ImageTexture.create_from_image(img))
	cow_empty = load("res://assets/sprites/lobby/cow_empty.png")
	theme = Theme.new()
	theme.default_font = f_semi
	theme.default_font_size = 18


func _weight(base: Font, wght: int) -> FontVariation:
	var v := FontVariation.new()
	v.base_font = base
	v.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): wght}
	return v


func _screen(key: String) -> Control:
	var c := Control.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(c)
	screens[key] = c
	return c


## Full-screen column with the small logo header, used by connecting and lost screens.
func _page(screen: Control) -> VBoxContainer:
	var col := _vbox(0)
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.add_child(col)
	var header := MarginContainer.new()
	header.add_theme_constant_override("margin_left", 32)
	header.add_theme_constant_override("margin_top", 32)
	header.custom_minimum_size.y = 104
	header.add_child(_logo())
	col.add_child(header)
	return col


func _logo() -> Label:
	var l := _label("PandeMOOnium", f_title, 40, CREAM, 4)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return l


func _step(number: String) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(36, 36)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.add_theme_stylebox_override("panel", _box(CREAM, 18))
	var l := _label(number, f_bold, 20, BG)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	p.add_child(l)
	return p


func _blob(rect: Rect2, from_right: bool, radii: Array) -> void:
	var p := Panel.new()
	var s := _box(BLOB, 0)
	s.corner_radius_top_left = radii[0]
	s.corner_radius_top_right = radii[1]
	s.corner_radius_bottom_right = radii[2]
	s.corner_radius_bottom_left = radii[3]
	s.corner_detail = 16
	p.add_theme_stylebox_override("panel", s)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if from_right:
		p.anchor_left = 1.0
		p.anchor_right = 1.0
	p.offset_left = rect.position.x
	p.offset_top = rect.position.y
	p.offset_right = rect.end.x
	p.offset_bottom = rect.end.y
	add_child(p)


func _label(text: String, font: Font, size: int, color: Color, shadow := 0) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if shadow > 0:
		l.add_theme_color_override("font_shadow_color", INK)
		l.add_theme_constant_override("shadow_offset_x", 0)
		l.add_theme_constant_override("shadow_offset_y", shadow)
		l.add_theme_constant_override("shadow_outline_size", 0)
	return l


func _centered(l: Label) -> Label:
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _box(bg: Color, radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.corner_detail = 10
	s.set_content_margin_all(0)
	return s


func _bordered(s: StyleBoxFlat, width: int, color: Color) -> StyleBoxFlat:
	s.set_border_width_all(width)
	s.border_color = color
	return s


## The design's chunky "box-shadow: 0 Npx 0" ledge under buttons and tiles.
func _ledge(s: StyleBoxFlat, height: int, color: Color) -> StyleBoxFlat:
	s.border_width_bottom = height
	s.border_color = color
	s.expand_margin_bottom = height
	return s


func _pad(s: StyleBoxFlat, horizontal: int, vertical: int) -> StyleBoxFlat:
	s.content_margin_left = horizontal
	s.content_margin_right = horizontal
	s.content_margin_top = vertical
	s.content_margin_bottom = vertical
	return s


func _button(text: String, font: Font, size: int, color: Color, style: StyleBoxFlat, min_size: Vector2, icon: Texture2D = null, icon_size := 0, icon_after := false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_override("font", font)
	b.add_theme_font_size_override("font_size", size)
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color", "font_disabled_color"]:
		b.add_theme_color_override(key, color)
	var hover := style.duplicate() as StyleBoxFlat
	var pressed := style.duplicate() as StyleBoxFlat
	if style.bg_color.a == 0.0:
		hover.bg_color = Color(CREAM, 0.06)
		pressed.bg_color = Color(CREAM, 0.12)
	else:
		hover.bg_color = style.bg_color.lightened(0.08)
		pressed.bg_color = style.bg_color.darkened(0.08)
	var focus := style.duplicate() as StyleBoxFlat
	focus.draw_center = false
	focus.set_border_width_all(3)
	focus.border_color = LATTE
	focus.expand_margin_left = 4
	focus.expand_margin_right = 4
	focus.expand_margin_top = 4
	b.add_theme_stylebox_override("normal", style)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("hover_pressed", pressed)
	b.add_theme_stylebox_override("disabled", style)
	b.add_theme_stylebox_override("focus", focus)
	if icon:
		# Godot pins a Button's icon to an edge; the design centres icon + text together,
		# so draw them as children instead. Callers set custom_minimum_size.x for the width.
		b.text = ""
		var center := CenterContainer.new()
		center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(center)
		var row := _hbox(maxi(8, icon_size / 2 - 2))
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		center.add_child(row)
		var pic := _pic(icon, Vector2(icon_size, icon_size))
		pic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(_label(text, font, size, color))
		row.add_child(pic)
		if not icon_after:
			row.move_child(pic, 0)
		b.set_meta("icon_rect", pic)
	return b


func _bar(fill: Color, track: Color, height: int) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size.y = height
	bar.add_theme_stylebox_override("background", _box(track, height / 2))
	bar.add_theme_stylebox_override("fill", _box(fill, height / 2))
	return bar


func _vbox(separation: int) -> VBoxContainer:
	var b := VBoxContainer.new()
	b.add_theme_constant_override("separation", separation)
	return b


func _hbox(separation: int) -> HBoxContainer:
	var b := HBoxContainer.new()
	b.add_theme_constant_override("separation", separation)
	return b


func _gap(parent: Control, height: int) -> void:
	var c := Control.new()
	c.custom_minimum_size.y = height
	parent.add_child(c)


func _svg(src: String, scale := 2.0) -> ImageTexture:
	var img := Image.new()
	img.load_svg_from_string(src, scale)
	return ImageTexture.create_from_image(img)


func _pic(tex: Texture2D, size: Vector2) -> TextureRect:
	var t := TextureRect.new()
	t.texture = tex
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = size
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


## A picture that gently floats up and down (title cow, coffee machine).
func _bobbing(parent: Control, tex: Texture2D, size: Vector2, amount: float, period: float) -> void:
	var holder := Control.new()
	holder.custom_minimum_size = size
	holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(holder)
	var pic := _pic(tex, size)
	pic.size = size
	holder.add_child(pic)
	var tw := pic.create_tween().set_loops()
	tw.tween_property(pic, "position:y", -amount, period / 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(pic, "position:y", 0.0, period / 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
