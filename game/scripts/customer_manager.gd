extends Node2D
## Customers for a shift (#27): spawns them at random times, keeps the line moving,
## and hands their orders to Sruti's OrderManager (#30).
##
## Flow: door -> walk up the side lane -> back of the line -> register (orders by
## themselves, no player needed) -> steps aside to a pickup spot so the line moves up
## -> leaves happy when served, angry when their patience runs out.
signal customer_served(customer)
signal customer_left_angry(customer)

const Customer = preload("res://scripts/customer.gd")

## --- Layout: placeholder spots beside SERVE until Grace's World.tscn (#23) has markers ---
const DOOR := Vector2(1000, 625)
const LANE_X := 955.0 # customers walk in along this lane, beside the line, never through it
## LINE_SPOTS[0] is the register; the rest is the line behind it.
const LINE_SPOTS := [Vector2(915, 405), Vector2(915, 460), Vector2(915, 515), Vector2(915, 570), Vector2(915, 625)]
## Where customers wait for their drink. Filled from the far end, so a new customer only
## walks past empty spots; when someone leaves, everyone nearer the register shuffles over.
const PICKUP_SPOTS := [Vector2(690, 405), Vector2(745, 405), Vector2(800, 405), Vector2(855, 405)]
## Placeholder until Sruti's recipes (#29).
const RECIPES := ["Latte", "Chai Latte", "Matcha Latte", "Vanilla Coffee"]
const TINTS := [Color("f4d6b0"), Color("c9e4ca"), Color("d7c9f2"), Color("f6c6c6"), Color("cfe3f5")]

## --- Spawning: random gaps, so customers can pile up fast or trickle in slowly ---
## Normal gaps are random (exponential, like real arrivals) around an average that
## shrinks as the shift goes on. Sometimes a rush happens: a few customers back to back.
const START_GAP := 9.0 # average seconds between customers at the start of the shift
const END_GAP := 4.0 # ...and by the end of it
const MIN_GAP := 1.0 # outside a rush, never two in the same second
const MAX_GAP := 2.5 # longest quiet spell is 2.5x the current average
const RUSH_CHANCE := Vector2(0.10, 0.30) # chance the next arrival starts a rush (start, end of shift)
const RUSH_SIZE := Vector2i(2, 4) # customers in a rush
const RUSH_GAP := Vector2(0.6, 1.4) # seconds between rush customers
const FIRST_CUSTOMER := 2.0 # seconds into the shift

## --- Customers ---
const ORDER_SECONDS := 1.5 # time spent ordering at the register
const PATIENCE := Vector2(30.0, 45.0) # seconds a customer waits for their drink...
const PATIENCE_END_SCALE := 0.7 # ...shrinking to 70% by the end of the shift

## Set this if OrderManager is not an autoload; otherwise /root/OrderManager is used if it exists.
## With no OrderManager, customers time out by themselves and main.gd calls serve().
var order_manager: Node = null
var rng := RandomNumberGenerator.new()
var running := false
var paused := false
var shift_length := 180.0
var shift_time := 0.0
var next_spawn := 0.0
var rush_left := 0
var order_timer := 0.0
var line: Array = [] # line[i] stands at LINE_SPOTS[i]
var waiting: Array = [] # waiting[i] stands at PICKUP_SPOTS[i], oldest order first

func _ready() -> void:
	rng.randomize()
	var net := get_node_or_null("/root/NetworkManager")
	if net:
		net.disconnected.connect(clear)
		net.message_received.connect(_on_message)

## Start a new shift (round). Clears any customers left from the last one.
func start_shift(length_seconds: float) -> void:
	clear()
	shift_length = maxf(1.0, length_seconds)
	next_spawn = FIRST_CUSTOMER
	running = true
	paused = false
	_connect_order_manager()

## Round over: no new customers, everyone freezes where they are.
func stop_shift() -> void:
	running = false

## Emergency meeting (#22): freeze arrivals, walking and patience.
func set_paused(value: bool) -> void:
	paused = value

func clear() -> void:
	for c in get_children():
		c.queue_free()
	line.clear()
	waiting.clear()
	running = false
	shift_time = 0.0
	rush_left = 0
	order_timer = 0.0

## Temporary, until OrderManager exists: main.gd calls this when a drink is served.
## The customer who has waited longest for that recipe takes it and leaves happy.
## Returns false if nobody wants it (or if OrderManager is handling orders).
func serve(recipe: String) -> bool:
	if _has_order_manager():
		return false
	for c in waiting:
		if c.recipe == recipe and c.state == Customer.State.WAITING:
			_leave(c, true)
			return true
	return false

func _process(delta: float) -> void:
	if running and not paused:
		tick(delta)

