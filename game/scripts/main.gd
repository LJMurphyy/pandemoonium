extends Control
## Milestone 2: 2-4 local phone controllers, movement and playable drink loop.
## The lobby screens (create room, roster, start) live in lobby.gd; this script runs the round.
const PLAYER_SCRIPT = preload("res://scripts/player.gd")
const LOBBY_SCRIPT = preload("res://scripts/lobby.gd")
const STARTS := [Vector2(330, 400), Vector2(410, 400), Vector2(490, 400), Vector2(570, 400)]
const STATIONS := [
	{"name":"INGREDIENTS", "pos":Vector2(145, 305), "color":Color("f2bd66")},
	{"name":"MIX DRINK", "pos":Vector2(480, 305), "color":Color("81d1da")},
	{"name":"SERVE", "pos":Vector2(805, 305), "color":Color("b9a2f4")}
]
var lobby: Control
var hud_label: Label
var world: Node2D
var characters: Dictionary = {}
var role_map: Dictionary = {}
var phase := "lobby"
var score := 0
var satisfaction := 100
var seconds_left := 180.0
var sabotage_cooldown := 0.0
var event_message := ""
var event_timer := 0.0
var customers: Node2D # customer_manager.gd (#27), created when the first round starts

func _ready() -> void:
	NetworkManager.message_received.connect(_network_message)
	NetworkManager.disconnected.connect(_reset_round)
	_build_world()
	lobby = LOBBY_SCRIPT.new()
	lobby.connect("create_requested", _reset_round)
	add_child(lobby)
	set_process(true)

func _build_world() -> void:
	world = Node2D.new()
	add_child(world)
	# Collision demo: a solid service counter between the stations and walking area.
	var counter := StaticBody2D.new()
	counter.position = Vector2(480, 525)
	counter.collision_layer = 2
	counter.collision_mask = 0
	var counter_shape := CollisionShape2D.new()
	var counter_rect := RectangleShape2D.new()
	counter_rect.size = Vector2(200, 38)
	counter_shape.shape = counter_rect
	counter.add_child(counter_shape)
	world.add_child(counter)
	hud_label = Label.new()
	hud_label.position = Vector2(20, 660)
	hud_label.add_theme_font_size_override("font_size", 18)
	hud_label.text = ""
	add_child(hud_label)

## A new room is being made, or the connection is gone: clear the old round.
func _reset_round() -> void:
	for player in characters.values():
		player.queue_free()
	characters.clear()
	role_map.clear()
	phase = "lobby"
	hud_label.text = ""
	queue_redraw()

func _network_message(msg: Dictionary) -> void:
	match str(msg.get("type", "")):
		"player_joined":
			var id := str(msg.get("playerId", ""))
			_spawn_player(id, int(msg.get("number", 1)))
		"player_left":
			var id := str(msg.get("playerId", ""))
			if characters.has(id):
				characters[id].queue_free()
				characters.erase(id)
		"game_started":
			_start_round()
		"input":
			var id := str(msg.get("playerId", ""))
			if characters.has(id):
				var p = characters[id]
				p.direction = Vector2(float(msg.get("x", 0.0)), float(msg.get("y", 0.0))).limit_length(1.0)
				p.held_action = msg.get("action", false) == true
				p.held_sabotage = msg.get("sabotage", false) == true

func _spawn_player(id: String, number: int) -> void:
	if id.is_empty() or number < 1 or number > 4 or characters.has(id):
		return
	var p = CharacterBody2D.new()
	p.set_script(PLAYER_SCRIPT)
	p.call("configure", number, false)
	p.position = STARTS[number - 1]
	world.add_child(p)
	characters[id] = p

