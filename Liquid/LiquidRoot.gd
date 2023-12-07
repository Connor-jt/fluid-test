class_name L_Manager
extends Node3D

# Called when the node enters the scene tree for the first time.
var scene : PackedScene = load("res://Liquid/LiquidCluster.tscn")
var active_clusters = []
func _ready():
	GenerateCluster(Vector3(0, 10, 0), Vector3(0,0,0), 40)
	return


const new_cluster_tick_interval = 180
var generate_new_Cluster_Ticks = new_cluster_tick_interval
# testing stuff to limit rate of dispersal

#const disperse_ticks = 40
#var disperse_current = disperse_ticks
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	
	generate_new_Cluster_Ticks -= 1
	if generate_new_Cluster_Ticks <= 0:
		GenerateCluster(Vector3(0, 10, 0), Vector3(0,0,0), 5)
		generate_new_Cluster_Ticks = new_cluster_tick_interval
	#return
	# TESTING #
	# limit dispersal to every 30th frame
#	disperse_current -= 1
#	if disperse_current > 0: 
#		return
#	disperse_current = disperse_ticks
	
	#TryPressurize(delta)
	var current_clusters = [] + active_clusters
	for cluster in current_clusters:
		cluster.c_phys_ticks -= 1
		if cluster.c_phys_ticks <= 0:
			Cluster_TryDisperse(cluster)
			cluster.ResetTicks()
	
	

func GenerateCluster(pos : Vector3, velocity : Vector3, mass : float):
	var new_cluster : L_Cluster = scene.instantiate()
	new_cluster.position = pos
	new_cluster.linear_velocity = velocity
	Cluster_UpdateMass(new_cluster, mass)
	self.add_child(new_cluster)
	active_clusters.push_back(new_cluster)
	#new_cluster.max_contacts_reported = 1
	return


## pressurization stuff
#const pressure_force = 2.5
#const pressure_falloff = 3.5
#
#func TryPressurize(cluster, delta_time : float):
#	var accumulated_pressure : Vector3 = Vector3(0,0,0)
#	var total_force : float = 0.0
#	for fluid in cluster.get_node($Node3D/FluidColliders.get_overlapping_bodies()):
#		if fluid == cluster:
#			continue # for some reason these overlap despite being related
#
#		var overlap_direction : Vector3 = cluster.position - fluid.position
#
#		var distance : float = overlap_direction.length()
#		var overlap_length : float = (radius + fluid.radius) - distance
#		if overlap_length <= 0.0:
#			continue # skip if the things somehow aren't actually touching
#
#		var coverage_factor : float = clampf(overlap_length/radius, 0.0, 1.0)  
#		var coverage_expon : float = 1 - pow(1-coverage_factor, pressure_falloff)
#		overlap_direction = overlap_direction.normalized()
#		overlap_direction *= coverage_expon * pressure_force * delta_time
#
#		accumulated_pressure += overlap_direction
#		total_force += overlap_direction.length()
#
#	if total_force > 0.0:
#		var totalled_length = accumulated_pressure.length()
#		accumulated_pressure.y += total_force - totalled_length
#		cluster.apply_impulse(accumulated_pressure)
#	return

# dispersion ring stuff
const ring_segments : int = 4
const ring_degrees : float = deg_to_rad(360.0 / ring_segments)

const ring_height = 0.1
const ring_spacer = 0.1

const smallest_mass = 0.005
const dispersion_multiplier = 0.15

const smallest_mass_mergeability_multiplier = 1.5

func Cluster_GetAllNeighbours(cluster : L_Cluster):
	var colliders = cluster.get_node("Node3D/Neighbours").get_overlapping_bodies()
	# filter colliders by type
	var neighbours = []
	for collider in colliders:
		if collider is L_Cluster: neighbours.push_back(collider)
	return neighbours

