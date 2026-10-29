@tool
extends Node2D

var floor_texture: Texture2D = preload("res://assets/sprites/room/environment_floor.png")
var wall_texture: Texture2D = preload("res://assets/sprites/room/environment_wall.png")

func _draw() -> void:
	# Everything below the skirting board is walkable floor. The physics
	# boundaries in Room.tscn use exactly these same four edges.
	draw_rect(Rect2(232,100,496,324),Color("090b11"))
	draw_rect(Rect2(240,108,480,308),Color("20202a"))
	draw_texture_rect(wall_texture,Rect2(248,116,464,60),false)
	# A single flush skirting board closes the seam between wall and floor.
	draw_rect(Rect2(248,176,464,8),Color("39313d"))
	draw_rect(Rect2(248,176,464,2),Color("554957"))
	draw_texture_rect(floor_texture,Rect2(248,184,464,224),false)
	# Window and rug are separate sprites in Room.tscn so they can be replaced.
