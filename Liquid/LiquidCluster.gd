class_name L_Cluster
extends RigidBody3D

const phys_update_ticks_interval = 40

var c_mass : float
var c_radius : float
var c_phys_ticks : int = randi_range(0, phys_update_ticks_interval)
func ResetTicks():
	c_phys_ticks = phys_update_ticks_interval

func get_colliders():
	return $'.'.get_colliding_bodies()

func UpdatePhysicalSize():
	var new_scale = Vector3(c_radius*2,c_radius*2,c_radius*2)
	$BoundsCollider.scale = new_scale
	$Node3D.scale = new_scale
	scale = new_scale
	mass = c_mass



# raycast ring segment stuff

var c_ring_heights : Array = []
const ring_height_step : float = 0.05

# private functions
func TestFillRingSegments(index : int):
	while (c_ring_heights.size() <= index): 
		c_ring_heights.push_back(0.0)

func SetRingHeight(index : int, new_height : float):
	TestFillRingSegments(index)
	c_ring_heights[index] = new_height

# public functions
func GetRingHeight(index : int) -> float:
	TestFillRingSegments(index)
	var curr_height = c_ring_heights[index]
	if curr_height > c_radius:
		c_ring_heights[index] = c_radius
		curr_height = c_radius
	return curr_height

func IncRingHeight(index : int):
	var next_height : float = GetRingHeight(index) + ring_height_step * c_radius
	if (next_height > c_radius): return
	SetRingHeight(index, next_height)
func DecRingHeight(index : int):
	var next_height : float = GetRingHeight(index) - ring_height_step * c_radius
	if (next_height <= 0): return
	SetRingHeight(index, next_height)
