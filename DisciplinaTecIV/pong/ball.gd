extends CharacterBody2D

const SPEED = 300.0
var direction = Vector2.ZERO

func _ready() -> void:
	
	direction.y = [1, -1].pick_random()
	direction.x = [1, -1].pick_random()

func _physics_process(delta: float) -> void:

	if direction:
		velocity = direction * SPEED
	else:
		velocity = velocity.move_toward(Vector2.ZERO, SPEED)

	move_and_slide()
