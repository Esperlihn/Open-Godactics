extends Area2D

@onready var main:Node = get_node("/root/Main")
@export var disabled = false
signal rollcall


func _ready() -> void:
	if disabled:
		visible = false
		printerr("Cursor disabled!")
		return
	connect("rollcall", main._rollcall)
	emit_signal("rollcall", self)
	z_index = 99
	
func _process(delta: float) -> void:
	position = get_global_mouse_position()
	#get_ov
