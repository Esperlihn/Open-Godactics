extends Node2D

@onready var astar = AStar3D.new()
@export var movement_range:int = 1
var atlas:Dictionary = {}
var map_max = null#:Vector2
var map_min = null#:Vector2
var map_height:int = 0
var map_size:Dictionary = {"x":0,"y":0}
var visible_tiles:Array:set = _update_visual_tiles
var highlights = []
var active_highlights = {}
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

var orientation:int:set = _change_orientation
var panning = false
var pan_anchor:Vector2


enum DIRECTION {RIGHT, LEFT}

var textures = {
	#"grass":Vector2i(0, 4),
	#"dirt":Vector2i(0, 10),
	#"grass_green":Vector2i(0,2)
	}

#region Startup Functions
func _ready() -> void:
	var timer = Time.get_ticks_msec()
	var used_tiles = _collect_used_tiles()
	
	orientation = 0
	
	$"../Camera/Canvas".set_size($"../Camera".get_canvas_transform()[2])
	$"../Camera/Canvas".position = ($"../Camera".position - ($"../Camera/Canvas".size/2)) + Vector2(layer_height, 10)
	
	for layer:TileMapLayer in get_children():
		var z = int(str(layer.name))
		layer.position.y = z * layer_height
		layer.z_index = z
	
	set_map_size()
	set_index_values()
	create_astar_grid()
	add_all_tiles_to_atlas(used_tiles)
	add_tiles_to_astar_grid()
	connect_astar_points()
	generate_highlights()
	%Rotate_Right.connect("rotate", _rotate_map)
	%Rotate_Left.connect("rotate", _rotate_map)
	
	print("Highlights: ", highlights.size())
	print("Atlas[0]: ", atlas[0])
	print("Total tiles: ", atlas.size())
	print("Visible Tiles: ", visible_tiles.size())
	
	print("Ready function took ", Time.get_ticks_msec() - timer, "ms to complete")
	print(visible_tiles.size())
	print(visible_tiles)

func _update_visual_tiles(index):
	if visible_tiles.has(index):
		return
	visible_tiles.append(index)

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
			"map":tile[0],
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
		var coord = Vector3(atlas[index].map.x, atlas[index].map.y, atlas[index].z)
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
			if abs(atlas[index].map.x - atlas[new_index].map.x) > 1 \
			or abs(atlas[index].map.y - atlas[new_index].map.y) > 1 \
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

#region Rotation Functions
func _rotate_map(direction):
	var time = Time.get_ticks_msec()
	print("----- Rotatate Direction = ", direction, " -----")
	match direction:
		"Rotate_Right":
			direction = DIRECTION.RIGHT
		"Rotate_Left":
			direction = DIRECTION.LEFT
	_rotate_camera(direction)
	clear_tilemaps()
	_rotate_visible_tiles(direction)
	_rotate_highlights()
	print("active highlights count ", active_highlights.size())
	print("Function:  rotate_map() ran in ", Time.get_ticks_msec() - time, "msec")
	#print(" ==========")

func _rotate_visible_tiles(direction):
	var layer:TileMapLayer
	var x:int
	var y:int
	
	for index in visible_tiles:
		layer = atlas[index].layer
		
		if direction == DIRECTION.RIGHT:
			x = -atlas[index].y
			y = atlas[index].x
			
		if direction == DIRECTION.LEFT:
			x = atlas[index].y
			y = -atlas[index].x
		
		layer.set_cell(Vector2(x,y), iso_set, atlas[index].texture) 
		atlas[index].x = x
		atlas[index].y = y
		atlas[index].map = Vector2(x,y)

func _rotate_camera(direction):
	var base_layer:TileMapLayer = get_child(0)
	var cam_coord:Vector2i = base_layer.local_to_map(%Camera.position)
	
	match direction:
		DIRECTION.RIGHT:
			%Camera.position = base_layer.map_to_local(Vector2(-cam_coord.y, cam_coord.x))
			orientation += 90
		DIRECTION.LEFT:
			%Camera.position = base_layer.map_to_local(Vector2(cam_coord.y, -cam_coord.x))
			orientation -= 90

func _rotate_highlights():
	var highlightstorotate = active_highlights.keys()

	clear_highlights()

	for index in highlightstorotate:
		var layer = atlas[index].layer
		var tile = atlas[index].map
		var z = int(str(layer.name))
		set_highlight(index)

	
