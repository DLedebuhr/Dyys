extends Area2D
## A área detecta projéteis hostis. O corpo também protege receber_dano().
@onready var lenco = get_parent()

# Preparar o nó
# ---------------------
# Configura referências, sinais e estado inicial.
func _ready() -> void:

	body_entered.connect(_ao_contato)
	area_entered.connect(_ao_contato)

# Ao contato
# ---------------------
# Trata o evento: contato.
func _ao_contato(contato: Node) -> void:

	if not lenco.defesa_ativa():

		return

	var alvo: Node = contato

	while alvo != null and alvo != lenco.jogador:

		if alvo.has_method("bloquear_pelo_escudo"):

			alvo.call_deferred("bloquear_pelo_escudo")
			return

		if alvo.is_in_group("projeteis_hostis"):

			alvo.queue_free()
			return

		alvo = alvo.get_parent()

# Atualizar contatos
# ---------------------
# Atualiza contatos.
func atualizar_contatos() -> void:

	if lenco.defesa_ativa():

		for corpo in get_overlapping_bodies():

			_ao_contato(corpo)

		for area in get_overlapping_areas():

			_ao_contato(area)
