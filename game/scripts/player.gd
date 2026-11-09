extends CharacterBody2D
## Host-authoritative physics player. Network sends normalized direction only.
const WALK_SPEED := 210.0
var player_number := 1
var color := Color.WHITE
var direction := Vector2.ZERO
var held_action := false
var held_sabotage := false
var last_action := false
var last_sabotage := false
var carried := ""
var impostor := false
var facing := Vector2.DOWN

func configure(number: int, is_impostor: bool) -> void:
	player_number = number
	impostor = is_impostor
	var palette := [Color("ffbd69"), Color("72d6ba"), Color("8eafff"), Color("ff8ab0")]
	color = palette[clampi(number - 1, 0, 3)]

func _ready() -> void:
	var shape := CircleShape2D.new()
	shape.radius = 19.0
	var collider := CollisionShape2D.new()
	collider.shape = shape
	add_child(collider)
	collision_layer = 1
	collision_mask = 2
	queue_redraw()

func _physics_process(_delta: float) -> void:
	velocity = direction.limit_length(1.0) * WALK_SPEED
	if direction.length_squared() > 0.02:
		facing = direction.normalized()
	move_and_slide()
	position = position.clamp(Vector2(28, 225), Vector2(930, 635))
	queue_redraw()

func _draw() -> void:
	# Simple animated character with eyes, feet and carried item. Replace with sprites later.
	var bob := sin(Time.get_ticks_msec() / 110.0) * 2.5 if velocity.length() > 3.0 else 0.0
	draw_circle(Vector2(-9, 17), 7, Color("253343"))
	draw_circle(Vector2(9, 17), 7, Color("253343"))
	draw_circle(Vector2(0, bob), 20, color)
	draw_circle(Vector2(-7, bob - 4), 4, Color.WHITE)
	draw_circle(Vector2(7, bob - 4), 4, Color.WHITE)
	draw_circle(Vector2(-7, bob - 3) + facing * 1.5, 1.7, Color("182c3b"))
	draw_circle(Vector2(7, bob - 3) + facing * 1.5, 1.7, Color("182c3b"))
	draw_string(ThemeDB.fallback_font, Vector2(-12, -27), "P%d" % player_number, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
	if not carried.is_empty():
		draw_circle(Vector2(20, -20), 9, Color("ffe8a3") if carried == "ingredient" else Color("ee8bba"))
		draw_string(ThemeDB.fallback_font, Vector2(15, -16), "I" if carried == "ingredient" else "D", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.BLACK)
