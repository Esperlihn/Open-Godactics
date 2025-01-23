extends Node

var nodes = []
var camera
var map
var rotater
var pathfinder
var mapeditor
var button_rotate_right
var button_rotate_left


func _ready() -> void:
	for node in nodes:
		if "map" in node: 
			printerr(node.name, "'s map variable was changed by main,gd!")
			node.map = map
		
		if "rotater" in node: 
			printerr(node.name, "'s rotater variable was changed!")
			node.rotater = rotater
		
		if "camera" in node: 
			printerr(node.name, "'s camera variable was changed by main,gd!")
			node.camera = camera
			
		if "pathfinder" in node: 
			printerr(node.name, "'s pathfinder variable was changed by main,gd!")
			node.pathfinder = pathfinder
		
		if "mapedit" in node:
			printerr(node.name, "'s mapedit variable was changed by main,gd!")
			node.mapedit = mapeditor


func _rollcall(node):
	printerr(node.name, " script connected to Main script")
	match node.name:
		"Map":
			map = node
			#return
		"Rotation":
			rotater = node
		"Camera":
			camera = node
		"Rotate Left":
			button_rotate_left = node
		"Rotate Right":
			button_rotate_right = node
		"Pathfinding":
			pathfinder = node
		"Mapedit":
			mapeditor = node
		_:
			printerr(node.name, " has no assigned variable in the Main script.")
	nodes.append(node)
