extends Node3D

const min_water_height_to_spread:float = 0.005
const dispersal_per_second:float = 5

const fluid_tile_size:float = 1
const fluid_height_padding:float = 0.4

const max_water_height_cast:float = 100.0

var demo_obj:PackedScene = load("res://Fluid/demo_cluster.tscn")

const neighbour_offsets:Array = [
	{x= 0,y= 1}, 
	{x= 0,y=-1}, 
	{x= 1,y= 0}, 
	{x=-1,y= 0}]

var fluid_coords:Dictionary = {}
#var fluid_queue:Dictionary = {}

class fluid_obj:
	var water_height:float = NAN # this determines the height of the water off of the ground point
	var world_height:float = NAN # this determines the gound point for this coord
	var connections:int = 0 # flags to determine which connections are valid for passing fluid through
	#var momentum_x:float
	#var momentum_y:float
	# why is the smallest thing an int (64 BITS??)???
	# store all the special values as unpacked for now, we can pack them into the connections data int when we optimize
	#var invalid:bool = true # if valid but not connected then below this point is the void?
	var grounded:bool = false
	var update:bool = true
	var mesh = null
	
	# property functions
	func Connection(index:int) -> bool: # use '1' to indicate that this connection is valid, '0' for invalid
		assert(index < 4 && index >= 0)
		return connections & (1 << index)
	func SetConnection(index:int, is_valid:bool) -> void:
		assert(index < 4 && index >= 0)
		var bit_mask:int = 1 << index
		if is_valid: connections |= bit_mask
		else: connections &= ~bit_mask
	func HasConnection() -> bool:
		var test:bool = Connection(0) || Connection(1) || Connection(2) || Connection(3)
		return test
	
	func NeedsUpdate() -> bool:
		return update
	func RequestUpdate():
		update = true
	func ClearUpdate():
		update = false
	
	func HasGround() -> bool:
		return grounded
	func SetGrounded(is_grounded:bool):
		grounded = is_grounded
	# random functions
	func GetHeight() -> float:
		var height:float = world_height
		if HasGround(): height += water_height
		return height
	func GetHeightAbove(compare_fluid:fluid_obj) -> float:
		if compare_fluid == null || !compare_fluid.HasGround():
			return 0.0
		
		var com_height = compare_fluid.GetHeight()
		var our_height = GetHeight()
		
		if (com_height >= our_height): return 0.0
		return our_height - com_height
	
	func DisperseTo(cluster:fluid_obj, max:float):
		if !(HasConnection() && HasGround() && cluster.HasConnection() && cluster.HasGround()): # this is not sufficient to test whether these are actually connected though
			return
		cluster.UpdateVolume(max)
		UpdateVolume(-max)
		# TDDO: put stuff here to destroy water when it fully disperses?
	
	func UpdateVolume(change_in_height:float):
		assert(HasGround())
		water_height += change_in_height
		UpdateDemoPos()
		RequestUpdate()
	func UpdateDemoPos():
		mesh.position.y = GetHeight()
	func SetDemoPos(x:float, y:float): # to be removed
		mesh.position = Vector3(x, 0, y)
		UpdateDemoPos()
	func UpdateDemoColor():
		mesh.UpdateColor(Color(float(!HasGround()), float(HasConnection()), float(NeedsUpdate())))

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


var create_tick_max = 60
var create_ticks = 60
var volume_to_create = 2

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	create_ticks -= 1
	if create_ticks == 0:
		create_ticks = create_tick_max
		ApplyFluid(0,0, 0, volume_to_create)
		volume_to_create += 8 + (volume_to_create * 0.3)
	
	# first we disperse all elements to neighbours
	for key in fluid_coords: # 'fluid_obj'
		var fluid:fluid_obj = fluid_coords[key]
		var x:int = (key & 0x7fffffffffffffff) >> 32 # sign has to be positive
		var y:int = key & 0xffffffff
		# fix the dumb issue where we cant bitshift negative numbers
		if key & -9223372036854775808 != 0:
			x |= -2147483648 # also extend sign bit
		if key & 0x80000000:
			y |= -4294967296 # extend sign bit
		TryConnections(fluid, x,y)
		TryGround(fluid, x,y)
		TryDisperse(fluid, x, y, delta)
		fluid.UpdateDemoColor()

