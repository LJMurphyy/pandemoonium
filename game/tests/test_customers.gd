extends SceneTree
## Tests for customer_manager.gd + customer.gd (#27). Fast-forwards whole shifts with fake time.
## Run from the repo root (use the path to your Godot app if `godot` isn't on your PATH):
##   godot --headless --path game -s res://tests/test_customers.gd
## On a Mac: /Applications/Godot.app/Contents/MacOS/Godot --headless --path game -s res://tests/test_customers.gd
## Exits with code 0 if everything passes, 1 if a check fails, 2 if it timed out.
const Manager = preload("res://scripts/customer_manager.gd")
const Customer = preload("res://scripts/customer.gd")
const STEP := 0.05
var passes := 0
var failures := 0

func check(cond: bool, what: String) -> void:
	if cond:
		passes += 1
		print("  ok   ", what)
	else:
		failures += 1
		print("  FAIL ", what)

func make(seed_value := 12345):
	var m = Manager.new()
	root.add_child(m)
	m.rng.seed = seed_value
	return m

## Customers still in the café (not fading out).
func present(m) -> Array:
	return m.get_children().filter(func(c): return not c.is_queued_for_deletion() and c.state != Customer.State.LEAVING)

func run(m, seconds: float, each_step := Callable()) -> void:
	var t := 0.0
	while t < seconds:
		m.tick(STEP)
		if each_step.is_valid():
			each_step.call()
		t += STEP

func settle(m, seconds := 4.0) -> void:
	m.next_spawn = INF
	run(m, seconds)

## Safety net: quit even if a script error stops the tests (otherwise Godot runs forever).
func _process(_delta: float) -> bool:
	if Time.get_ticks_msec() > 60000:
		print("TIMED OUT (a script error probably stopped the tests; see above)")
		quit(2)
	return false

## Wait (in fake time) until cond() is true. Returns false if it never happens.
func until(m, cond: Callable, max_seconds := 10.0) -> bool:
	var t := 0.0
	while not cond.call():
		if t > max_seconds:
			return false
		m.tick(STEP)
		t += STEP
	return true

func _initialize() -> void:
	_run.call_deferred() # after the scene tree is up, so /root lookups and signals work

