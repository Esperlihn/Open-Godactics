extends Node

@onready var main:Node = get_node("/root/Main")

#Variables from Main. These variables values will be assigned by main.gd
var map
var pathfinder
var mapedit

signal rollcall


func _ready() -> void:
	connect("rollcall", main._rollcall)
	emit_signal("rollcall", self)


func _unhandled_input(event: InputEvent) -> void:
	if event.get_class() == "InputEventMouseButton":
		match event.as_text():
			"Left Mouse Button":
				if event.pressed: 
					if pathfinder:
						var index = pathfinder.find_clicked_tile(event)
						if !index: return
						var movement = pathfinder.calc_movement_range(index)
						map.set_highlight(index)
						for mov_index in movement:
							map.set_highlight(mov_index)
			
			"Right Mouse Button":
				if event.pressed:
					if mapedit:
						var global_pos = map.get_global_mouse_position()
						mapedit.place_tile_from_mouse_pos(global_pos)
						print("Right Clicked")
			_:
				print(event.as_text(), " was pressed but has no assigned function")
