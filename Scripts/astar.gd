extends Node2D

@onready var astar = AStar3D.new()
@onready var main:Node = get_node("/root/Main")
@export var movement_range:int = 1

var atlas:Dictionary = {}
var map_max = null#:Vector2
var map_min = null#:Vector2
var map_height:int = 0
var map_size:Dictionary = {"x":0,"y":0}
var visible_tiles:Array:set = _add_visual_tile
var highlights = []
var active_highlights = {}
var textures = {
	#"Grass":Vector2i(0, 4),
	}
var layer_height = -8
const iso_set:int = 0


var index_layer_value:int
var index_column_value:int
var index_max:int = 0
var index_move_right:int
var index_move_left:int
var index_move_forward:int
var index_move_back:int
var index_move_up:int
var index_move_up_right:int
var index_move_up_left:int
var index_move_up_forward:int
var index_move_up_back:int
var index_move_down_right:int
var index_move_down_left:int
var index_move_down_forward:int
var index_move_down_back:int
var index_move_down:int

#Variables from Main. These variables values will be assigned by main.gd
var rotater
var camera

signal rollcall


func _ready() -> void:
	var timer = Time.get_ticks_msec()
	var used_tiles = _collect_used_tiles()
	
	connect("rollcall", main._rollcall)
	emit_signal("rollcall", self)
	align_tilemaps()
	set_map_size()
	set_index_values()
	create_astar_grid()
	add_all_tiles_to_atlas(used_tiles)
	add_tiles_to_astar_grid()
	connect_astar_points()
	generate_highlights()
	
	print("Highlights: ", highlights.size())
	print("Atlas[0]: ", atlas[0])
	print("Total tiles: ", atlas.size())
	print("Visible Tiles: ", visible_tiles.size())
	print("Ready function took ", Time.get_ticks_msec() - timer, "ms to complete")

#region Startup Functions
func align_tilemaps():
	for layer:TileMapLayer in get_children():
		var z = int(str(layer.name))
		layer.position.y = z * layer_height
		layer.z_index = z

func generate_highlights():
	for i in index_layer_value * 2:
		var highlight = Sprite2D.new()
		highlight.texture = load("res://Resources/isometric tileset/spritesheet.png")
		highlight.region_enabled = true
		highlight.visible = false
		highlight.region_rect = Rect2(288, 304, 32, 16)
		get_parent().add_child.call_deferred(highlight)
		highlight.position = Vector2.ZERO
		highlights.append(highlight)
	
func _collect_used_tiles():
	var array = []
	map_height = get_child_count()
	for layer:TileMapLayer in get_children():
		
		for tile in layer.get_used_cells():
			#print(tile, layer.name)
			var texture:String = layer.get_cell_tile_data(tile).get_custom_data("name")
			
			if texture == "":
				var err = str("TILE ",layer.get_cell_atlas_coords(tile), " IN TILESET SOURCE ",\
				layer.get_cell_source_id(tile), " HAS NO ASSIGNED NAME. Please assign a name to", \
				" this tile and then run the program again :)")
				
				printerr(err)
				push_error(err)
				printerr("BREAKPOINT")
				
			if !textures.has(texture):
				textures[texture] = layer.get_cell_atlas_coords(tile)

			array.append([tile, layer, texture])
		
		set_map_minmax_values(layer) 
		
	print("Visible tiles: ", visible_tiles.size())
	return array

func create_astar_grid():
	var timer2 = Time.get_ticks_msec()
	for z in range(0, map_height):
		for y in range(0, map_max.y-map_min.y + 1):
			for x in range(0, map_max.x-map_min.x + 1):
				astar.add_point(_calc_astar_index(Vector3(x,y,z)), Vector3(x,y,z))
	print("Astar point count: ", astar.get_point_count())
	print("Astar grid creation took ", Time.get_ticks_msec() - timer2, "msec")