func _start_round() -> void:
	phase = "playing"
	score = 0
	satisfaction = 100
	seconds_left = 180.0
	sabotage_cooldown = 0.0
	if customers == null:
		customers = preload("res://scripts/customer_manager.gd").new()
		world.add_child(customers)
		world.move_child(customers, 0) # draw customers under the players
	customers.start_shift(seconds_left)
	var ids: Array = characters.keys()
	if ids.is_empty():
		return
	ids.shuffle()
	var impostor_id: String = str(ids[0])
	for id in characters.keys():
		var p = characters[id]
		var is_impostor: bool = str(id) == impostor_id
		role_map[id] = "impostor" if is_impostor else "barista"
		p.impostor = is_impostor
		p.carried = ""
		p.position = STARTS[p.player_number - 1]
	NetworkManager.send_message({"type":"assign_roles", "roles":role_map})
	_announce("Round started! Make drinks. One player is the impostor.")

func _process(delta: float) -> void:
	if phase != "playing":
		queue_redraw()
		return
	seconds_left -= delta
	sabotage_cooldown = maxf(0.0, sabotage_cooldown - delta)
	event_timer = maxf(0.0, event_timer - delta)
	for id in characters.keys():
		var p = characters[id]
		if p.held_action and not p.last_action:
			_interact(p)
		if p.held_sabotage and not p.last_sabotage and p.impostor:
			_sabotage(p)
		p.last_action = p.held_action
		p.last_sabotage = p.held_sabotage
	hud_label.text = "Drinks served: %d   |   Satisfaction: %d%%   |   Time: %ds   |   %s" % [score, satisfaction, maxi(0, ceili(seconds_left)), event_message if event_timer > 0 else ""]
	if seconds_left <= 0.0 or satisfaction <= 0:
		_finish_round()
	queue_redraw()

func _nearest_station(at: Vector2) -> int:
	var best := -1
	var distance := 100.0
	for i in range(STATIONS.size()):
		var d: float = at.distance_to(STATIONS[i]["pos"])
		if d < distance:
			best = i
			distance = d
	return best

func _interact(p) -> void:
	var station := _nearest_station(p.position)
	if station == -1:
		_announce("P%d: Move closer to a station." % p.player_number)
		return
	match station:
		0:
			if p.carried.is_empty():
				p.carried = "ingredient"
				_announce("P%d picked up ingredients." % p.player_number)
		1:
			if p.carried == "ingredient":
				p.carried = "drink"
				_announce("P%d mixed a drink!" % p.player_number)
		2:
			if p.carried == "drink":
				customers.serve(p.carried) # temporary until OrderManager (#30) handles serving
				p.carried = ""
				score += 1
				satisfaction = mini(100, satisfaction + 4)
				_announce("P%d served a drink! +1" % p.player_number)

func _sabotage(p) -> void:
	if sabotage_cooldown > 0.0:
		_announce("Sabotage recharging: %ds" % ceili(sabotage_cooldown))
		return
	if _nearest_station(p.position) == -1:
		_announce("Impostor: get near a station to sabotage.")
		return
	sabotage_cooldown = 18.0
	satisfaction = maxi(0, satisfaction - 20)
	_announce("A station was sabotaged! Satisfaction -20.")

func _announce(message: String) -> void:
	event_message = message
	event_timer = 4.0
	NetworkManager.send_message({"type":"game_event", "event":message})

func _finish_round() -> void:
	phase = "finished"
	customers.stop_shift()
	var ending := "IMPOSTOR WINS" if satisfaction <= 0 else "BARISTAS WIN"
	hud_label.text = "%s — %d drinks served. Restart Godot to create another room." % [ending, score]
	NetworkManager.send_message({"type":"game_event", "event":ending})

func _draw() -> void:
	var bg := Color("182c3b")
	draw_rect(Rect2(0, 205, 960, 440), bg)
	draw_rect(Rect2(380, 506, 200, 38), Color("4b6681"))
	for s in STATIONS:
		var pos: Vector2 = s["pos"]
		var rect := Rect2(pos - Vector2(74, 45), Vector2(148, 90))
		draw_rect(rect, s["color"])
		draw_rect(rect, Color("203144"), false, 3.0)
		draw_string(ThemeDB.fallback_font, pos + Vector2(-64, 5), str(s["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("1c2636"))
	draw_string(ThemeDB.fallback_font, Vector2(25, 625), "Move: joystick   |   Interact near a station: ingredients -> mix -> serve", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
