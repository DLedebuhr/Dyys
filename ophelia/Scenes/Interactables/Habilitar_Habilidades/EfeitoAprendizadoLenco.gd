class_name OpheliaAprendizadoLenco
extends RefCounted
## Reutiliza o efeito do ataque seguindo as fitas de repouso, sem acionar combate.
var _lenco: Node2D
var _efeitos: Node2D
var _origem: Node2D
var _jogador: CharacterBody2D
var _modo_efeitos: Node.ProcessMode
var _distancia_original: bool = false
var _ativo: bool = false
var _apice: bool = false

# Preparar
# ---------------------
# Prepara a rotina deste componente.
func preparar(jogador: CharacterBody2D) -> bool:

	var candidato: Node = jogador.get_node_or_null("Lenco")

	if candidato == null:

		return false

	for metodo in ["_calcular_offset_gola", "_calcular_offsets_fitas", "_atualizar_frontal", "_acompanhar_origem", "_atualizar_repouso_firme", "_redesenhar_line2d"]:

		if not candidato.has_method(metodo):

			return false
	# Não interrompe um golpe, uma defesa ou uma corda já presa.

	if int(candidato.get("estado_atual")) != 0:

		return false

	_lenco = candidato as Node2D
	_efeitos = _lenco.get_node_or_null("Efeitos") as Node2D
	_origem = _lenco.get_node_or_null("OrigemLenco") as Node2D

	if _efeitos == null or _origem == null:

		return false

	for metodo in ["atualizar", "parar", "_faiscas_da_explosao", "_adicionar_onda"]:

		if not _efeitos.has_method(metodo):

			return false

	_jogador = jogador
	return true

# Iniciar
# ---------------------
# Inicia a rotina deste componente.
func iniciar() -> void:

	_modo_efeitos = _efeitos.process_mode
	_distancia_original = bool(_efeitos.get("ataque_a_distancia"))
	_efeitos.process_mode = Node.PROCESS_MODE_ALWAYS
	_efeitos.set("ataque_a_distancia", false)
	_efeitos.call("parar")
	_apice = false
	_ativo = true

# Validar o efeito
# ---------------------
# Informa se o efeito ainda tem referências válidas.
func valido() -> bool:

	return _ativo and is_instance_valid(_lenco) and is_instance_valid(_efeitos) and is_instance_valid(_origem)

# Posição gola
# ---------------------
# Processa posição gola.
func posicao_gola() -> Vector2:

	return _origem.global_position + Vector2(_lenco.get("offset_gola_atual"))

# Atualizar
# ---------------------
# Atualiza a rotina deste componente.
func atualizar(delta: float, progresso_luz: float) -> void:

	if not valido():

		return
	# Somente a apresentação do repouso. Não executa física, colisões nem comandos.

	var origem: Vector2 = _origem.global_position + Vector2(_lenco.call("_calcular_offset_gola", delta))
	_lenco.call("_calcular_offsets_fitas", delta)
	_lenco.call("_atualizar_frontal", delta)
	_lenco.call("_acompanhar_origem", origem)
	_lenco.call("_atualizar_repouso_firme", origem, delta)
	_lenco.call("_redesenhar_line2d")
	_lenco.queue_redraw()
	var tras: Array = _lenco.get("pontos_tras")
	var frente: Array = _lenco.get("pontos_frente")

	if tras.size() < 2 or frente.size() < 2:

		return

	var ponta_a: Vector2 = tras[-1]
	var ponta_b: Vector2 = frente[-1]
	var centro: Vector2 = _jogador.global_position

	if progresso_luz >= 0.0 and progresso_luz < 1.0:

		# As cabeças de luz percorrem o comprimento real das fitas, da gola às pontas.
		var a: Vector2 = _amostrar(tras, progresso_luz)
		var b: Vector2 = _amostrar(frente, progresso_luz)
		var direcao: Vector2 = (a.lerp(b, 0.5) - origem).normalized()
		_efeitos.call("atualizar", delta, 1, direcao, minf(progresso_luz, 0.999), origem, a, b, centro)

	else:

		if progresso_luz >= 1.0 and not _apice:

			_apice = true
			# Eco em CADA ponta, sem explosão na gola nem no chão.

			for ponta in [ponta_a, ponta_b]:

				_efeitos.call("_faiscas_da_explosao", ponta, int(_efeitos.get("quantidade_explosao")), 180.0, float(_efeitos.get("velocidade_explosao")))
				_efeitos.call("_adicionar_onda", ponta, float(_efeitos.get("raio_onda_ataque")))

		_efeitos.call("atualizar", delta, 0, Vector2.RIGHT, 1.0, origem, ponta_a, ponta_b, centro)

# Amostrar
# ---------------------
# Amostra a rotina deste componente.
func _amostrar(pontos: Array, progresso: float) -> Vector2:

	var comprimento: float = 0.0

	for i in range(1, pontos.size()):

		comprimento += Vector2(pontos[i - 1]).distance_to(pontos[i])

	var restante: float = comprimento * clampf(progresso, 0.0, 1.0)

	for i in range(1, pontos.size()):

		var a: Vector2 = pontos[i - 1]
		var b: Vector2 = pontos[i]
		var trecho: float = a.distance_to(b)

		if restante <= trecho and trecho > 0.0001:

			return a.lerp(b, restante / trecho)

		restante -= trecho

	return pontos[-1]

# Finalizar
# ---------------------
# Finaliza a rotina deste componente.
func finalizar() -> void:

	if not _ativo:

		return

	if is_instance_valid(_efeitos):

		_efeitos.call("parar")
		_efeitos.set("ataque_a_distancia", _distancia_original)
		_efeitos.process_mode = _modo_efeitos

	_ativo = false
