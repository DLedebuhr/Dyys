extends CharacterBody2D

const SPEED = 300.0

@export var side = 'p1'

func _physics_process(_delta: float) -> void:

	var direction 
	
	if side == 'p1':
		
		direction = get_axis(KEY_W, KEY_S)
		
	else:
	
		direction = get_axis(KEY_I, KEY_K)
	
	if direction:
		
		velocity.y = direction * SPEED
		
	else:
		
		velocity.y = move_toward(velocity.x, 0, SPEED)

	move_and_slide()

func get_axis(up, down):
	
	if Input.is_key_pressed(up): return -1
	elif Input.is_key_pressed(down): return 1

func _on_area_2d_body_entered(body: Node2D) -> void:
	body.direction.x *= -1
	Main.side = side
