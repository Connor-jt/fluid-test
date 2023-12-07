extends MeshInstance3D

var material = $".".get_surface_override_material(0)
func UpdateColor(input:Color):
	material.albedo_color = input
	#$".".set_surface_override_material(0, material)

# Called when the node enters the scene tree for the first time.
func _ready():
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
