class_name OpheliaDano
extends RefCounted
## Interface única usada pelo ataque, pelo projétil e pelos exemplos de inimigo.

# Encontrar receptor
# ---------------------
# Procura receptor.
static func encontrar_receptor(contato: Node, ignorar: Node = null) -> Node:

	var alvo: Node = contato

	while is_instance_valid(alvo):

		if alvo == ignorar or (ignorar != null and ignorar.is_ancestor_of(alvo)):

			return null

		if alvo.has_method("receber_dano") or alvo.has_method("tomar_dano"):

			return alvo

		alvo = alvo.get_parent()

	return null

# Aplicar
# ---------------------
# Aplica a rotina deste componente.
static func aplicar(alvo: Node, quantidade: int, inicio: Vector2 = Vector2.INF, fim: Vector2 = Vector2.INF) -> bool:

	if not is_instance_valid(alvo) or quantidade <= 0:

		return false

	var retorno: Variant

	if alvo.has_method("receber_golpe") and inicio.is_finite() and fim.is_finite():

		retorno = alvo.call("receber_golpe", quantidade, inicio, fim)

	elif alvo.has_method("receber_dano"):

		retorno = alvo.call("receber_dano", quantidade)

	elif alvo.has_method("tomar_dano"):

		retorno = alvo.call("tomar_dano", quantidade)

	else:

		return false
	# Métodos antigos sem retorno continuam compatíveis; false representa bloqueio.

	if retorno is bool:

		return retorno

	return true
