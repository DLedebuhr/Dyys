extends Area2D
@export var velocidade: Vector2 = Vector2(-180, 0)
@export var dano: int = 10
var bloqueado: bool = false

# Preparar o nó
# ---------------------
# Configura referências, sinais e estado inicial.
func _ready() -> void:

	add_to_group("projeteis_hostis")
	collision_layer = CamadasFisica.PROJETEIS_HOSTIS
	collision_mask = CamadasFisica.JOGADOR | CamadasFisica.DEFESA_JOGADOR
	body_entered.connect(_ao_corpo)
	var forma := CollisionShape2D.new()
	var circulo := CircleShape2D.new()
	circulo.radius = 6.0
	forma.shape = circulo
	add_child(forma)

# Atualizar a física
# ---------------------
# Avança o movimento e as verificações físicas deste nó.
func _physics_process(delta: float) -> void:

	position += velocidade * delta

# Ao corpo
# ---------------------
# Trata o evento: corpo.
func _ao_corpo(corpo: Node) -> void:

	if corpo.has_method("receber_dano"):

		corpo.call("receber_dano", dano, global_position)
		queue_free()

# Bloquear pelo escudo
# ---------------------
# Bloqueia pelo escudo.
func bloquear_pelo_escudo() -> void:

	bloqueado = true
	queue_free()
