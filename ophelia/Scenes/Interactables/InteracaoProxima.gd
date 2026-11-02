class_name InteracaoProxima
extends RefCounted

# Selecionar o interativo mais próximo
# ---------------------
# Escolhe um único coletável disponível para cada aperto de interação.
static func escolher(jogador: CharacterBody2D) -> Node2D:

	var escolhido: Node2D = null
	var distancia: float = INF

	if not is_instance_valid(jogador):

		return null

	for candidato in jogador.get_tree().get_nodes_in_group("coletaveis_ophelia"):

		if not candidato is Node2D or not candidato.has_method("pode_interagir"):

			continue

		if not bool(candidato.call("pode_interagir", jogador)):

			continue

		var atual: float = jogador.global_position.distance_squared_to(candidato.global_position)

		if atual < distancia or (is_equal_approx(atual, distancia) and (escolhido == null or candidato.get_instance_id() < escolhido.get_instance_id())):

			distancia = atual
			escolhido = candidato as Node2D

	return escolhido
