extends RefCounted
## what the player can carry. players hold one at a time.
enum Kind { INGREDIENT, DRINK }

var kind: int = Kind.INGREDIENT
var id := ""            # ingredient id ("coffee") or recipe name for drinks
var label := ""
var color := Color.WHITE
var recipe: Resource = null  # set for finished drinks

static func ingredient(ingredient_id: String, display: String, tint: Color):
	var it = load("res://scripts/item.gd").new()
	it.kind = Kind.INGREDIENT
	it.id = ingredient_id
	it.label = display
	it.color = tint
	return it

static func drink(r: Resource):
	var it = load("res://scripts/item.gd").new()
	it.kind = Kind.DRINK
	it.id = r.display_name
	it.label = r.display_name
	it.color = r.color
	it.recipe = r
	return it