func _run() -> void:
	print("Random arrivals")
	var m = make()
	m.start_shift(180.0)
	var gaps: Array[float] = []
	for i in 3000:
		gaps.append(m.next_gap())
	var mean_start := 0.0
	for g in gaps:
		mean_start += g
	mean_start /= gaps.size()
	var quick := gaps.filter(func(g): return g < 2.0).size()
	var slow := gaps.filter(func(g): return g > 12.0).size()
	var runs := 0
	for i in range(1, gaps.size()):
		if gaps[i] < 1.5 and gaps[i - 1] < 1.5:
			runs += 1
	print("    start of shift: avg gap %.1fs, %d quick (<2s), %d slow (>12s), %d back-to-back pairs" % [mean_start, quick, slow, runs])
	check(quick > 300, "customers sometimes come right after each other")
	check(slow > 100, "sometimes there's a long quiet spell")
	check(runs > 50, "rushes happen (several quick arrivals in a row)")
	check(gaps.all(func(g): return g >= 0.6 and g <= Manager.START_GAP * Manager.MAX_GAP), "gaps stay between 0.6s and 2.5x the average")
	m.shift_time = 180.0
	var mean_end := 0.0
	for i in 3000:
		mean_end += m.next_gap()
	mean_end /= 3000.0
	print("    end of shift: avg gap %.1fs" % mean_end)
	check(mean_end < mean_start * 0.7, "customers come faster near the end of the shift")
	var a = make(1)
	var b = make(2)
	a.start_shift(180.0)
	b.start_shift(180.0)
	var seq_a := []
	var seq_b := []
	for i in 10:
		seq_a.append(snappedf(a.next_gap(), 0.01))
		seq_b.append(snappedf(b.next_gap(), 0.01))
	check(seq_a != seq_b, "different shifts get different timing")
	for x in [m, a, b]:
		x.free()

	print("Line")
	m = make()
	m.start_shift(180.0)
	m.next_spawn = INF
	for i in 3:
		m._spawn()
		run(m, 0.3)
	check(m.line.size() == 3 and m.line.all(func(c): return c.state == Customer.State.IN_LINE), "3 customers walk in and line up")
	var front = m.line[0]
	var second = m.line[1]
	check(until(m, func(): return front.state == Customer.State.ORDERING), "front customer starts ordering by themselves at the register")
	check(front.position.distance_to(Manager.LINE_SPOTS[0]) < 1.0, "...standing at the register")
	check(until(m, func(): return m.waiting.size() == 1, Manager.ORDER_SECONDS + 0.5), "after ordering (%.1fs) they step aside to wait for their drink" % Manager.ORDER_SECONDS)
	check(m.line.size() == 2 and m.line[0] == second, "the line moves up: 2nd customer is now at the front")
	check(until(m, func(): return not front.is_walking() and not second.is_walking()), "everyone finishes walking")
	check(second.position.distance_to(Manager.LINE_SPOTS[0]) < 1.0, "2nd customer is at the register")
	check(front.position.distance_to(Manager.PICKUP_SPOTS[0]) < 1.0, "waiting customer stands at the first pickup spot")
	m.free()

	print("A whole busy shift")
	m = make(7)
	m.start_shift(180.0)
	var closest := [INF]
	var limits_ok := [true]
	var spawned := [0]
	m.child_entered_tree.connect(func(_c): spawned[0] += 1)
	run(m, 180.0, func():
		var cs := present(m)
		for i in cs.size():
			for j in range(i + 1, cs.size()):
				closest[0] = minf(closest[0], cs[i].position.distance_to(cs[j].position))
		if m.line.size() > Manager.LINE_SPOTS.size() or m.waiting.size() > Manager.PICKUP_SPOTS.size():
			limits_ok[0] = false
	)
	print("    %d customers came in; closest two ever got: %.0fpx (bodies touch at 34px)" % [spawned[0], closest[0]])
	check(spawned[0] >= 20, "a shift brings a steady stream of customers")
	check(closest[0] >= 34.0, "customers never walk into each other")
	check(limits_ok[0], "line and pickup spots never overflow")
	m.free()

	print("Leaving")
	m = make()
	m.start_shift(180.0)
	var angry := []
	var happy := []
	m.customer_left_angry.connect(func(c): angry.append(c))
	m.customer_served.connect(func(c): happy.append(c))
	m.next_spawn = INF
	for i in 3:
		m._spawn()
		run(m, 0.6)
	settle(m, 12.0)
	check(m.waiting.size() == 3, "3 customers ordered and are waiting")
	var first = m.waiting[0]
	var third = m.waiting[2]
	check(m.serve("tea") == false, "serving something nobody ordered does nothing")
	check(m.serve("drink") == true and happy == [first], "serving a drink: the one who waited longest leaves happy")
	settle(m, 2.0)
	check(m.waiting.size() == 2 and third.position.distance_to(Manager.PICKUP_SPOTS[1]) < 1.0, "the others shuffle over to make room")
	settle(m, 60.0)
	check(angry.size() == 2 and m.waiting.is_empty(), "when patience runs out they leave angry")
	check(present(m).is_empty(), "everyone is gone after leaving")
	m.free()

	print("Pause, end of round, new room")
	m = make()
	m.start_shift(180.0)
	m.next_spawn = INF
	m._spawn()
	m._process(0.5)
	var c0 = m.line[0]
	var before: Vector2 = c0.position
	m.set_paused(true)
	m._process(2.0)
	check(c0.position == before, "emergency meeting pause freezes customers")
	m.set_paused(false)
	m._process(0.5)
	check(c0.position != before, "they walk again after the meeting")
	m.stop_shift()
	before = c0.position
	m._process(1.0)
	check(c0.position == before and not m.running, "end of round: nobody new, everyone freezes")
	m._on_message({"type": "room_created"})
	check(m.line.is_empty() and m.waiting.is_empty(), "creating a new room clears the customers")
	m.free()

	print("Speech bubbles")
	var gap: float = Manager.PICKUP_SPOTS[1].x - Manager.PICKUP_SPOTS[0].x
	var talker = Customer.new()
	var widest := 0.0
	for drink in ["Latte", "Chai Latte", "Matcha Latte", "Vanilla Coffee", "Strawberry Matcha Latte"]:
		talker.recipe = drink
		widest = maxf(widest, talker.bubble_width())
	check(widest < gap, "even long drink names fit between pickup spots (widest bubble %.0fpx, spots %.0fpx apart)" % [widest, gap])
	talker.free()

	print("With Sruti's OrderManager")
	var src := GDScript.new()
	src.source_code = "extends Node\nsignal order_completed(customer)\nsignal order_expired(customer)\nvar calls := []\nfunc add_order(recipe, patience, customer):\n\tcalls.append([recipe, patience, customer])\n"
	src.reload()
	var om := Node.new()
	om.set_script(src)
	om.name = "OrderManager"
	root.add_child(om)
	m = make()
	m.start_shift(180.0)
	happy = []
	angry = []
	m.customer_served.connect(func(c): happy.append(c))
	m.customer_left_angry.connect(func(c): angry.append(c))
	m.next_spawn = INF
	m._spawn()
	m._spawn()
	settle(m, 10.0)
	var cust = m.waiting[0]
	check(om.calls.size() == 2 and om.calls[0][0] == "drink" and om.calls[0][2] == cust and is_equal_approx(om.calls[0][1], cust.patience_total), "orders go to OrderManager.add_order(recipe, patience, customer)")
	settle(m, 60.0)
	check(m.waiting.size() == 2 and angry.is_empty(), "OrderManager decides when orders expire, not the customer")
	check(m.serve("drink") == false, "serve() steps aside when OrderManager is in charge")
	om.order_completed.emit(cust)
	check(happy == [cust] and m.waiting.size() == 1, "order_completed -> customer leaves happy")
	om.order_expired.emit(m.waiting[0])
	check(angry.size() == 1 and m.waiting.is_empty(), "order_expired -> customer leaves angry")
	m.free()
	om.free()

	print("\n%d passed, %d failed" % [passes, failures])
	quit(1 if failures > 0 else 0)
