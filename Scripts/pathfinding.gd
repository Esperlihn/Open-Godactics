extends Node

@onready var main:Node = get_node("/root/Main")
@export var disabled = false

#Variables from Main. These variables values will be assigned by main.gd
var map

signal rollcall


func _ready() -> void:
	if disabled:
		printerr("Pathfinding disabled!")
		return
	connect("rollcall", main._rollcall)
	emit_signal("rollcall", self)

func find_clicked_tile(event):
	var global_pos = map.get_global_mouse_position()
	var astarcoord = map._global_to_astarcoord(global_pos)
	
	if astarcoord == Vector3(-1,-1,-1):
		printerr("Selected tile is NOT valid")
		return
	
	map.clear_highlights()
	
	var index = map._calc_astar_index(astarcoord)
	var index_above = index + map.index_layer_value
	if map.atlas.get(index_above):
		printerr("Clicked tile is not navicable")
		return
		
	print("Index clicked: ", index)
	return index

func calc_movement_range(start_index) -> Array:
	#Use the code below to get started on the movement range function. 
	var neighbours = map.astar.get_point_connections(start_index)
	var movement_dict = {}
	var buffer = []
	var search_indexes = [start_index]
	
	var movement = map.movement_range
	
	while movement >= 0:
		for index in search_indexes:
			for neighbour in map.astar.get_point_connections(index):
				if map.atlas.get(neighbour + map.index_layer_value):
					continue
				if !buffer.has(neighbour):
					buffer.append(neighbour)
			movement_dict[index] = index
		search_indexes = []
		search_indexes = buffer
		buffer = []
		movement -= 1
	
	return movement_dict.keys()
