extends Node
## Open orders, satisfaction meter and shift timer (#30).
## Orders come from customers (#27) via add_order(); until then main.gd spawns test orders.
signal order_added(order)
signal order_completed(customer)
signal order_expired(customer)
signal satisfaction_changed(value)
signal shift_ended(won: bool)

const MAX_SATISFACTION := 100
const ON_TIME_BONUS := 6
const WRONG_PENALTY := 10
const EXPIRED_PENALTY := 15

var orders: Array = []   # each: {recipe, patience, left, customer}
var satisfaction := MAX_SATISFACTION
var shift_length := 180.0
var time_left := 180.0
var served := 0
var paused := false      # emergency meetings (#22) set this to freeze everything
var running := false

func start_shift(length: float = 180.0) -> void:
	orders.clear()
	shift_length = length
	time_left = length
	satisfaction = MAX_SATISFACTION
	served = 0
	paused = false
	running = true
	satisfaction_changed.emit(satisfaction)

func set_paused(value: bool) -> void:
	paused = value

func add_order(recipe: Resource, patience_seconds: float, customer = null) -> void:
	var order := {"recipe": recipe, "patience": patience_seconds, "left": patience_seconds, "customer": customer}
	orders.append(order)
	order_added.emit(order)

## Returns true if the drink matched an open order (oldest matching first).
func serve(drink_recipe: Resource) -> bool:
	for order in orders:
		if order["recipe"] == drink_recipe:
			orders.erase(order)
			served += 1
			change_satisfaction(ON_TIME_BONUS)
			order_completed.emit(order["customer"])
			return true
	change_satisfaction(-WRONG_PENALTY)
	return false

func change_satisfaction(amount: int) -> void:
	satisfaction = clampi(satisfaction + amount, 0, MAX_SATISFACTION)
	satisfaction_changed.emit(satisfaction)
	if satisfaction <= 0:
		_end(false)

func _process(delta: float) -> void:
	if not running or paused:
		return
	time_left -= delta
	for order in orders.duplicate():
		order["left"] -= delta
		if order["left"] <= 0.0:
			orders.erase(order)
			change_satisfaction(-EXPIRED_PENALTY)
			order_expired.emit(order["customer"])
	if running and time_left <= 0.0:
		_end(true)

func _end(won: bool) -> void:
	if not running:
		return
	running = false
	shift_ended.emit(won)
