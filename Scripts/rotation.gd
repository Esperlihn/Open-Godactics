extends Node

@onready var main:Node = get_node("/root/Main")
@export var disabled = false

var orientation:int:set = _change_orientation

#Variables from Main. These variables values will be assigned by main.gd
var map

enum DIRECTION {RIGHT, LEFT}

signal rollcall


func _ready() -> void:
	if disabled:
		%Button_Rotate_Right.visible = false
		%Button_Rotate_Left.visible = false
		printerr("Rotation disabled!")
		return
	connect("rollcall", main._rollcall)
	%Button_Rotate_Right.connect("rotate", _rotate_map)
	%Button_Rotate_Left.connect("rotate", _rotate_map)
	emit_signal("rollcall", self)

func _rotate_map(rotate_button):
	var time = Time.get_ticks_msec()
	var direction
	print("----- Rotate Direction = ", direction, " -----")
	match rotate_button:
		"Button_Rotate_Right":
			direction = DIRECTION.RIGHT
		"Button_Rotate_Left":
			direction = DIRECTION.LEFT
			
	_rotate_camera(direction)
	map.clear_tilemaps()
	_rotate_visible_tiles(direction)
	_rotate_highlights()
	print("Function:  rotate_map() ran in ", Time.get_ticks_msec() - time, "msec")

func _rotate_camera(direction):
	var base_layer:TileMapLayer = map.get_child(0)
	var cam_coord:Vector2i = base_layer.local_to_map(main.camera.position)
	
	match direction:
		DIRECTION.RIGHT:
			main.camera.position = base_layer.map_to_local(Vector2(-cam_coord.y, cam_coord.x))
			#%Camera.position = Vector2(-%Camera.position.y, %Camera.position.x)
			orientation += 90
		DIRECTION.LEFT:
			main.camera.position = base_layer.map_to_local(Vector2(cam_coord.y, -cam_coord.x))
			#%Camera.position = Vector2(%Camera.position.y, -%Camera.position.x)
			orientation -= 90

func _rotate_visible_tiles(direction):
	var layer:TileMapLayer
	var x:int
	var y:int
	
	for index in map.visible_tiles:
		layer = map.atlas[index].layer
		
		if direction == DIRECTION.RIGHT:
			x = -map.atlas[index].y
			y = map.atlas[index].x
			
		if direction == DIRECTION.LEFT:
			x = map.atlas[index].y
			y = -map.atlas[index].x
		
		layer.set_cell(Vector2(x,y), map.iso_set, map.atlas[index].texture) 
		map.atlas[index].x = x
		map.atlas[index].y = y
		map.atlas[index].coord = Vector2(x,y)
	
func _rotate_highlights():
	var highlightstorotate = map.active_highlights.keys()

	map.clear_highlights()

	for index in highlightstorotate:
		var layer = map.atlas[index].layer
		var tile = map.atlas[index].coord
		var z = int(str(layer.name))
		map.set_highlight(index)

func _change_orientation(new_value):
	if new_value >= 360: orientation = 0
	
	elif new_value <= -90: orientation = 270
	
	else:orientation = new_value
	
	print("Orientation = ", new_value)

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