func add_all_tiles_to_atlas(used_tiles):
	print("Used Tiles[0]: ", used_tiles[0])
	for tile in used_tiles:
		var x:int = tile[0].x
		var y:int = tile[0].y
		var z:int = int(str(tile[1].name))
		var layer:TileMapLayer = tile[1]
		var texture:String = tile[2]
		var astarcoord:Vector3 = _mapcoord_to_astarcoord(x, y, z)
		var index:int = _calc_astar_index(astarcoord)
		
		atlas[index] = {
			"coord":tile[0],
			"x":x,
			"y":y,
			"z":z,
			"layer":layer,
			"texture":textures[texture],
			"neighbours":[],
		}

func set_map_minmax_values(layer:TileMapLayer):
	for point in layer.get_used_cells():
		if map_max == null:
			map_max = point
			map_min = point
			continue

		if point.x > map_max.x: map_max.x = point.x
		elif point.x < map_min.x: map_min.x = point.x
		
		if point.y > map_max.y: map_max.y = point.y
		elif point.y < map_min.y: map_min.y = point.y

func set_map_size():
	map_size.x = (map_max.x - map_min.x) + 1
	map_size.y = (map_max.y - map_min.y) + 1
	
	if map_size.x < 0 or map_size.y < 0:
		printerr("Map size below 0, this should not be possible. Please check values")

func set_index_values():
	index_column_value = map_size.y
	index_layer_value = map_size.x * map_size.y
	index_max = map_size.x * map_size.y * map_height
	
	index_move_left = -1
	index_move_right = 1
	index_move_forward = -map_size.x
	index_move_back = map_size.x
	index_move_down = (map_size.x * map_size.y) * -1
	index_move_up = map_size.x * map_size.y
	
	index_move_down_left = index_move_down + index_move_left
	index_move_down_right = index_move_down + index_move_right
	index_move_down_forward = index_move_down + index_move_forward
	index_move_down_back = index_move_down + index_move_back


	index_move_up_left = index_move_up + index_move_left
	index_move_up_right = index_move_up + index_move_right
	index_move_up_forward = index_move_up + index_move_forward
	index_move_up_back = index_move_up + index_move_back

func add_tiles_to_astar_grid():
	for index in atlas.keys():
		if index == null: continue
		var coord = Vector3(atlas[index].coord.x, atlas[index].coord.y, atlas[index].z)
		astar.add_point(index, coord)
	print("Astar point count: ", astar.get_point_count())

func connect_astar_points():
	var neighbours_visible = [
		index_move_right, 
		index_move_left, 
		index_move_forward, 
		index_move_back, 
	
		index_move_up,
		]
		
	var neighbours_other = [
		index_move_down,
		index_move_down_left,
		index_move_down_right,
		index_move_down_forward,
		index_move_down_back,
	
		index_move_up_left,
		index_move_up_right,
		index_move_up_forward,
		index_move_up_back,
	]
	connect_neighbors(neighbours_visible, true) #This is used to determine while tiles don't need to be drawn
	connect_neighbors(neighbours_other) # This then connects everything else.

func connect_neighbors(neighbours, countneighbours = false):
	for index in atlas.keys():
		var count = 0
		for neighbour in neighbours:
			var new_index = index + neighbour

			#If the new neighbour doesn't exist in the Atlas, or 
			if !atlas.has(new_index):
				continue

			# If the index is negative...somehow.
			if new_index < 0:
				printerr("How in the FUCK did you get a negative index value??")
				printerr("This shouldn't even be possible!")
				printerr("Index: ", index, " New Index", new_index)
				continue

			# If the new neighbour is more than 1 tile away
			if abs(atlas[index].coord.x - atlas[new_index].coord.x) > 1 \
			or abs(atlas[index].coord.y - atlas[new_index].coord.y) > 1 \
			or abs(atlas[index].z - atlas[new_index].z) > 1:
				continue

			astar.connect_points(index, new_index)
			atlas[index].neighbours.append(new_index)
			count += 1
		
		if countneighbours == true:
			if count >= 5:
				continue
			else:
				visible_tiles.append(index)
#endregion

#region Setget Functions
func _add_visual_tile(index): # Whenever a new tile is added to the visual tiles array
	if visible_tiles.has(index):
		return
	visible_tiles.append(index)
#endregion

#region Regular Functions
func clear_tilemaps():
	for layer:TileMapLayer in get_children():
		layer.clear()

