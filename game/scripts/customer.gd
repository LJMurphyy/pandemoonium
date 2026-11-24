extends Node2D
## One café customer (#27). CustomerManager tells it where to go; this script walks there,
## counts down patience while it waits for its drink, and shows how it feels.
## Drawn with shapes for now; swap in Logan's sprites later.
enum State { IN_LINE, ORDERING, WAITING, LEAVING }
const WALK_SPEED := 130.0
const FADE_SPEED := 1.6 # leaving customers fade out over about 0.6s
const BUBBLE_FONT_SIZE := 12
const BUBBLE_MAX_WIDTH := 52.0 # pickup spots are 55 px apart, so bubbles never touch
var state := State.IN_LINE
var recipe := ""
var patience_total := 1.0
var patience_left := 1.0
var happy := true
var color := Color.WHITE
var path: Array[Vector2] = []

func setup(start: Vector2, wanted: String, patience: float, tint: Color) -> void:
	position = start
	recipe = wanted
	patience_total = maxf(0.1, patience)
	patience_left = patience_total
	color = tint

## Walk through these points in order (replaces any walk in progress).
func walk_to(points: Array) -> void:
	path.clear()
	for p in points:
		path.append(p)

func is_walking() -> bool:
	return not path.is_empty()

## Step back out of the way and fade out. Frees itself when done.
func leave(was_happy: bool) -> void:
	state = State.LEAVING
	happy = was_happy
	walk_to([position + Vector2(0, 45)])

## Called by CustomerManager every frame (or by tests with fake time).
func tick(delta: float) -> void:
	var step := WALK_SPEED * delta
	while step > 0.0 and not path.is_empty():
		var gap := position.distance_to(path[0])
		if gap <= step:
			position = path.pop_front()
			step -= gap
		else:
			position = position.move_toward(path[0], step)
			step = 0.0
	if state == State.WAITING:
		patience_left = maxf(0.0, patience_left - delta)
	elif state == State.LEAVING:
		modulate.a -= FADE_SPEED * delta
		if modulate.a <= 0.0:
			queue_free()
	queue_redraw()

func _draw() -> void:
	var bob := sin(Time.get_ticks_msec() / 120.0) * 2.0 if is_walking() else 0.0
	var upset := (state == State.LEAVING and not happy) or (state == State.WAITING and patience_left < patience_total * 0.3)
	var body := color.lerp(Color("e06666"), 0.45) if upset else color
	var ink := Color("1c2636")
	draw_circle(Vector2(-7, 15), 6, Color("3a2f2a"))
	draw_circle(Vector2(7, 15), 6, Color("3a2f2a"))
	draw_circle(Vector2(0, bob), 17, body)
	draw_circle(Vector2(-6, bob - 4), 2.2, ink)
	draw_circle(Vector2(6, bob - 4), 2.2, ink)
	if upset:
		draw_arc(Vector2(0, bob + 10), 5, PI * 1.15, PI * 1.85, 8, ink, 2.0)
	else:
		draw_arc(Vector2(0, bob + 3), 5, PI * 0.15, PI * 0.85, 8, ink, 2.0)
	if state == State.ORDERING or state == State.WAITING:
		_draw_bubble(ink)

## Speech bubble with what they ordered, with their patience bar along the bottom while they
## wait. One word per line keeps long names ("Vanilla Coffee") narrower than the gap between
## pickup spots, so neighbours' bubbles never cover each other.
func _draw_bubble(ink: Color) -> void:
	var words := recipe.split(" ", false)
	if words.is_empty():
		return
	var font := ThemeDB.fallback_font
	var size := bubble_font_size()
	var w := bubble_width()
	var line := font.get_ascent(size) + 1.0 # tight spacing: names are only a word or two
	var bar := 6.0 if state == State.WAITING else 0.0
	var h := 4.0 + line * words.size() + bar
	var top := -20.0 - h # sits just above the head
	draw_rect(Rect2(-w / 2.0, top, w, h), Color.WHITE)
	draw_rect(Rect2(-w / 2.0, top, w, h), ink, false, 1.0)
	for i in words.size():
		draw_string(font, Vector2(-w / 2.0, top + 1.0 + line * (i + 1)), words[i], HORIZONTAL_ALIGNMENT_CENTER, w, size, ink)
	if state == State.WAITING:
		# Patience bar: green when fresh, red when about to give up.
		var f := patience_left / patience_total
		draw_rect(Rect2(-w / 2.0 + 2.0, top + h - 5.0, (w - 4.0) * f, 3.0), Color("e06666").lerp(Color("7bd389"), f))

## Biggest font size (up to BUBBLE_FONT_SIZE) that keeps every word of the order inside BUBBLE_MAX_WIDTH.
func bubble_font_size() -> int:
	var words := recipe.split(" ", false)
	var size := BUBBLE_FONT_SIZE
	while size > 8 and _widest(words, size) + 8.0 > BUBBLE_MAX_WIDTH:
		size -= 1
	return size

## Width of the speech bubble in pixels.
func bubble_width() -> float:
	return _widest(recipe.split(" ", false), bubble_font_size()) + 8.0

func _widest(words: PackedStringArray, size: int) -> float:
	var widest := 0.0
	for word in words:
		widest = maxf(widest, ThemeDB.fallback_font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x)
	return widest
