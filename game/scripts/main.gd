extends Control
## Milestone 2: 2-4 local phone controllers, movement and playable drink loop.
## The lobby screens (create room, roster, start) live in lobby.gd; this script runs the round.
const PLAYER_SCRIPT = preload("res://scripts/player.gd")
const LOBBY_SCRIPT = preload("res://scripts/lobby.gd")
const STARTS := [Vector2(330, 400), Vector2(410, 400), Vector2(490, 400), Vector2(570, 400)]
const WORKSTATION_SCRIPT = preload("res://scripts/workstation.gd")
const ORDER_MANAGER_SCRIPT = preload("res://scripts/order_manager.gd")
const RECIPES: Array = [
	preload("res://resources/recipes/latte.tres"),
	preload("res://resources/recipes/chai_latte.tres"),
	preload("res://resources/recipes/matcha_latte.tres"),
	preload("res://resources/recipes/vanilla_coffee.tres"),
]
var lobby: Control
const REACH := 100.0
var hud_label: Label
var world: Node2D
var characters: Dictionary = {}
var role_map: Dictionary = {}
var phase := "lobby"
var stations: Array = []
var order_manager: Node
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
	order_manager = ORDER_MANAGER_SCRIPT.new()
	add_child(order_manager)
	order_manager.shift_ended.connect(_shift_ended)
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
	_build_stations()
	hud_label = Label.new()
	hud_label.position = Vector2(20, 660)
	hud_label.add_theme_font_size_override("font_size", 18)
	hud_label.text = ""
	add_child(hud_label)

func _add_station(kind: int, label: String, pos: Vector2, size: Vector2, tint: Color, extra: String = "") -> void:
	var st := Node2D.new()
	st.set_script(WORKSTATION_SCRIPT)
	st.call("setup", kind, label, pos, size, tint)
	if kind == WORKSTATION_SCRIPT.Kind.SUPPLY:
		st.supply_id = extra
	if kind == WORKSTATION_SCRIPT.Kind.MIX:
		st.recipes = RECIPES
	world.add_child(st)
	stations.append(st)

## Layout placeholder; move to Grace's World.tscn spots (#23) when ready.
func _build_stations() -> void:
	var K = WORKSTATION_SCRIPT.Kind
	_add_station(K.SUPPLY, "COFFEE", Vector2(90, 305), Vector2(110, 80), Color("a9744f"), "coffee")
	_add_station(K.SUPPLY, "MILK", Vector2(215, 305), Vector2(110, 80), Color("e8eef2"), "milk")
	_add_station(K.MIX, "MIX DRINK", Vector2(400, 305), Vector2(130, 80), Color("81d1da"))
	_add_station(K.COUNTER, "COUNTER", Vector2(565, 305), Vector2(120, 80), Color("8a9bb0"))
	_add_station(K.SERVE, "SERVE", Vector2(740, 305), Vector2(120, 80), Color("b9a2f4"))
	_add_station(K.TRASH, "TRASH", Vector2(880, 305), Vector2(80, 80), Color("6b6f76"))
	_add_station(K.SUPPLY, "CHAI", Vector2(90, 470), Vector2(100, 80), Color("c98a4b"), "chai")
	_add_station(K.SUPPLY, "VANILLA", Vector2(205, 470), Vector2(100, 80), Color("f3e5ab"), "vanilla")
	_add_station(K.SUPPLY, "MATCHA", Vector2(320, 470), Vector2(100, 80), Color("8fbf6a"), "matcha")
	_add_station(K.COUNTER, "COUNTER", Vector2(800, 470), Vector2(120, 70), Color("8a9bb0"))

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
	sabotage_cooldown = 0.0
	if customers == null:
		customers = preload("res://scripts/customer_manager.gd").new()
		world.add_child(customers)
		world.move_child(customers, 0) # draw customers under the players
	order_manager.start_shift(180.0)
	for st in stations:
		st.state = WORKSTATION_SCRIPT.State.IDLE
		st.contents.clear()
		st.recipe = null
		st.held = null
	customers.order_manager = order_manager
	customers.start_shift(order_manager.shift_length)
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
		p.carried = null
		p.position = STARTS[p.player_number - 1]
	NetworkManager.send_message({"type":"assign_roles", "roles":role_map})
	announce("Round started! Make drinks. One player is the impostor.")