func clear_highlights():
	for highlight in active_highlights.values():
		highlight.visible = false
		highlight.position = Vector2.ZERO
		highlights.append(highlight)
	active_highlights = {}
	if active_highlights != {}:
		printerr("Active Highlights should be empty")
		printerr("Active Highlights: ", active_highlights)

func set_highlight(index:int):
	if active_highlights.has(index):
		return
	var layer = atlas[index].layer
	if !layer:
		printerr("Index has no layer value!")
	var z = atlas[index].z
	var tile = atlas[index].coord
	var highlight = highlights.pop_front()
	

	highlight.z_index = z
	highlight.position = layer.map_to_local(tile)
	highlight.position += Vector2(0, z * layer_height)
	highlight.visible = true
	print("TILE: ", tile)
	
	active_highlights[index] = highlight
#endregion

#region PATHFINDING
#func set_tile(index, texture_coordinates=null):
	#var layer:TileMapLayer = atlas[index].layer
	#var cell = Vector2(atlas[index].map.x, atlas[index].map.y)
	#
	#if texture_coordinates == null:
			#texture_coordinates = atlas[index].texture
	#
	#layer.set_cell(cell, 2, texture_coordinates)
	#atlas[index].texture = texture_coordinates

func check_if_tile_visible(index) -> bool:
	var neighbours = [
		index_move_right, 
		index_move_left, 
		index_move_forward, 
		index_move_back, 
		index_move_up
		]
	
	var count = 0
	
	for neighbour in neighbours:
		var new_index = index + neighbour
		if atlas.has(new_index): 
			count += 1
			
	if count >= 5:
		print("Index ", index, " no longer visible")
		return false
	else: 
		return true

#endregion

#region COORRDINATE CONVERSIONS
func _global_to_astarcoord(global_pos:Vector2) -> Vector3:
	var x:int
	var y:int
	var z:int
	var tile = null
	var astarcoord
	

	
	for layer:TileMapLayer in get_children():
		var click_pos = layer.local_to_map(global_pos - Vector2(0, layer.position.y))
		if layer.get_cell_tile_data(click_pos) == null:
			continue
		tile = click_pos
		z = int(str(layer.name))
	
	if tile == null:
		printerr("You fucked upppp")
		return Vector3(-1,-1,-1)
	
	# Order matters: This function must be run after getting the click_pos but before adding the 
	# map_min value back into the variable
	if rotater: 
		tile = rotater.adjust_coord_for_orientation(tile)
	
	tile = tile - map_min
	
	x = tile.x
	y = tile.y
	
	astarcoord = Vector3(x,y,z)

	if astarcoord == null:
		printerr("Clicked tile returned as null")
		return Vector3(-1, -1, -1)
	
	print("Selected Layer is ", z, " with Tile ", astarcoord)
	
	return astarcoord

func _mapcoord_to_astarcoord(x:int, y:int, z:int) -> Vector3:
	x = x - map_min.x
	y = y - map_min.y
	return Vector3(x,y,z)

func _calc_astar_index(astarcoord:Vector3i) -> int:
	if astarcoord.x < 0 or astarcoord.y < 0:
		printerr("TRIED TO CALCULATE INDEX ON COORDINATE WITH VALUE BELOW 0!!!")
		print(astarcoord)
		return -1
	var x_value = astarcoord.x
	var y_value = map_size.x * astarcoord.y
	var z_value = map_size.x * map_size.y * astarcoord.z
	var index = z_value + y_value + x_value

	if index > index_max or index < 0:
		printerr("id value of ", index, " is not possible. Vector was ", astarcoord, " ", Vector3(x_value, y_value, z_value))
		return -1

	return index

func _global_to_index(global_pos:Vector2) -> int:
	var astarcoord = _global_to_astarcoord(global_pos)
	var index:int = _calc_astar_index(astarcoord)
	return index

func _index_to_globalcoord(index, layer:TileMapLayer = get_child(0)) -> Vector2:
	return layer.map_to_local(atlas[index].coord - map_min)

func _find_index_z_value(index) -> int:
	var index_count = 0
	var z = 0
	while index > index_count:
		z += 1
		index_count += index_layer_value
	return z
#endregion
