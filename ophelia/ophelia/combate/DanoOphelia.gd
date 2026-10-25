class_name OpheliaDano
extends RefCounted
## Interface única usada pelo ataque, pelo projétil e pelos exemplos de inimigo.
static func encontrar_receptor(contato: Node, ignorar: Node = null) -> Node:
	var alvo: Node = contato
	while is_instance_valid(alvo):
		if alvo == ignorar or (ignorar != null and ignorar.is_ancestor_of(alvo)):
			return null
		if alvo.has_method("receber_dano") or alvo.has_method("tomar_dano"):
			return alvo
		alvo = alvo.get_parent()
	return null

static func aplicar(alvo: Node, quantidade: int) -> bool:
	if not is_instance_valid(alvo) or quantidade <= 0:
		return false
	var retorno: Variant
	if alvo.has_method("receber_dano"):
		retorno = alvo.call("receber_dano", quantidade)
	elif alvo.has_method("tomar_dano"):
		retorno = alvo.call("tomar_dano", quantidade)
	else:
		return false
	# Métodos antigos sem retorno continuam compatíveis; false representa bloqueio.
	if retorno is bool:
		return retorno
	return true
