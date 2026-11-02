class_name ColisaoLenco
extends RefCounted

# Consultar o percurso
# ---------------------
# Procura a primeira colisão considerando o volume e o deslocamento.
static func varrer(no: Node2D, origem: Vector2, deslocamento: Vector2, raio: float, mascara: int, excluir: Array[RID] = [], areas: bool = false) -> Dictionary:

	var consulta := PhysicsShapeQueryParameters2D.new()
	var forma := CircleShape2D.new()
	forma.radius = maxf(raio, 0.1)
	consulta.shape = forma
	consulta.transform = Transform2D(0.0, origem)
	consulta.collision_mask = mascara
	consulta.exclude = excluir
	consulta.collide_with_areas = areas
	consulta.margin = 0.01
	var espaco: PhysicsDirectSpaceState2D = no.get_world_2d().direct_space_state
	var contatos: Array[Dictionary] = espaco.intersect_shape(consulta, 1)

	if not contatos.is_empty():

		return {"fracao": 0.0, "posicao": origem, "collider": contatos[0]["collider"]}

	if deslocamento.is_zero_approx():

		return {}

	consulta.motion = deslocamento
	var movimento: PackedFloat32Array = espaco.cast_motion(consulta)

	if movimento.size() < 2 or movimento[0] >= 1.0:

		return {}

	consulta.motion = Vector2.ZERO
	consulta.transform.origin = origem + deslocamento * movimento[1] + deslocamento.normalized() * 0.02
	contatos = espaco.intersect_shape(consulta, 1)
	var alvo: Object = contatos[0]["collider"] if not contatos.is_empty() else null
	var repouso: Dictionary = espaco.get_rest_info(consulta)
	var contato: Vector2 = repouso.get("point", origem + deslocamento * movimento[0] + deslocamento.normalized() * raio)
	return {"fracao": movimento[0], "posicao": origem + deslocamento * movimento[0], "ponto_contato": contato, "collider": alvo}