func adjust_coord_for_orientation(coordinates:Vector2):
	match orientation:
		0, 360: 
			return Vector2i(coordinates.x,coordinates.y)
		90: 
			return Vector2i(coordinates.y, -coordinates.x)
		180:
			return Vector2i(-coordinates.x, -coordinates.y)
		270:
			return Vector2i(-coordinates.y, coordinates.x)
		_: 
			printerr("Orientation ", orientation, " is not a valid orientation value.")
			printerr("Durr")

func _change_orientation(new_value):
	if new_value >= 360: orientation = 0
	
	elif new_value <= -90: orientation = 270
	
	else:orientation = new_value
	
	print("Orientation = ", new_value)

#endregion



func clear_tilemaps():
	for layer:TileMapLayer in get_children():
		layer.clear()

func find_clicked_tile(event):
	var astarcoord:Vector3
	
	astarcoord = global_to_astarcoord(get_global_mouse_position())

	
	clear_highlights()
	
	if astarcoord == Vector3(-1,-1,-1):
		return
	
	var index = _calc_astar_index(astarcoord)
		
	var index_above = index + index_layer_value
	if atlas.get(index_above):
		printerr("Clicked tile is not navicable")
		return
	calc_movement_range(index)
	set_highlight(index)
	print("Neighbours: ", atlas[index].neighbours)
	print("Astar Neighbours: ", astar.get_point_connections(index))
	print("Click Index = ", index)
	#Check what tiles clicked tile is connected to. Maybe have it highlight them for debugging purposes.


func calc_movement_range(start_index):
	#Use the code below to get started on the movement range function. 
	var neighbours = astar.get_point_connections(start_index)
	var movement_array = {}
	var buffer = []
	var search_indexes = [start_index]
	
	var movement = movement_range
	
	while movement >= 0:
		for index in search_indexes:
			for neighbour in astar.get_point_connections(index):
				if atlas.get(neighbour + index_layer_value):
					continue
				if !buffer.has(neighbour):
					buffer.append(neighbour)
			movement_array[index] = index
			#set_highlight(index)
			#print("Index to Highlight: ", index)
		search_indexes = []
		search_indexes = buffer
		buffer = []
		movement -= 1
	for index in movement_array.keys():
		set_highlight(index)
	print("Highlights size: ", highlights.size())
	print("Movement Array Size = ", movement_array.keys().size())
	print("Active highlights size: ", active_highlights.keys().size())
	
	#for index in neighbours:
		#if !atlas.has(index):
			#printerr("Index ", index, " is NULL")
		#if atlas.has(index + index_layer_value):
			#continue
		#var layer = atlas[index].layer
		#var point = Vector2(
			#atlas[index].map.x, 
			#atlas[index].map.y,
			#)
		#set_highlight(index)

func set_highlight(index:int):
	if active_highlights.has(index):
		return
	var layer = atlas[index].layer
	if !layer:
		printerr("Index has no layer value!")
	var z = atlas[index].z
	var tile = atlas[index].map
	var highlight = highlights.pop_front()
	

	highlight.z_index = z
	highlight.position = layer.map_to_local(tile)
	highlight.position += Vector2(0, z * layer_height)
	highlight.visible = true
	
	active_highlights[index] = highlight
	#active_highlights.append(highlight)


func clear_highlights():
	for highlight in active_highlights.values():
		highlight.visible = false
		highlight.position = Vector2.ZERO
		highlights.append(highlight)
	active_highlights = {}
	print("----- Highlights Cleared -----")
	if active_highlights != {}:
		printerr("Active Highlights should be empty")
		printerr("Active Highlights: ", active_highlights)

#func set_tile(index, texture_coordinates=null):
	#var layer:TileMapLayer = atlas[index].layer
	#var cell = Vector2(atlas[index].map.x, atlas[index].map.y)
	#
	#if texture_coordinates == null:
			#texture_coordinates = atlas[index].texture
	#
	#layer.set_cell(cell, 2, texture_coordinates)
	#atlas[index].texture = texture_coordinates


func _unhandled_input(event: InputEvent) -> void:
	if event.get_class() == "InputEventMouseButton":
		match event.as_text():
			"Left Mouse Button":
				if event.pressed == true: 
					find_clicked_tile(event)
			
			"Middle Mouse Button":
				panning = event.pressed
				pan_anchor = get_global_mouse_position()
			
			"Right Mouse Button":
				if event.pressed == true:
					place_tile_from_mouse_pos(get_global_mouse_position())
					print("Right Clicked")
				#add_tile()
			_:
				print(event.as_text(), " was pressed but has no assigned function")

func _process(delta: float) -> void:
	if panning:
		%Camera.position += pan_anchor - get_global_mouse_position()