func _process(delta: float) -> void:
	if phase != "playing":
		queue_redraw()
		return
	event_timer = maxf(0.0, event_timer - delta)
	if not order_manager.paused:
		sabotage_cooldown = maxf(0.0, sabotage_cooldown - delta)
		for st in stations:
			st.tick(delta)
	for id in characters.keys():
		var p = characters[id]
		if p.held_action and not p.last_action and not order_manager.paused:
			_interact(p)
		if p.held_sabotage and not p.last_sabotage and p.impostor and not order_manager.paused:
			_sabotage(p)
		p.last_action = p.held_action
		p.last_sabotage = p.held_sabotage
	hud_label.text = "Drinks served: %d   |   Satisfaction: %d%%   |   Time: %ds   |   %s" % [order_manager.served, order_manager.satisfaction, maxi(0, ceili(order_manager.time_left)), event_message if event_timer > 0 else ""]
	queue_redraw()

func _nearest_station(at: Vector2):
	var best = null
	var distance := REACH
	for st in stations:
		var d: float = at.distance_to(st.position)
		if d < distance:
			best = st
			distance = d
	return best

func _interact(p) -> void:
	var station = _nearest_station(p.position)
	if station == null:
		announce("P%d: Move closer to a station." % p.player_number)
		return
	station.interact(p, self)

## Called by the SERVE station when a player hands in a drink.
func serve_drink(p, drink) -> void:
	if order_manager.serve(drink.recipe):
		announce("P%d served a %s! Satisfaction up." % [p.player_number, drink.label])
	else:
		announce("P%d served a drink nobody ordered! Satisfaction down." % p.player_number)

func _sabotage(p) -> void:
	if sabotage_cooldown > 0.0:
		announce("Sabotage recharging: %ds" % ceili(sabotage_cooldown))
		return
	if _nearest_station(p.position) == null:
		announce("Impostor: get near a station to sabotage.")
		return
	sabotage_cooldown = 18.0
	order_manager.change_satisfaction(-20)
	announce("A station was sabotaged! Satisfaction -20.")

func announce(message: String) -> void:
	event_message = message
	event_timer = 4.0
	NetworkManager.send_message({"type":"game_event", "event":message})

func _shift_ended(won: bool) -> void:
	phase = "finished"
	customers.stop_shift()
	var ending := "BARISTAS WIN" if won else "IMPOSTOR WINS"
	hud_label.text = "%s — %d drinks served. Restart Godot to create another room." % [ending, order_manager.served]
	NetworkManager.send_message({"type":"game_event", "event":ending})

func _draw() -> void:
	var bg := Color("182c3b")
	draw_rect(Rect2(0, 205, 960, 440), bg)
	draw_rect(Rect2(380, 506, 200, 38), Color("4b6681"))
	_draw_orders()
	draw_string(ThemeDB.fallback_font, Vector2(25, 625), "Move: joystick   |   Interact: combine 2 ingredients in the mixer -> serve the ticket", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)

func _draw_orders() -> void:
	var x := 20.0
	for order in order_manager.orders:
		var frac: float = clampf(order["left"] / order["patience"], 0.0, 1.0)
		var rect := Rect2(x, 215, 110, 46)
		draw_rect(rect, Color("f4ecd8"))
		draw_rect(Rect2(x, 255, 110.0 * frac, 6), Color("e0524d") if frac < 0.3 else Color("5bbf6a"))
		draw_string(ThemeDB.fallback_font, Vector2(x + 8, 240), order["recipe"].display_name, HORIZONTAL_ALIGNMENT_LEFT, 96, 16, Color("1c2636"))
		x += 118.0
