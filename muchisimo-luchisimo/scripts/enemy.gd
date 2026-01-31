extends CharacterBody2D

@export var move_speed := 120.0
@export var gravity := 1200.0
@export var max_health := 3
@export var score_value := 100

var health := max_health
var state := "normal"
var grabbed_by: CharacterBody2D = null

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready():
	add_to_group("enemies")

func _physics_process(delta):
	match state:
		"normal":
			ai_move()
		"grabbed":
			follow_player()
		"thrown":
			if is_on_floor():
				state = "normal"

	apply_gravity(delta)
	move_and_slide()

func apply_gravity(delta):
	if not is_on_floor():
		velocity.y += gravity * delta

# ===== AI =====
func ai_move():
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return

	var dir : float = sign(player.global_position.x - global_position.x)
	velocity.x = dir * move_speed
	sprite.flip_h = dir < 0
	sprite.play("walk")

# ===== DAMAGE =====
func take_damage(amount := 1):
	health -= amount
	sprite.play("hit")
	if health <= 0:
		die()

func die():
	Game.add_score(score_value, false)
	queue_free()

# ===== GRAB / THROW =====
func enter_grabbed_state(player: CharacterBody2D):
	state = "grabbed"
	grabbed_by = player
	velocity = Vector2.ZERO
	sprite.play("grabbed")

func follow_player():
	if grabbed_by:
		var offset_x := -16 if grabbed_by.sprite.flip_h else 16
		var target_pos := grabbed_by.global_position + Vector2(offset_x, 0)
		global_position = global_position.lerp(target_pos, 0.25)

func throw(force: Vector2):
	state = "thrown"
	grabbed_by = null
	velocity = force
	sprite.play("thrown")

# ===== HIT OTHER ENEMIES =====
func _on_hit_area_body_entered(body):
	if state == "thrown" and body != self and body.is_in_group("enemies"):
		body.take_damage(2)
		Game.add_score(score_value, true)
		queue_free()
