extends Node2D

## Light sources and shadow outlines are editable nodes in Room.tscn.
@export_range(0.0, 2.0) var monitor_idle_energy: float = 0.32
@export_range(0.0, 2.0) var monitor_near_energy: float = 0.52
@export var proximity_start: float = 125.0
@export var proximity_full: float = 30.0
@export var transition_speed: float = 4.0

@onready var _monitor_light: PointLight2D = $MonitorLight
@onready var _player: Node2D = get_parent().get_node_or_null("Player")
@onready var _computer: Node2D = get_parent().get_node_or_null("Computer")

func _process(delta: float) -> void:
	if not is_instance_valid(_player) or not is_instance_valid(_computer):
		return
	var distance := _player.global_position.distance_to(_computer.global_position)
	var proximity := 1.0 - smoothstep(proximity_full, maxf(proximity_full + 1.0, proximity_start), distance)
	var target_energy := lerpf(monitor_idle_energy, monitor_near_energy, proximity)
	_monitor_light.energy = lerpf(_monitor_light.energy, target_energy, 1.0 - exp(-transition_speed * delta))
