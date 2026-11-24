extends Resource
## A drink recipe (#29). Add new ones as .tres files in res://resources/recipes/.
@export var display_name := ""
@export var ingredients: Array[String] = []
@export var work_seconds := 3.0
@export var patience_seconds := 45.0
@export var color := Color.WHITE