func TryGround(fluid:fluid_obj, x:int, y:int):
	if !fluid.NeedsUpdate(): 
		return # no updated needed, this coord is settled
	# iterate for neighbours that are grounded
	var neighbours_grounded:bool = false
	for index in range(0, 4):
		var offset_cx = Coord(x + neighbour_offsets[index].x)
		var offset_cy = Coord(y + neighbour_offsets[index].y)
		
		var neighbour = FluidAt(x + neighbour_offsets[index].x, y + neighbour_offsets[index].y)
		if neighbour != null && neighbour.HasGround() && fluid.Connection(index):
			neighbours_grounded = true
			break
	
	# here we process for if we're already grounded, we can then unground if no good neighbours
	if fluid.HasGround():  
		if !neighbours_grounded && fluid_coords.size() > 8:
			# then we can actually try to unground
			#fluid.world_height = fluid.GetHeight()
			#fluid.water_height = NAN
			fluid.SetGrounded(false)
			fluid.UpdateDemoPos()
		return
	
	if !neighbours_grounded:
		return
	
	var global_y_pos = fluid.GetHeight()
	var cx = Coord(x)
	var cy = Coord(y)
	# attempt to find ground point here
	var pos:Vector3 = Vector3(cx, global_y_pos, cy)
	var min_pos:Vector3 = Vector3(cx, global_y_pos - max_water_height_cast, cy)
	var result = DrawLine.RaycastVisble(pos, min_pos, get_world_3d())
	
	if result.is_empty():
		return
	
	fluid.world_height = result.position.y + fluid_height_padding
	fluid.water_height = 0.0
	fluid.SetGrounded(true)

func TryConnections(fluid:fluid_obj, x:int, y:int):
	if !fluid.NeedsUpdate(): 
		return # no updated needed, this coord is settled
	
	var cx = Coord(x)
	var cy = Coord(y)
	for index in range(0, 4):
		var offset_cx = Coord(x + neighbour_offsets[index].x)
		var offset_cy = Coord(y + neighbour_offsets[index].y)
		
		var neighbour = FluidAt(x + neighbour_offsets[index].x, y + neighbour_offsets[index].y)
		var target_height:float = 0.0
		if neighbour != null && neighbour.HasGround():
			target_height = neighbour.GetHeight()
		else: 
			#continue
			target_height = fluid.GetHeight()
		
		var ray_start:Vector3 = Vector3(cx, fluid.GetHeight(), cy)
		var ray_end:Vector3 = Vector3(offset_cx, target_height, offset_cy)
		# to resolve the ambiguouety between each fluid's raycasts, we'll just start from the highest point and go to the lowest
#		var inversed = false
#		if ray_start.y < ray_end.y:
#			inversed = true
#		elif ray_start.y == ray_end.y:
#			if ray_start.x < ray_end.x:
#				inversed = true
#			elif ray_start.x == ray_end.x:
#				assert(ray_start.z != ray_end.z) # not all 3 points are going to be the same value
#				if ray_start.z < ray_end.z:
#					inversed = true
				
		#if inversed:
		var result1 = DrawLine.RaycastVisble(ray_end, ray_start, get_world_3d())
		#else:
		var result2 = DrawLine.RaycastVisble(ray_start, ray_end, get_world_3d())
		
		fluid.SetConnection(index, result1.is_empty() && result2.is_empty())

