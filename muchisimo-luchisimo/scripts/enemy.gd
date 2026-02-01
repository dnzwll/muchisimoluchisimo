extends CharacterBody2D

@export var move_speed := 120.0
@export var gravity := 1200.0
@export var max_health := 3
@export var score_value := 100
@export var damage_to_player := 1
@export var damage_cooldown := 1.0
@export var hit_stun_duration := 0.3  # How long to pause when hit

var health := max_health
var state := "normal"
var grabbed_by: CharacterBody2D = null
var can_damage := true
var is_hit_stunned := false  # NEW: Prevents movement during hit animation

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var damage_area: Area2D = $DamageArea
@onready var hit_area: Area2D = $HitArea

func _ready():
	add_to_group("enemies")
	
	# Setup damage area
	if damage_area:
		damage_area.body_entered.connect(_on_damage_area_body_entered)
		damage_area.monitoring = true
	else:
		push_warning("Enemy missing DamageArea! Add an Area2D child named 'DamageArea'")
	
	# Setup hit area (for thrown enemy collisions)
	if hit_area:
		hit_area.body_entered.connect(_on_hit_area_body_entered)
		hit_area.monitoring = false
	else:
		push_warning("Enemy missing HitArea! Add an Area2D child named 'HitArea'")
	
	# Connect animation_finished signal to handle hit animation
	if sprite:
		sprite.animation_finished.connect(_on_animation_finished)

func _physics_process(delta):
	# Don't move if hit stunned
	if is_hit_stunned:
		velocity.x = 0
		apply_gravity(delta)
		move_and_slide()
		return
	
	match state:
		"normal":
			ai_move()
		"grabbed":
			follow_player()
		"thrown":
			if is_on_floor():
				state = "normal"
				if hit_area:
					hit_area.monitoring = false
	
	apply_gravity(delta)
	move_and_slide()

func apply_gravity(delta):
	if not is_on_floor():
		velocity.y += gravity * delta

# ===== AI =====
func ai_move():
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		velocity.x = 0
		if sprite and sprite.sprite_frames.has_animation("idle"):
			sprite.play("idle")
		return
	
	var dir : float = sign(player.global_position.x - global_position.x)
	var distance : float = abs(player.global_position.x - global_position.x)
	
	# Stop moving if close enough to attack
	if distance < 30:
		velocity.x = 0
		if sprite and sprite.sprite_frames.has_animation("attack"):
			sprite.play("attack")
		elif sprite and sprite.sprite_frames.has_animation("idle"):
			sprite.play("idle")
	else:
		velocity.x = dir * move_speed
		if sprite:
			sprite.flip_h = dir < 0
			if sprite.sprite_frames.has_animation("walk"):
				sprite.play("walk")

# ===== DAMAGE PLAYER =====
func _on_damage_area_body_entered(body: Node2D):
	if body.is_in_group("player") and can_damage and state == "normal":
		if body.has_method("take_damage"):
			body.take_damage(damage_to_player)
			start_damage_cooldown()

func start_damage_cooldown():
	can_damage = false
	await get_tree().create_timer(damage_cooldown).timeout
	can_damage = true

# ===== TAKE DAMAGE =====
func take_damage(amount := 1):
	health -= amount
	
	print("Enemy took damage! Health: ", health)  # DEBUG
	
	# Enter hit stun state
	is_hit_stunned = true
	velocity.x = 0  # Stop moving immediately
	
	# Play hit animation
	if sprite and sprite.sprite_frames.has_animation("hit"):
		sprite.stop()  # Stop current animation
		sprite.play("hit")
	else:
		# If no hit animation, just flash
		flash_sprite()
		# End hit stun after flash
		await get_tree().create_timer(hit_stun_duration).timeout
		is_hit_stunned = false
	
	if health <= 0:
		die()

func _on_animation_finished():
	# When hit animation finishes, exit hit stun
	if sprite and sprite.animation == "hit":
		is_hit_stunned = false
		# Flash effect at end of hit animation
		flash_sprite()

func flash_sprite():
	if sprite:
		sprite.modulate = Color.RED
		await get_tree().create_timer(0.1).timeout
		if sprite:  # Check again in case enemy died
			sprite.modulate = Color.WHITE

func die():
	if has_node("/root/Game"):
		Game.add_score(score_value, false)
	queue_free()

# ===== GRAB / THROW =====
func enter_grabbed_state(player: CharacterBody2D):
	state = "grabbed"
	grabbed_by = player
	velocity = Vector2.ZERO
	is_hit_stunned = false  # Cancel hit stun when grabbed
	
	# Disable damage while grabbed
	if damage_area:
		damage_area.monitoring = false
	
	if sprite and sprite.sprite_frames.has_animation("grabbed"):
		sprite.play("grabbed")

func follow_player():
	if grabbed_by == null:
		state = "normal"
		if damage_area:
			damage_area.monitoring = true
		return
	
	# Safely get sprite reference
	var player_sprite = grabbed_by.get_node_or_null("AnimatedSprite2D")
	if player_sprite:
		var offset_x := -16 if player_sprite.flip_h else 16
		var target_pos := grabbed_by.global_position + Vector2(offset_x, 0)
		global_position = global_position.lerp(target_pos, 0.25)
	else:
		# Fallback if sprite not found
		global_position = global_position.lerp(grabbed_by.global_position, 0.25)

func throw(force: Vector2):
	state = "thrown"
	grabbed_by = null
	velocity = force
	is_hit_stunned = false  # Cancel hit stun when thrown
	
	# Enable hit detection for thrown enemy
	if hit_area:
		hit_area.monitoring = true
	
	# Disable player damage while thrown
	if damage_area:
		damage_area.monitoring = false
	
	if sprite and sprite.sprite_frames.has_animation("thrown"):
		sprite.play("thrown")

# ===== HIT OTHER ENEMIES WHEN THROWN =====
func _on_hit_area_body_entered(body: Node2D):
	if state == "thrown" and body != self and body.is_in_group("enemies"):
		if body.has_method("take_damage"):
			body.take_damage(2)
		
		if has_node("/root/Game"):
			Game.add_score(score_value, true)
		
		queue_free()
