extends Label

@export var cluster_thing : L_Manager

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	#set_text("FPS " + str(Engine.get_frames_per_second()) + " | Objects " + str(cluster_thing.active_clusters.size()))