func TryDisperse(fluid:fluid_obj, x:int, y:int, delta):
	if !fluid.NeedsUpdate(): 
		return # no updated needed, this coord is settled
	if !fluid.HasGround(): # || !fluid.HasConnection()
		var sum_height:float = 0.0
		var valid_neighbours:int = 0
		for index in range(0, 4):
			var neighbour = FluidAt(x + neighbour_offsets[index].x, y + neighbour_offsets[index].y)
			if neighbour != null && neighbour.HasGround():
				sum_height += neighbour.GetHeight()
				valid_neighbours += 1
		
		if valid_neighbours > 0:
			fluid.world_height = sum_height / valid_neighbours
			fluid.UpdateDemoPos()
		fluid.ClearUpdate() # NOTE: this can create inconsistencies, as we are potentially clearing update status before we apply all the changes to the neighbours, meaning the average will not be correct till next update
		return # these guys can spread as they do not technically contain any water
	if fluid.water_height < min_water_height_to_spread: 
		return # not enough mass to spread anywhere (this prevents excessively activating nearby tiles)
	
	
	# we now calculate how much volume we're actually allowed to distrubute
	var f_obj_array:Array = []
	var debug_height_array:Array = []
	# array for fluid direction?
	FluidHeightSort(debug_height_array, f_obj_array, NeighbourAtOrCreate(fluid, x,y, 0), fluid)
	FluidHeightSort(debug_height_array, f_obj_array, NeighbourAtOrCreate(fluid, x,y, 1), fluid)
	FluidHeightSort(debug_height_array, f_obj_array, NeighbourAtOrCreate(fluid, x,y, 2), fluid)
	FluidHeightSort(debug_height_array, f_obj_array, NeighbourAtOrCreate(fluid, x,y, 3), fluid)
	
	var highest_height:float = f_obj_array[3].height # always the biggest height value
	
	#var f_max_dispersible_array:Array = []
	for index in range(0, 4): # should be just 4 always
		var current_connection:disperse_data = f_obj_array[index]
		assert(current_connection.height >= 0.0)
		if current_connection.height == 0.0: 
			continue
		
		var sharing_count = 5 - index # including self + center point
		
		var measured_height = current_connection.height
		var redistributed_height = current_connection.height / sharing_count
		for redistribute_index in range(0, 4-index):
			var thing_connection:disperse_data = f_obj_array[redistribute_index + index]
			thing_connection.height -= measured_height
			thing_connection.max_dispersible += redistributed_height
			assert(thing_connection.height >= 0.0)
	
	# here we can normzlize or whatever
	var total_dispersed = 0.0
	for index in range(0, 4):
		var current_connection:disperse_data = f_obj_array[index]
		current_connection.amount_to_disperse = minf(current_connection.max_dispersible, dispersal_per_second*delta*current_connection.og_height)
		total_dispersed += current_connection.amount_to_disperse
	
	# if nothing to disperse, then we are done here
	if total_dispersed <= 0.0:
		fluid.ClearUpdate() # i believe this is the only place that its possible for a regular cluster thing to decide no more updates are required
		return
	
	# then we distribute water?
	for index in range(0, 4):
		var current_connection:disperse_data = f_obj_array[index]
		current_connection.debug()
		
		if current_connection.obj != null:
			if current_connection.amount_to_disperse > 0.0:
				fluid.DisperseTo(current_connection.obj, current_connection.amount_to_disperse)
			elif !current_connection.obj.HasGround():
				current_connection.obj.RequestUpdate()
	
	# for the time being we just distribute fluid at a constant rate, we need to change this to an exponential rate though i think
	# so we see much how each connection wants
	# get all neighbours?
	# average out how much we can distrubute?
	
	# then we do any height checks required
	# then we can render our mesh? or are we just going to spawn in a buncha spheres for this
	# NOTE: we can also do wave simulations by adding momentumn to our clusters
	
	



func FluidHeightSort(debug_height_array:Array, obj_array:Array, fluid:disperse_data, comparison_fluid:fluid_obj):
	if fluid.is_connection_valid:
		fluid.height = comparison_fluid.GetHeightAbove(fluid.obj)
	else: fluid.height = 0.0 # cant do height differencing between fluids who dont have a valid connection
	fluid.og_height = fluid.height
	
	for index in obj_array.size():
		var curr_height:float = obj_array[index].height
		if curr_height > fluid.height:
			obj_array.insert(index, fluid)
			debug_height_array.insert(index, fluid.height)
			return
	# else append to back
	obj_array.push_back(fluid)
	debug_height_array.push_back(fluid.height)

