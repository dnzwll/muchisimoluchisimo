extends CharacterBody2D

# ====== TUNABLE VALUES ======
@export var move_speed := 220.0
@export var jump_force := -420.0
@export var gravity := 1200.0
@export var throw_force := Vector2(380, -260)
@export var max_health := 15
@export var attack_damage := 1
@export var finisher_damage := 999

# ====== STATE ======
var health := max_health
var is_attacking := false
var is_grabbing := false
var grabbed_enemy: Node2D = null

# MASK / HYPE
var mask_power := 0.0
const MASK_MAX := 100.0

# ====== NODES ======
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_area: Area2D = $AttackArea

func _ready():
	add_to_group("player")
	
	if attack_area:
		attack_area.monitoring = false
		# Connect signal to detect hits
		attack_area.body_entered.connect(_on_attack_area_body_entered)
	else:
		push_error("Player missing AttackArea! Add an Area2D child named 'AttackArea'")

func _physics_process(delta):
	apply_gravity(delta)
	handle_movement()
	handle_states()
	move_and_slide()

func apply_gravity(delta):
	if not is_on_floor():
		velocity.y += gravity * delta

func handle_movement():
	if is_attacking or is_grabbing:
		velocity.x = move_toward(velocity.x, 0, move_speed * 0.2)
		return
	
	var input_dir := Input.get_axis("move_left", "move_right")
	velocity.x = input_dir * move_speed
	
	if input_dir != 0:
		sprite.flip_h = input_dir < 0
		if is_on_floor():
			sprite.play("run")
	else:
		if is_on_floor():
			sprite.play("idle")
	
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_force
		sprite.play("jump")

func handle_states():
	if Input.is_action_just_pressed("attack") and not is_attacking and not is_grabbing:
		attack()
	if Input.is_action_just_pressed("grab") and not is_grabbing and not is_attacking:
		try_grab()
	if Input.is_action_just_pressed("throw") and is_grabbing:
		throw_enemy()
	if Input.is_action_just_pressed("finisher") and not is_attacking and not is_grabbing:
		finisher()

# ====== COMBAT ======
func attack():
	is_attacking = true
	sprite.play("attack")
	
	print("Player attacking!")  # DEBUG
	
	# Enable attack detection
	if attack_area:
		attack_area.monitoring = true
	
	hitstop(0.05)
	
	await sprite.animation_finished
	
	# Disable after attack
	if attack_area:
		attack_area.monitoring = false
	
	is_attacking = false

# NEW: Handle what gets hit during attack
func _on_attack_area_body_entered(body: Node2D):
	if not is_attacking:
		return
	
	print("Attack hit: ", body.name)  # DEBUG
	
	if body.is_in_group("enemies"):
		if body.has_method("take_damage"):
			body.take_damage(attack_damage)
			gain_mask_power(10)
			print("Enemy damaged!")  # DEBUG

func try_grab():
	print("Trying to grab...")  # DEBUG
	
	if not attack_area:
		print("No attack_area!")  # DEBUG
		return
	
	attack_area.monitoring = true
	
	# Wait 1 physics frame for Godot to update overlaps
	await get_tree().physics_frame
	
	var bodies = attack_area.get_overlapping_bodies()
	print("Found ", bodies.size(), " bodies in grab range")  # DEBUG
	
	for body in bodies:
		print("Checking body: ", body.name)  # DEBUG
		if body.is_in_group("enemies"):
			print("Grabbing enemy: ", body.name)  # DEBUG
			grab_enemy(body)
			attack_area.monitoring = false
			return
	
	print("No enemies to grab")  # DEBUG
	attack_area.monitoring = false

func grab_enemy(enemy):
	is_grabbing = true
	grabbed_enemy = enemy
	enemy.enter_grabbed_state(self)
	sprite.play("grab")

func throw_enemy():
	if grabbed_enemy == null:
		return
	
	var dir := -1 if sprite.flip_h else 1
	grabbed_enemy.throw(Vector2(throw_force.x * dir, throw_force.y))
	gain_mask_power(20)
	grabbed_enemy = null
	is_grabbing = false
	sprite.play("throw")
	hitstop(0.08)

func finisher():
	
	sprite.play("finisher")
	
	
# ====== DAMAGE ======
func take_damage(amount: int):
	health -= amount
	print("Player took damage! Health: ", health)  # DEBUG
	
	# Visual feedback
	if sprite:
		sprite.modulate = Color.RED
		await get_tree().create_timer(0.1).timeout
		sprite.modulate = Color.WHITE
	
	if health <= 0:
		die()

func die():
	print("Player died!")
	get_tree().reload_current_scene()

# ====== MASK SYSTEM ======
func gain_mask_power(amount):
	mask_power = clamp(mask_power + amount, 0, MASK_MAX)
	print("Mask Power: ", mask_power, "/", MASK_MAX)  # DEBUG

func use_mask_power():
	if mask_power >= MASK_MAX:
		mask_power = 0
		sprite.play("finisher")
		# MASSIVE THROW / SCREEN CLEAR

# ====== JUICE ======
func hitstop(time := 0.05):
	Engine.time_scale = 0.0
	await get_tree().create_timer(time, true, false, true).timeout
	Engine.time_scale = 1.0