func global_to_astarcoord(global_pos:Vector2) -> Vector3:
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
	tile = adjust_coord_for_orientation(tile)
	tile = tile - map_min
	
	x = tile.x
	y = tile.y
	
	astarcoord = Vector3(x,y,z)

	if astarcoord == null:
		printerr("Clicked tile returned as null")
		return Vector3(-1, -1, -1)
	
	print("Selected Layer is ", z, " with Tile ", astarcoord)
	
	return astarcoord
	

func place_tile_from_mouse_pos(mouse_pos:Vector2, texture = null):
	var astarcoord:Vector3
	var x:int
	var y:int
	var z:int
	var map:Vector2
	var layer:TileMapLayer
	var index:int
	
	# Need to add the tile to Atlas
	
	if texture == null:
		texture = textures["Grass"]
	
	clear_highlights()
	
	astarcoord = global_to_astarcoord(mouse_pos)
	if astarcoord == Vector3(-1,-1,-1):
		return
	var old_index = index
	index = _calc_astar_index(astarcoord) + index_layer_value
	print("Astarcoord: ", astarcoord)
	print("Index: ", old_index)
	astarcoord += Vector3(0,0,1)
	if astarcoord.z >= map_height:
		printerr(" Cannot place tiles any higher! ")
		return
	
	x = astarcoord.x
	y = astarcoord.y
	z = astarcoord.z
	map = Vector2i(x, y) + map_min
	layer = get_child(z)

	match orientation:
		90:
			map = Vector2(-map.y, map.x)
		180:
			map = Vector2(-map.x, -map.y)
		270:
			map = Vector2(map.y, -map.x)
		360, 0:
			pass

	if !atlas.has(index):
		atlas[index] = {
			"map":map,
			"x":map.x,
			"y":map.y,
			"z":z,
			"layer":layer,
			"texture":texture,
			"neighbours":[],
		}
	
	layer.set_cell(map, 0, texture)
	visible_tiles.append(index)
	
	var neighbours = [
		index_move_right, 
		index_move_left, 
		index_move_forward, 
		index_move_back, 
	
		index_move_up,
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
	#connect_neighbors(neighbours)

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
		if abs(atlas[index].map.x - atlas[new_index].map.x) > 1 \
		or abs(atlas[index].map.y - atlas[new_index].map.y) > 1 \
		or abs(atlas[index].z - atlas[new_index].z) > 1:
			continue
		if index == 207:
			printerr("Index 207 CLEARED")
		#if !astar.has_point(new_index):
			#astar.add_point(new_index, astarcoord)
			#print("	Astar added point ", new_index)
		astar.connect_points(index, new_index)
		atlas[index].neighbours.append(new_index)
		print("Connected index ", index, " to index ", new_index)
		if !astar.are_points_connected(index, new_index):
			printerr("Astar Point connection FAILED")
	
	for neighbour in atlas[index].neighbours:
		if !astar.are_points_connected(index, neighbour):
			printerr("Points ", index, " and ", neighbour, " did not connect correctly in Astar node.")
	
	if check_if_tile_visible(old_index) == false:
		
		visible_tiles.remove_at((visible_tiles.find(old_index)))
	
	print("Visible Tiles Size: ", visible_tiles.size())
	print("Astar Neighbours: ", astar.get_point_connections(index))
	print("Atlas Neighbours: ", atlas[index].neighbours)
	# Need to add the tile to Astar
	# Need to connect the tile to Astar
	# Need to draw the tile

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
		

func _calc_astar_index(vec3:Vector3i):
	if vec3.x < 0 or vec3.y < 0:
		printerr("TRIED TO CALCULATE INDEX ON COORDINATE WITH VALUE BELOW 0!!!")
		print(vec3)
		return
	var x_value = vec3.x
	var y_value = map_size.x * vec3.y
	var z_value = map_size.x * map_size.y * vec3.z
	var index = z_value + y_value + x_value

	if index > index_max or index < 0:
		printerr("id value of ", index, " is not possible. Vector was ", vec3, " ", Vector3(x_value, y_value, z_value))
		return

	return index

func _mapcoord_to_astarcoord(x:int, y:int, z:int):
	x = x - map_min.x
	y = y - map_min.y
	return Vector3(x,y,z)

func find_index_z_value(index):
	#var layer_index_size = map_size.x * map_size.y
	var index_count = 0
	var z = 0
	while index > index_count:
		#index_count += layer_index_size
		z += 1
	return z

func index_to_globalcoord(index, layer:TileMapLayer = get_child(0)):
	return layer.map_to_local(atlas[index].map - map_min)
