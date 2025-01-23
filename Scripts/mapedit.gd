extends Node

@onready var main:Node = get_node("/root/Main")
@export var disabled = false

#Variables from Main. These variables values will be assigned by main.gd
var map

signal rollcall


func _ready() -> void:
	if disabled: return
	
	connect("rollcall", main._rollcall)
	emit_signal("rollcall", self)

func place_tile_from_mouse_pos(mouse_pos:Vector2, texture = null):
	var astarcoord:Vector3
	var x:int
	var y:int
	var z:int
	var coord:Vector2
	var layer:TileMapLayer
	var index:int
	
	# Need to add the tile to Atlas
	
	if texture == null:
		texture = map.textures["Grass"]
	
	map.clear_highlights()
	
	astarcoord = map._global_to_astarcoord(mouse_pos)
	if astarcoord == Vector3(-1,-1,-1):
		return
	var old_index = index
	index = map._calc_astar_index(astarcoord) + map.index_layer_value
	print("Astarcoord: ", astarcoord)
	print("Index: ", old_index)
	astarcoord += Vector3(0,0,1)
	if astarcoord.z >= map.map_height:
		printerr(" Cannot place tiles any higher! ")
		return
	
	x = astarcoord.x
	y = astarcoord.y
	z = astarcoord.z
	coord = Vector2i(x, y) + map.map_min
	layer = map.get_child(z)
	
	if map.rotater:
		match map.rotater.orientation:
			90:
				coord = Vector2(-coord.y, coord.x)
			180:
				coord = Vector2(-coord.x, -coord.y)
			270:
				coord = Vector2(coord.y, -coord.x)
			360, 0:
				pass

	if !map.atlas.has(index):
		map.atlas[index] = {
			"coord":coord,
			"x":coord.x,
			"y":coord.y,
			"z":z,
			"layer":layer,
			"texture":texture,
			"neighbours":[],
		}
	
	layer.set_cell(coord, 0, texture)
	map.visible_tiles.append(index)
	
	var neighbours = [
		map.index_move_right, 
		map.index_move_left, 
		map.index_move_forward, 
		map.index_move_back, 
	
		map.index_move_up,
		map.index_move_down,
		map.index_move_down_left,
		map.index_move_down_right,
		map.index_move_down_forward,
		map.index_move_down_back,
	
		map.index_move_up_left,
		map.index_move_up_right,
		map.index_move_up_forward,
		map.index_move_up_back,
	]
	#connect_neighbors(neighbours)

	for neighbour in neighbours:
		var new_index = index + neighbour

		#If the new neighbour doesn't exist in the Atlas, or 
		if !map.atlas.has(new_index):
			continue

		# If the index is negative...somehow.
		if new_index < 0:
			printerr("How in the FUCK did you get a negative index value??")
			printerr("This shouldn't even be possible!")
			printerr("Index: ", index, " New Index", new_index)
			continue

		# If the new neighbour is more than 1 tile away
		if abs(map.atlas[index].coord.x - map.atlas[new_index].coord.x) > 1 \
		or abs(map.atlas[index].coord.y - map.atlas[new_index].coord.y) > 1 \
		or abs(map.atlas[index].z - map.atlas[new_index].z) > 1:
			continue
		if index == 207:
			printerr("Index 207 CLEARED")
		#if !astar.has_point(new_index):
			#astar.add_point(new_index, astarcoord)
			#print("	Astar added point ", new_index)
		map.astar.connect_points(index, new_index)
		map.atlas[index].neighbours.append(new_index)
		print("Connected index ", index, " to index ", new_index)
		if !map.astar.are_points_connected(index, new_index):
			printerr("Astar Point connection FAILED")
	
	for neighbour in map.atlas[index].neighbours:
		if !map.astar.are_points_connected(index, neighbour):
			printerr("Points ", index, " and ", neighbour, " did not connect correctly in Astar node.")
	
	if map.check_if_tile_visible(old_index) == false:
		
		map.visible_tiles.remove_at((map.visible_tiles.find(old_index)))
	
	print("Visible Tiles Size: ", map.visible_tiles.size())
	print("Astar Neighbours: ", map.astar.get_point_connections(index))
	print("Atlas Neighbours: ", map.atlas[index].neighbours)
	# Need to add the tile to Astar
	# Need to connect the tile to Astar
	# Need to draw the tile