class disperse_data:
	# constructor stuff
	var obj:fluid_obj
	var neighbour_index:int
	var is_connection_valid:bool
	# extra stuff
	var height:float = NAN
	var og_height:float = NAN
	var max_dispersible:float = 0.0
	var amount_to_disperse:float = NAN
	func debug():
		var test = 0
		assert(height == 0.0)

func NeighbourAtOrCreate(base_fluid:fluid_obj, x:int, y:int, neighbour_index:int) -> disperse_data:
	var target_x = x + neighbour_offsets[neighbour_index].x
	var target_y = y + neighbour_offsets[neighbour_index].y
	
	var data_obj:disperse_data = disperse_data.new()
	data_obj.obj = FluidAt(target_x,target_y)
	data_obj.neighbour_index = neighbour_index
	data_obj.is_connection_valid = base_fluid.Connection(neighbour_index)
	
	# if allowed & the neighbour doesn't exist yet, then lets create it
	if base_fluid.HasGround() && data_obj.obj == null:
		var global_y_pos = base_fluid.GetHeight()
		
		var cx = Coord(target_x)
		var cy = Coord(target_y)
		var new_fluid:fluid_obj = fluid_obj.new()
		# get/set position of fluid?
		new_fluid.mesh = demo_obj.instantiate()
		
		new_fluid.world_height = base_fluid.world_height
		new_fluid.SetGrounded(false)
		
		new_fluid.RequestUpdate()
		new_fluid.SetDemoPos(cx, cy)
		self.add_child(new_fluid.mesh)
		data_obj.obj = new_fluid
		# append to dictionary??
		fluid_coords[GenerateCoordKey(target_x, target_y)] = new_fluid
	return data_obj

func ApplyFluid(x:float, y:float, altitude:float, amount:float):
	# round the x & y values // screw it we're using z as height here. i HATE the y is height thing !!!!!
	var x_int:int = roundf(x)
	var y_int:int = roundf(y)
	var fluid:fluid_obj = FluidAt(x_int, y_int)
	if fluid != null && fluid.HasGround(): # then we just apply the new height & request that they update their stuff
		fluid.UpdateVolume(amount)
	else:
		var fluid_was_null = (fluid == null)
		if fluid_was_null:
			fluid = fluid_obj.new()
			fluid.mesh = demo_obj.instantiate()
		
		var cx:float = Coord(x_int)
		var cy:float = Coord(y_int)
		# attempt to find ground point here
		var pos:Vector3 = Vector3(cx, altitude, cy)
		var min_pos:Vector3 = Vector3(cx, altitude - max_water_height_cast, cy)
		var result = DrawLine.RaycastVisble(pos, min_pos, get_world_3d())
		if result.is_empty():
			assert(1 == 2) # placeholder error for now
			return # if we couldn't find a ground position then the water falls into the void
		
		fluid.world_height = result.position.y + fluid_height_padding
		fluid.water_height = amount
		fluid.SetGrounded(true)
		fluid.RequestUpdate()
		
		if fluid_was_null: # lastly cleanup & add to thing if this guy didn't already exist
			fluid.SetDemoPos(cx, cy)
			self.add_child(fluid.mesh)
			fluid_coords[GenerateCoordKey(x_int, y_int)] = fluid

func Coord(pos:int) -> float:
	return pos * fluid_tile_size

func FluidAt(x:int, y:int) -> fluid_obj:
	var key:int = GenerateCoordKey(x,y)
	if !fluid_coords.has(key): return null
	return fluid_coords[GenerateCoordKey(x,y)]

#func AddFluidAt(x:int, y:int, change:float) -> void:
#	fluid_coords[GenerateCoordKey(x,y)].water_height += change

func GenerateCoordKey(x:int, y:int) -> int:
	return (x << 32) + (y & 0xffffffff)
