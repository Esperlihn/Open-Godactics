extends Button

signal rotate

func _ready() -> void:
	connect("pressed", _rotate)

func _rotate() -> void:
	print(name)
	emit_signal("rotate", name)
