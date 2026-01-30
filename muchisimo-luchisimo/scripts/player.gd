extends CharacterBody2D

# ====== TUNABLE VALUES ======
@export var move_speed := 220.0
@export var jump_force := -420.0
@export var gravity := 1200.0

@export var throw_force := Vector2(380, -260)
@export var max_health := 5

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
@onready var anim_player: AnimationPlayer = $AnimationPlayer

func _ready():
	attack_area.monitoring = false

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

	if Input.is_action_just_pressed("grab") and not is_grabbing:
		try_grab()

	if Input.is_action_just_pressed("throw") and is_grabbing:
		throw_enemy()

# ====== COMBAT ======

func attack():
	is_attacking = true
	sprite.play("attack")
	attack_area.monitoring = true
	hitstop(0.05)

	await sprite.animation_finished
	attack_area.monitoring = false
	is_attacking = false

func try_grab():
	var bodies = attack_area.get_overlapping_bodies()
	for body in bodies:
		if body.is_in_group("enemies"):
			grab_enemy(body)
			return

func grab_enemy(enemy):
	is_grabbing = true
	grabbed_enemy = enemy
	enemy.enter_grabbed_state(self)
	sprite.play("grab")

func throw_enemy():
	if grabbed_enemy == null:
		return

	var dir := sprite.flip_h ? -1 : 1
	grabbed_enemy.throw(Vector2(throw_force.x * dir, throw_force.y))
	gain_mask_power(20)

	grabbed_enemy = null
	is_grabbing = false
	sprite.play("throw")
	hitstop(0.08)

# ====== MASK SYSTEM ======

func gain_mask_power(amount):
	mask_power = clamp(mask_power + amount, 0, MASK_MAX)

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
