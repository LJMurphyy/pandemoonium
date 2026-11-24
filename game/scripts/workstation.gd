extends Node2D
# a cafe station , Stations are driven by main.gd: `interact(player, game)` and `tick(delta)`.
const ItemScript = preload("res://scripts/item.gd")

enum Kind { SUPPLY, COUNTER, MIX, SERVE, TRASH, STEAM }
enum State { IDLE, WORKING, DONE, SABOTAGED }  # SABOTAGED is reserved for the impostor role

var kind: int = Kind.COUNTER
var state: int = State.IDLE
var station_name := ""
var size := Vector2(120, 80)
var tint := Color.WHITE
var supply_id := ""              # SUPPLY: which ingredient it hands out
var recipes: Array = []          # MIX: every drink it can make
var recipe: Resource = null      # MIX: the drink currently being made
var contents: Array[String] = [] # MIX: ingredients added so far
var held = null                  # MIX/STEAM: the finished output waiting to be taken
var items: Array = []            # COUNTER: everything set down here
var capacity := 3                # COUNTER: how many items fit
var work_left := 0.0

func setup(p_kind: int, p_name: String, pos: Vector2, p_size: Vector2, p_tint: Color) -> void:
	kind = p_kind
	station_name = p_name
	position = pos
	size = p_size
	tint = p_tint

func tick(delta: float) -> void:
	if state == State.WORKING:
		work_left -= delta
		if work_left <= 0.0:
			state = State.DONE
			if kind == Kind.STEAM:
				held = ItemScript.ingredient("steamed_milk", "Steamed Milk", Color("fff1d6"))
			else:
				held = ItemScript.drink(recipe)
	queue_redraw()

## Called when a player presses INTERACT within reach. Mutates player.carried.
func interact(player, game) -> void:
	match kind:
		Kind.SUPPLY:
			if player.carried == null:
				player.carried = ItemScript.ingredient(supply_id, station_name.capitalize(), tint)
				game.announce("P%d grabbed %s." % [player.player_number, station_name.to_lower()])
			else:
				game.announce("P%d: hands full." % player.player_number)
		Kind.COUNTER:
			if player.carried != null and items.size() < capacity:
				items.append(player.carried)
				player.carried = null
			elif player.carried == null and not items.is_empty():
				player.carried = items.pop_back()
			elif player.carried != null:
				game.announce("P%d: counter is full." % player.player_number)
		Kind.TRASH:
			if player.carried != null:
				game.announce("P%d trashed %s." % [player.player_number, player.carried.label])
				player.carried = null
		Kind.MIX:
			_interact_mix(player, game)
		Kind.STEAM:
			_interact_steam(player, game)
		Kind.SERVE:
			if player.carried != null and player.carried.kind == ItemScript.Kind.DRINK:
				var drink = player.carried
				player.carried = null
				game.serve_drink(player, drink)
			elif player.carried != null:
				game.announce("P%d: that's not a drink." % player.player_number)
	queue_redraw()

func _interact_steam(player, game) -> void:
	match state:
		State.IDLE:
			if player.carried != null and player.carried.id == "milk":
				player.carried = null
				state = State.WORKING
				work_left = 3.0
				game.announce("Steaming milk...")
			elif player.carried != null:
				game.announce("P%d: the steamer only takes milk." % player.player_number)
		State.DONE:
			if player.carried == null:
				player.carried = held
				held = null
				state = State.IDLE
		State.SABOTAGED:
			state = State.IDLE
			held = null

func _interact_mix(player, game) -> void:
	match state:
		State.IDLE:
			var c = player.carried
			if c == null or c.kind != ItemScript.Kind.INGREDIENT:
				return
			if contents.has(c.id) or _matching_recipe(contents + [c.id], false) == null:
				game.announce("P%d: that doesn't go in any recipe with what's in the mixer." % player.player_number)
				return
			contents.append(c.id)
			player.carried = null
			recipe = _matching_recipe(contents, true)
			if recipe != null:
				state = State.WORKING
				work_left = recipe.work_seconds
				game.announce("Mixing a %s..." % recipe.display_name)
		State.DONE:
			if player.carried == null:
				player.carried = held
				held = null
				contents.clear()
				state = State.IDLE
				recipe = null
				game.announce("P%d took the %s." % [player.player_number, player.carried.label])
		State.SABOTAGED:
			state = State.IDLE
			contents.clear()
			recipe = null
			held = null

## A recipe whose ingredients are exactly `have` (exact) or a superset of it (partial).
func _matching_recipe(have: Array, exact: bool):
	for r in recipes:
		var ok := true
		for id in have:
			if not r.ingredients.has(id):
				ok = false
		if exact and have.size() != r.ingredients.size():
			ok = false
		if ok:
			return r
	return null

func _draw() -> void:
	if kind == Kind.SUPPLY:
		# Small round ingredient pot that sits on a table.
		draw_circle(Vector2.ZERO, size.x / 2.0 - 4, tint)
		draw_arc(Vector2.ZERO, size.x / 2.0 - 4, 0, TAU, 24, Color("203144"), 2.0)
		draw_string(ThemeDB.fallback_font, Vector2(-size.x / 2.0, 4), station_name, HORIZONTAL_ALIGNMENT_CENTER, size.x, 11, Color("1c2636"))
		return
	var rect := Rect2(-size / 2.0, size)
	draw_rect(rect, tint)
	draw_rect(rect, Color("203144"), false, 3.0)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(-size.x / 2.0 + 6, -size.y / 2.0 - 6), station_name, HORIZONTAL_ALIGNMENT_LEFT, size.x, 14, Color.WHITE)
	var status := ""
	match kind:
		Kind.MIX:
			status = ["READY", "WORKING", "DONE!", "BROKEN"][state]
			if state == State.IDLE:
				status = "+".join(contents) if not contents.is_empty() else "EMPTY"
			if state == State.WORKING and recipe:
				var frac := float(1.0 - work_left / recipe.work_seconds)
				draw_rect(Rect2(-size.x / 2.0 + 8, size.y / 2.0 - 16, (size.x - 16) * frac, 8), Color("203144"))
		Kind.STEAM:
			status = ["READY", "STEAMING", "DONE!", "BROKEN"][state]
			if state == State.WORKING:
				draw_rect(Rect2(-size.x / 2.0 + 8, size.y / 2.0 - 16, (size.x - 16) * (1.0 - work_left / 3.0), 8), Color("203144"))
		Kind.COUNTER:
			for i in range(items.size()):
				draw_circle(Vector2(-size.x / 2.0 + 18 + i * 26, 0), 10, items[i].color)
				draw_string(font, Vector2(-size.x / 2.0 + 10 + i * 26, 4), items[i].label.left(2), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.BLACK)
	if not status.is_empty():
		draw_string(font, Vector2(-size.x / 2.0 + 8, 5), status, HORIZONTAL_ALIGNMENT_LEFT, size.x - 12, 16, Color("1c2636"))
	if held != null:
		draw_circle(Vector2(size.x / 2.0 - 16, 0), 10, held.color)
