extends Camera2D

@onready var main:Node = get_node("/root/Main")

var panning = false
var pan_anchor

signal rollcall

func _ready() -> void:
	connect("rollcall", main._rollcall)
	emit_signal("rollcall", self)

	#$"../Camera/Canvas".set_size($"../Camera".get_canvas_transform()[2])
	#$"../Camera/Canvas".position = ($"../Camera".position - ($"../Camera/Canvas".size/2)) + Vector2(layer_height, 10)

func _unhandled_input(event: InputEvent) -> void:
	if event.get_class() == "InputEventMouseButton":
		match event.as_text():			
			"Middle Mouse Button":
				panning = event.pressed
				pan_anchor = get_global_mouse_position()

func _process(delta: float) -> void:
	if panning:
		position += pan_anchor - get_global_mouse_position()
