extends Node2D

func _process(delta: float) -> void:
	$Label.text = str(Main.p1_score)
	$Label2.text = str(Main.p2_score)

func _on_top_body_entered(body: Node2D) -> void:
	body.direction.y *= -1

func _on_bottom_body_entered(body: Node2D) -> void:
	body.direction.y *= -1

func _on_left_body_entered(body: Node2D) -> void:
	body.queue_free()
	var e = preload("res://ball.tscn").instantiate()
	e.global_position = Vector2(576, 320)
	add_child(e)
	Main.p2_score += 1
	
func _on_right_body_entered(body: Node2D) -> void:
	body.queue_free()
	var e = preload("res://ball.tscn").instantiate()
	e.global_position = Vector2(576, 320)
	add_child(e)
	Main.p1_score += 1