func Cluster_TryDisperse(cluster : L_Cluster): 
	# do not disperse if moving (ideally if just not grounded)
	#if (Cluster_IsGrounded(cluster)):
	#	return
	# if any collision instead?
	#var v = cluster.linear_velocity
	var neighbours = Cluster_GetAllNeighbours(cluster)
	#var current_strength = cluster.linear_velocity.length()
	# this should be some ratio between surface area & mass, (/2 as only half the surface should be able to disperse)
	# but multipled/added by loss in velocity, as collisions accelerate rate of dispersion
	var surface_area = CalcSurface(cluster.c_radius)
	var dispersible_mass = maxf(clampf((surface_area/cluster.c_mass)*dispersion_multiplier, 0.0, 1.0) * cluster.c_mass, smallest_mass)
	# check to see if any neighbours are 
	if true: # cluster.c_mass <= smallest_mass * smallest_mass_mergeability_multiplier:
		# then this is eligeable to merge into another cluster
		
		var best_merge_cluster = null
		var lowest_hieght : float = NAN
		
		var our_height = cluster.c_radius + cluster.global_position.y
		for merge_candidate in neighbours:
			var cand_height = merge_candidate.c_radius + merge_candidate.global_position.y
			var cand_offset = cand_height - our_height
			if cand_offset < 0.0 && (is_nan(lowest_hieght) || cand_offset < lowest_hieght):
				best_merge_cluster = merge_candidate
				lowest_hieght = cand_height
		if best_merge_cluster != null && cluster.c_mass < best_merge_cluster.c_mass * 0.4:
			Cluster_UpdateMass(best_merge_cluster, cluster.c_mass)
			Cluster_UpdateMass(cluster, -cluster.c_mass)
			return
	if cluster.c_mass <= smallest_mass * smallest_mass_mergeability_multiplier:
		return
	
	# used so we can guess at how much space is required for the object to be validly created
	var max_dispersal_mass_radius = CalcRadius(dispersible_mass / ring_segments)
	# water will remain grouped while in motion
	# alternatively, water should rapidly disperse * change in velocity
	var connections = []
	
	
	# if this object cant split, then theres no point running any casts, fill all connections as walls
	if dispersible_mass / ring_segments < smallest_mass || neighbours.size() > ring_segments:
		for index in range(0, ring_segments):
			connections.push_back(null)
	else:
		for index in range(0, ring_segments):
			var degrees_offset = index * ring_degrees
			# get the relative direction of this 
			var direction = Vector3.RIGHT.rotated(Vector3.UP, degrees_offset)
			
			var raycast_height_offset = -cluster.c_radius + cluster.GetRingHeight(index)
			assert(absf(raycast_height_offset) <= cluster.c_radius)
			var sphere_width_at_raycast_height = CalcIntersectWidth(cluster.c_radius, raycast_height_offset)
			
			# get start & end positions
			var ray_origin : Vector3 = cluster.global_position
			ray_origin.y += raycast_height_offset
			var disperse_point = ray_origin + (direction * (sphere_width_at_raycast_height + ring_spacer + max_dispersal_mass_radius))
			var ray_end = disperse_point + (direction * max_dispersal_mass_radius) # use double the radius for the full cast length
			# perform raycast
			var space_state = get_world_3d().direct_space_state
			var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
			DrawLine.DrawLine(ray_origin, ray_end, Color(1.0, 0, 0), 0.1)
			var result = space_state.intersect_ray(query)
			
			
			var collided : bool = false
			# if no collision, then simply output the fluid?
			if result.is_empty():
				# perform volume raycast to see if theres enough vertical room
				var vert_begin = disperse_point + Vector3(0, max_dispersal_mass_radius, 0)
				var vert_end   = disperse_point - Vector3(0, max_dispersal_mass_radius, 0)
				var vert_query = PhysicsRayQueryParameters3D.create(vert_begin, vert_end)
				DrawLine.DrawLine(vert_begin, vert_end, Color(1.0, 0, 0), 0.75)
				var vert_result = space_state.intersect_ray(vert_query)
				
				if vert_result.is_empty():
					cluster.DecRingHeight(index)
					connections.push_back(disperse_point)
				else: collided = true
			else: 
				collided = true
			#elif result.collider is L_Cluster:
			#	connections.push_back(result.collider) # NOTE: this functionality is currently unused!!!
			if collided:
				cluster.IncRingHeight(index)
				connections.push_back(null)
	
	# NOTE: this system does no conform to the original concept of dispersing mass equally across all directions
	# this is because we dont take into account the direction of connections before we give them our mass
	
	# count number of valid dispersal raycast position things
	var valid_clusterspawn_count : int = 0
	for index in range(0, ring_segments):
		var connection = connections[index]
		if connection is Vector3:
			valid_clusterspawn_count += 1
	
	var max_mass_dispersal_per_connection = dispersible_mass / (valid_clusterspawn_count + neighbours.size())
	for index in range(0, ring_segments):
		var connection = connections[index]
		if connection is Vector3: # connection == null:
			# if this is too small, then we cant split 
			if max_mass_dispersal_per_connection < smallest_mass:
				continue
			# then we can create a new thingo here
			Cluster_UpdateMass(cluster, -max_mass_dispersal_per_connection)
			GenerateCluster(connection, Vector3(0,0,0), max_mass_dispersal_per_connection)
		elif connection != null:
			pass
	
	# handle dispersing mass off to neighbouring clusters
	for neighbour in neighbours:
		# determine maximum mass we can give away to this connection
		
		# max is based purely off of the highest points of both clusters
		# as we want to level out any connections
		var conn_height = neighbour.c_radius + neighbour.global_position.y
		var conn_radius = neighbour.c_radius
		var conn_mass   = neighbour.c_mass
		
		var our_height = cluster.c_radius + cluster.global_position.y
		var our_radius = cluster.c_radius
		var our_mass   = cluster.c_mass
		
		var difference = our_height - conn_height
		# skip if the current cluster is smaller than connected cluster
		if difference <= 0.0: continue
		
		# then calculate how much mass it would take to reach that height
		var conn_target_mass = CalcVolume(conn_radius + difference)
		var max_conn_dispersable_mass = minf(conn_target_mass - conn_mass, max_mass_dispersal_per_connection)
		
		Cluster_UpdateMass(cluster, -max_conn_dispersable_mass)
		Cluster_UpdateMass(neighbour, max_conn_dispersable_mass)
	
	return

