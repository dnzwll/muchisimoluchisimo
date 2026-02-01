extends Node2D

# ====== SPAWNER SETTINGS ======
@export var enemy_scene: PackedScene
@export var spawn_interval := 1.0  # Seconds between spawns
@export var max_enemies := 10  # Maximum enemies alive at once
@export var spawn_radius := 50.0  # Random spawn area radius
@export var spawn_on_start := true  # Spawn one enemy immediately
@export var enabled := true  # Can turn spawner on/off

# ====== WAVE SETTINGS ======
@export_group("Wave System")
@export var use_waves := true
@export var enemies_per_wave := 3
@export var wave_delay := 5.0  # Delay between waves

var spawn_timer := 1.0
var current_wave := 1
var enemies_spawned_this_wave := 2
var wave_active := true

func _ready():
	if spawn_on_start and enabled:
		spawn_enemy()

func _process(delta):
	if not enabled or not enemy_scene:
		return
	
	spawn_timer += delta
	
	if spawn_timer >= spawn_interval:
		spawn_timer = 0.0
		attempt_spawn()

func attempt_spawn():
	# Count current enemies
	var current_enemies = get_tree().get_nodes_in_group("enemies").size()
	
	if current_enemies >= max_enemies:
		return
	
	# Wave system logic
	if use_waves:
		if not wave_active:
			return
		
		if enemies_spawned_this_wave >= enemies_per_wave:
			# Check if all enemies are dead before starting next wave
			if current_enemies == 0:
				start_next_wave()
			return
	
	spawn_enemy()

func spawn_enemy():
	if not enemy_scene:
		push_error("EnemySpawner: No enemy scene assigned!")
		return
	
	# Calculate random spawn position
	var spawn_pos = global_position
	if spawn_radius > 0:
		var angle = randf() * TAU
		var distance = randf() * spawn_radius
		spawn_pos += Vector2(cos(angle), sin(angle)) * distance
	
	# Instantiate enemy
	var enemy = enemy_scene.instantiate()
	enemy.global_position = spawn_pos
	
	# Add to scene tree
	get_parent().add_child(enemy)
	
	if use_waves:
		enemies_spawned_this_wave += 1
	
	print("Spawned enemy at: ", spawn_pos)

func start_next_wave():
	wave_active = false
	enemies_spawned_this_wave = 0
	current_wave += 1
	
	print("Wave ", current_wave - 1, " complete! Next wave in ", wave_delay, " seconds...")
	
	await get_tree().create_timer(wave_delay).timeout
	
	wave_active = true
	print("Wave ", current_wave, " started!")

# ====== UTILITY FUNCTIONS ======
func stop_spawning():
	enabled = false

func start_spawning():
	enabled = true

func clear_all_enemies():
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		enemy.queue_free()
