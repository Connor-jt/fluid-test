extends Node2D

class Line:
	var Start
	var End
	var LineColor
	var LineTime
	
	func _init(_Start, _End, _LineColor, _LineTime):
		Start = _Start
		End = _End
		LineColor = _LineColor
		LineTime = _LineTime

var Lines = []
var RemovedLine = false

func _process(delta):
	for i in range(len(Lines)):
		Lines[i].LineTime -= delta
	
	if(len(Lines) > 0 || RemovedLine):
		queue_redraw() #Calls _draw
		RemovedLine = false

func _draw():
	var Cam = get_viewport().get_camera_3d()
	for i in range(len(Lines)):
		var ScreenPointStart = Cam.unproject_position(Lines[i].Start)
		var ScreenPointEnd = Cam.unproject_position(Lines[i].End)
		
		#Dont draw line if either start or end is considered behind the camera
		#this causes the line to not be drawn sometimes but avoids a bug where the
		#line is drawn incorrectly
		if(Cam.is_position_behind(Lines[i].Start) ||
			Cam.is_position_behind(Lines[i].End)):
			continue
		
		draw_line(ScreenPointStart, ScreenPointEnd, Lines[i].LineColor)
	
	#Remove lines that have timed out
	var i = Lines.size() - 1
	while (i >= 0):
		if(Lines[i].LineTime < 0.0):
			Lines.remove_at(i)
			RemovedLine = true
		i -= 1

func DrawLine(Start, End, LineColor, LineTime = 0.0):
	Lines.append(Line.new(Start, End, LineColor, LineTime))

func DrawRay(Start, Ray, LineColor, LineTime = 0.0):
	Lines.append(Line.new(Start, Start + Ray, LineColor, LineTime))

func DrawCube(Center, HalfExtents, LineColor, LineTime = 0.0):
	#Start at the 'top left'
	var LinePointStart = Center
	LinePointStart.x -= HalfExtents
	LinePointStart.y += HalfExtents
	LinePointStart.z -= HalfExtents
	
	#Draw top square
	var LinePointEnd = LinePointStart + Vector3(0, 0, HalfExtents * 2.0)
	DrawLine(LinePointStart, LinePointEnd, LineColor, LineTime);
	LinePointStart = LinePointEnd
	LinePointEnd = LinePointStart + Vector3(HalfExtents * 2.0, 0, 0)
	DrawLine(LinePointStart, LinePointEnd, LineColor, LineTime);
	LinePointStart = LinePointEnd
	LinePointEnd = LinePointStart + Vector3(0, 0, -HalfExtents * 2.0)
	DrawLine(LinePointStart, LinePointEnd, LineColor, LineTime);
	LinePointStart = LinePointEnd
	LinePointEnd = LinePointStart + Vector3(-HalfExtents * 2.0, 0, 0)
	DrawLine(LinePointStart, LinePointEnd, LineColor, LineTime);
	
	#Draw bottom square
	LinePointStart = LinePointEnd + Vector3(0, -HalfExtents * 2.0, 0)
	LinePointEnd = LinePointStart + Vector3(0, 0, HalfExtents * 2.0)
	DrawLine(LinePointStart, LinePointEnd, LineColor, LineTime);
	LinePointStart = LinePointEnd
	LinePointEnd = LinePointStart + Vector3(HalfExtents * 2.0, 0, 0)
	DrawLine(LinePointStart, LinePointEnd, LineColor, LineTime);
	LinePointStart = LinePointEnd
	LinePointEnd = LinePointStart + Vector3(0, 0, -HalfExtents * 2.0)
	DrawLine(LinePointStart, LinePointEnd, LineColor, LineTime);
	LinePointStart = LinePointEnd
	LinePointEnd = LinePointStart + Vector3(-HalfExtents * 2.0, 0, 0)
	DrawLine(LinePointStart, LinePointEnd, LineColor, LineTime);
	
	#Draw vertical lines
	LinePointStart = LinePointEnd
	DrawRay(LinePointStart, Vector3(0, HalfExtents * 2.0, 0), LineColor, LineTime)
	LinePointStart += Vector3(0, 0, HalfExtents * 2.0)
	DrawRay(LinePointStart, Vector3(0, HalfExtents * 2.0, 0), LineColor, LineTime)
	LinePointStart += Vector3(HalfExtents * 2.0, 0, 0)
	DrawRay(LinePointStart, Vector3(0, HalfExtents * 2.0, 0), LineColor, LineTime)
	LinePointStart += Vector3(0, 0, -HalfExtents * 2.0)
	DrawRay(LinePointStart, Vector3(0, HalfExtents * 2.0, 0), LineColor, LineTime)


func RaycastVisble(begin:Vector3, end:Vector3, world_3d):
	var space_state = world_3d.direct_space_state
	var query = PhysicsRayQueryParameters3D.create(begin, end)
	var result = space_state.intersect_ray(query)
#	if result.is_empty():
#		DrawLine(begin, end, Color(0.0, 0.0, 1.0), 0.005)
#	else: 
#		DrawLine(begin, end, Color(1.0, 0.0, 0.0), 0.005)
	return result