func Cluster_TryMerge(cluster : L_Cluster):
	
	pass

func Cluster_IsGrounded(cluster : L_Cluster) -> bool:
	var space_state = get_world_3d().direct_space_state
	var origin : Vector3 = cluster.global_position
	var end = origin
	end.y -= cluster.c_radius + 0.1
	# perform raycast
	var query = PhysicsRayQueryParameters3D.create(origin, end)
	DrawLine.DrawLine(origin, end, Color(1.0, 0, 0), 0.75)
	query.collide_with_bodies = true
	return space_state.intersect_ray(query).is_empty()

func Cluster_GainMass(cluster : L_Cluster, ChangeInMass : float, OriginVelocity : Vector3):
	assert(ChangeInMass > 0.0)
	# inherit velocity based off ratio of mass added
	var velocity_inherit_percentage : float = 1.0
	if cluster.c_mass > smallest_mass:
		velocity_inherit_percentage = clampf(ChangeInMass / cluster.c_mass, 0.0, 1.0)
	
	cluster.linear_velocity = lerp(cluster.linear_velocity, OriginVelocity, velocity_inherit_percentage)
	#cluster.apply_impulse(OriginVelocity * velocity_inherit_percentage)
	return Cluster_UpdateMass(cluster, ChangeInMass)

func Cluster_UpdateMass(cluster : L_Cluster, ChangeInMass : float):
	
	var new_mass : float = cluster.c_mass + ChangeInMass
	# if new mass is less than 0, then theres no mass left in this cluster
	if new_mass <= 0.0:
		Cluster_Dissipate(cluster)
		return true
	var new_radius : float = CalcRadius(new_mass)
	
	# find difference in distance to ground
	var height_difference = new_radius - (cluster.c_radius)
	
	# test whether new size can fit
	# if not, then return false? # for the time being, ignore this and always adjust size
	
	# apply new sizes & return true
	cluster.c_radius = new_radius
	cluster.c_mass = new_mass
	cluster.translate(Vector3(0,0,height_difference))
	cluster.UpdatePhysicalSize()
	return true

func Cluster_Dissipate(cluster : L_Cluster):
	# just delete ourselves or something
	active_clusters.erase(cluster)
	cluster.queue_free() # what the hell godot
	return


# helper functions to calcuate sphere sizes
const conversion_factor : float = (4.0/3.0) * PI
const surface_factor : float = 4.0 * PI
func CalcVolume(radius : float):
	return pow(radius, 3) * conversion_factor
func CalcRadius(volume : float):
	return pow(volume/conversion_factor, 1.0/3.0) 
func CalcSurface(radius : float):
	return surface_factor * pow(radius, 2.0)
# calculates the x coord of circle perimeter given the y
func CalcIntersectWidth(radius : float, height : float):
	return pow(pow(radius, 2.0) - pow(height, 2.0), 0.5)
	
	
	
	
