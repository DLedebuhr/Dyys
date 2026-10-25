extends Area2D
@export var velocidade: Vector2 = Vector2(-180, 0)
@export var dano: int = 10
var bloqueado: bool = false
func _ready() -> void:
	add_to_group("projeteis_hostis")
	collision_layer = 16
	collision_mask = 2
	body_entered.connect(_ao_corpo)
	var forma := CollisionShape2D.new()
	var circulo := CircleShape2D.new()
	circulo.radius = 6.0
	forma.shape = circulo
	add_child(forma)
func _physics_process(delta: float) -> void:
	position += velocidade * delta
func _ao_corpo(corpo: Node) -> void:
	if corpo.has_method("receber_dano"):
		corpo.call("receber_dano", dano, global_position)
		queue_free()
func bloquear_pelo_escudo() -> void:
	bloqueado = true
	queue_free()
