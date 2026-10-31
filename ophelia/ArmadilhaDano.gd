extends Area2D
## Dano repetido enquanto o jogador estiver dentro; respeita a invulnerabilidade.
@export_range(0.5, 6.0, 0.5) var dano: float = 1.0
@export var escudo_pode_bloquear: bool = true
@export_range(0.05, 2.0, 0.05) var intervalo_tentativas: float = 0.15
var _tempo: float = 0.0

func _ready() -> void:
	body_entered.connect(_ao_entrar)

func _ao_entrar(corpo: Node2D) -> void:
	_tentar_dano(corpo)

func _physics_process(delta: float) -> void:
	_tempo -= delta
	if _tempo > 0.0:
		return
	_tempo = intervalo_tentativas
	for corpo in get_overlapping_bodies():
		_tentar_dano(corpo)

func _tentar_dano(corpo: Node2D) -> void:
	if not corpo.is_in_group("jogador"):
		return
	var vitalidade: Node = corpo.get_node_or_null("Vitalidade")
	if vitalidade == null:
		return
	var defendendo: bool = false
	var lenco: Node = corpo.get_node_or_null("Lenco")
	if escudo_pode_bloquear and lenco != null and lenco.has_method("defesa_ativa"):
		defendendo = bool(lenco.call("defesa_ativa"))
	vitalidade.call("receber_dano", dano, global_position, defendendo)