## One step of the shift. Runs every frame; tests call it directly with fake time.
func tick(delta: float) -> void:
	shift_time += delta
	if shift_time >= next_spawn:
		if line.size() < LINE_SPOTS.size():
			_spawn()
			next_spawn = shift_time + next_gap()
		else:
			next_spawn = shift_time + 1.0 # line is full: try again in a second
	for c in get_children():
		if not c.is_queued_for_deletion():
			c.tick(delta)
	_run_register(delta)
	if not _has_order_manager():
		for c in waiting.duplicate():
			if c.patience_left <= 0.0:
				_leave(c, false)

## Seconds until the next customer. Random each time: usually around the average,
## sometimes much sooner (or a rush), sometimes a quiet spell.
func next_gap() -> float:
	var progress := clampf(shift_time / shift_length, 0.0, 1.0)
	if rush_left > 0:
		rush_left -= 1
		return rng.randf_range(RUSH_GAP.x, RUSH_GAP.y)
	if rng.randf() < lerpf(RUSH_CHANCE.x, RUSH_CHANCE.y, progress):
		rush_left = rng.randi_range(RUSH_SIZE.x, RUSH_SIZE.y) - 2 # this gap is the first of the rush
		return rng.randf_range(RUSH_GAP.x, RUSH_GAP.y)
	var average := lerpf(START_GAP, END_GAP, progress)
	var gap := -average * log(maxf(0.000001, 1.0 - rng.randf())) # exponential random gap
	return clampf(gap, MIN_GAP, average * MAX_GAP)

func _spawn() -> void:
	var progress := clampf(shift_time / shift_length, 0.0, 1.0)
	var patience := rng.randf_range(PATIENCE.x, PATIENCE.y) * lerpf(1.0, PATIENCE_END_SCALE, progress)
	var c = Customer.new()
	c.setup(DOOR, RECIPES[rng.randi() % RECIPES.size()], patience, TINTS[rng.randi() % TINTS.size()])
	add_child(c)
	line.append(c)
	_walk_to_line_spot(c, line.size() - 1)

## Walk up the side lane, then step into the spot, so nobody walks through the line.
func _walk_to_line_spot(c, i: int) -> void:
	var spot: Vector2 = LINE_SPOTS[i]
	if c.position.x > spot.x + 1.0:
		c.walk_to([Vector2(LANE_X, c.position.y), Vector2(LANE_X, spot.y), spot])
	else:
		c.walk_to([spot])

## The customer at the register orders by themselves, then steps aside to a pickup spot
## and everyone behind them moves up one spot.
func _run_register(delta: float) -> void:
	if line.is_empty():
		return
	var c = line[0]
	if c.is_walking():
		return
	if c.state == Customer.State.IN_LINE:
		c.state = Customer.State.ORDERING
		order_timer = ORDER_SECONDS
		return
	order_timer -= delta
	if order_timer > 0.0 or waiting.size() >= PICKUP_SPOTS.size():
		return # still ordering, or no room to wait yet (so the line backs up)
	line.pop_front()
	waiting.append(c)
	c.state = Customer.State.WAITING
	c.walk_to([PICKUP_SPOTS[waiting.size() - 1]])
	_place_order(c)
	for i in line.size():
		_walk_to_line_spot(line[i], i)

func _leave(c, was_happy: bool) -> void:
	var i := waiting.find(c)
	if i == -1:
		return
	waiting.remove_at(i)
	c.leave(was_happy)
	for j in range(i, waiting.size()):
		waiting[j].walk_to([PICKUP_SPOTS[j]]) # shuffle over to make room
	if was_happy:
		customer_served.emit(c)
	else:
		customer_left_angry.emit(c)

## --- OrderManager (#30): add_order(recipe, patience_seconds, customer),
## signals order_completed(customer) / order_expired(customer) ---
func _get_order_manager() -> Node:
	if order_manager:
		return order_manager
	return get_node_or_null("/root/OrderManager") if is_inside_tree() else null

func _has_order_manager() -> bool:
	var om := _get_order_manager()
	return om != null and om.has_method("add_order")

func _connect_order_manager() -> void:
	var om := _get_order_manager()
	if om == null:
		return
	if om.has_signal("order_completed") and not om.is_connected("order_completed", _on_order_completed):
		om.connect("order_completed", _on_order_completed)
	if om.has_signal("order_expired") and not om.is_connected("order_expired", _on_order_expired):
		om.connect("order_expired", _on_order_expired)

func _place_order(c) -> void:
	if _has_order_manager():
		_get_order_manager().add_order(c.recipe, c.patience_total, c)

func _on_order_completed(customer) -> void:
	_leave(customer, true)

func _on_order_expired(customer) -> void:
	_leave(customer, false)

func _on_message(msg: Dictionary) -> void:
	if str(msg.get("type", "")) == "room_created":
		clear()
