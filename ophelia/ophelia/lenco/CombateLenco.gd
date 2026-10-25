extends RefCounted
## Componente especializado; o coordenador fornece o estado e as referências.
var lenco

func configurar(coordenador) -> void:
	lenco = coordenador

func _atualizar_ataque(origem: Vector2, delta: float) -> void:
	lenco.pontos_tras[0] = origem
	lenco.pontos_frente[0] = origem

	var dir = lenco.dir_acao
	var perp = Vector2(-dir.y, dir.x)

	var abertura_losango_1: float = 15.0
	var abertura_losango_2: float = 10.0

	var offsets_verde: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]
	var offsets_vermelho: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]

	offsets_verde[1] = perp * abertura_losango_1
	offsets_vermelho[1] = -perp * abertura_losango_1
	offsets_verde[2] = Vector2.ZERO
	offsets_vermelho[2] = Vector2.ZERO
	offsets_verde[3] = -perp * abertura_losango_2
	offsets_vermelho[3] = perp * abertura_losango_2
	offsets_verde[4] = Vector2.ZERO
	offsets_vermelho[4] = Vector2.ZERO

	lenco._aplicar_forma(origem, dir, lenco.alcance_ataque, offsets_verde, offsets_vermelho, delta, lenco.duracao_formacao_ataque)

	if lenco.area_ataque:
		# No modo à distância quem machuca é a ponta lançada, não o golpe curto
		lenco.area_ataque.monitoring = (not lenco.ataque_a_distancia) and lenco.tempo_estado >= lenco.duracao_formacao_ataque * 0.6 # ativa quando a ponta está quase lá
		lenco.area_ataque.global_position = origem + (dir * (lenco.alcance_ataque * 0.7))
		lenco.area_ataque.rotation = dir.angle()
		if lenco.area_ataque.monitoring:
			for corpo in lenco.area_ataque.get_overlapping_bodies():
				lenco._ao_ataque_normal_atingir(corpo)
			for area in lenco.area_ataque.get_overlapping_areas():
				lenco._ao_ataque_normal_atingir(area)

	# Auge do movimento: o projétil é lançado na direção escolhida
	if lenco.ataque_a_distancia and not lenco.projetil_lancado and lenco.tempo_estado >= lenco.duracao_formacao_ataque:
		lenco.projetil_lancado = true
		lenco._lancar_projetil()

func _atualizar_defesa(origem: Vector2, _delta: float) -> void:
	var centro = lenco._centro_corpo() + lenco.redoma_deslocamento * Vector2(lenco.frente_defesa, 1.0)
	var raio = maxf(lenco.raio_defesa, 20.0)
	var angulo_gola = asin(clampf((origem.y - centro.y) / raio, -0.95, 0.95))
	var extra = deg_to_rad(lenco.sobreposicao_arcos_defesa)
	# Saídas retas na altura da gola, em sentidos opostos.
	var caminho_tras = lenco._caminho_circular_defesa(origem, centro, raio, angulo_gola, extra, 1.0)
	var caminho_frente = lenco._caminho_circular_defesa(origem, centro, raio, PI - angulo_gola, extra, -1.0)
	var linear = clampf(lenco.tempo_estado / maxf(lenco.duracao_formacao_defesa, 0.01), 0.0, 1.0)
	var progresso = smoothstep(0.0, 1.0, linear)
	var mistura_inicio = 1.0 - smoothstep(0.0, 0.25, linear)
	# O desenho é sempre um trecho do MESMO caminho, inclusive ao fechar.
	lenco.caminho_defesa_tras = lenco._revelar_caminho_defesa(caminho_tras, lenco.pontos_inicio_tras, progresso, mistura_inicio)
	lenco.caminho_defesa_frente = lenco._revelar_caminho_defesa(caminho_frente, lenco.pontos_inicio_frente, progresso, mistura_inicio)
	for i in range(lenco.pontos_por_fita):
		var pos = float(i) / float(lenco.pontos_por_fita - 1) * float(lenco.caminho_defesa_tras.size() - 1)
		lenco.pontos_tras[i] = lenco._amostrar_caminho(lenco.caminho_defesa_tras, pos)
		lenco.pontos_frente[i] = lenco._amostrar_caminho(lenco.caminho_defesa_frente, pos)
	lenco.pontos_tras[0] = origem
	lenco.pontos_frente[0] = origem
	lenco.caminho_defesa_tras[0] = origem
	lenco.caminho_defesa_frente[0] = origem

	# O preenchimento tem uma única circunferência, sem duplicar a sobreposição.
	lenco.vertices_redoma.clear()
	for i in range(128):
		var angulo = TAU * float(i) / 128.0
		lenco.vertices_redoma.append(centro + Vector2(cos(angulo), sin(angulo)) * raio)

	if lenco.area_defesa:
		lenco.area_defesa.monitoring = lenco.defesa_ativa()
		lenco.area_defesa.monitorable = lenco.defesa_ativa()
		lenco.area_defesa.atualizar_contatos()
		lenco.area_defesa.global_position = centro
		lenco.area_defesa.rotation = 0.0
		for filho in lenco.area_defesa.get_children():
			if filho is CollisionShape2D:
				if not filho.shape is CircleShape2D:
					filho.shape = CircleShape2D.new()
				var circulo = filho.shape as CircleShape2D
				circulo.radius = raio
				filho.position = Vector2.ZERO
				filho.scale = Vector2.ONE

	if lenco.efeitos:
		lenco.efeitos.definir_redoma(lenco.vertices_redoma, lenco.caminho_defesa_frente, lenco.caminho_defesa_tras, centro)

func _atualizar_propulsor(origem: Vector2, delta: float) -> void:
	lenco.pontos_tras[0] = origem
	lenco.pontos_frente[0] = origem

	var dir = lenco.dir_acao
	var perp = Vector2(-dir.y, dir.x)

	var altura_arco_1: float = 15.0
	var altura_cotovelo: float = 10.0
	var recuo_ponta: float = 40.0

	var offsets_verde: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]
	var offsets_vermelho: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]

	offsets_verde[1] = perp * altura_arco_1
	offsets_vermelho[1] = -perp * altura_arco_1
	offsets_verde[2] = Vector2.ZERO
	offsets_vermelho[2] = Vector2.ZERO
	offsets_verde[3] = -perp * altura_cotovelo
	offsets_vermelho[3] = perp * altura_cotovelo
	offsets_verde[4] = (-perp * (altura_cotovelo + 35.0)) - (dir * recuo_ponta)
	offsets_vermelho[4] = (perp * (altura_cotovelo + 35.0)) - (dir * recuo_ponta)

	lenco._aplicar_forma(origem, dir, lenco.alcance_propulsor, offsets_verde, offsets_vermelho, delta, lenco.duracao_formacao_propulsor)


func aplicar_propulsor() -> void:
	# O golpe e o jato chegam ao auge no mesmo quadro em que sai o impulso.
	if lenco.impulso_propulsor_pendente and lenco.tempo_estado >= lenco.duracao_formacao_propulsor:
		lenco.impulso_propulsor_pendente = false
		if lenco.jogador and not lenco.jogador.is_on_floor():
			# Encerra a planagem para ela não limitar o segundo pulo.
			if lenco.jogador.has_method("_encerrar_planar"):
				lenco.jogador.call("_encerrar_planar")
			# Usa a direção do mouse travada no início da ação, no sentido contrário.
			# Mantém a força consistente e preserva a velocidade perpendicular.
			var direcao_impulso = -lenco.dir_acao.normalized()
			var velocidade_propulsor_atual = maxf(absf(lenco.forca_propulsor), 1.0)
			if lenco.velocidade_max_propulsor > 0.0:
				velocidade_propulsor_atual = minf(velocidade_propulsor_atual, lenco.velocidade_max_propulsor)
			var atual_na_direcao = lenco.jogador.velocity.dot(direcao_impulso)
			var impulso = direcao_impulso * (velocidade_propulsor_atual - atual_na_direcao)
			lenco.jogador.aplicar_impulso(impulso, lenco.embalo_propulsor, 0.0)

func _lancar_projetil() -> void:
	if lenco.projeteis.size() >= 2:
		return
	var ponta = (lenco.pontos_tras[lenco.pontos_por_fita - 1] + lenco.pontos_frente[lenco.pontos_por_fita - 1]) * 0.5
	var p = lenco.CenaProjetil.instantiate()
	p.top_level = true   # Voa no mundo, independente do movimento da personagem
	p.velocidade_ida = lenco.velocidade_projetil
	p.velocidade_volta = lenco.velocidade_volta_projetil
	p.alcance = lenco.alcance_projetil
	p.tempo_espera = lenco.tempo_recarga_projetil
	p.raio = lenco.raio_projetil
	p.cor = lenco._cor_do_lenco().lerp(Color.WHITE, 0.45)
	p.textura_ponta = lenco.textura_projetil
	p.tamanho_ponta = lenco.tamanho_projetil
	p.dano = lenco.dano_projetil
	p.mascara_dano = lenco.mascara_dano
	p.destino_volta = Callable(lenco, "_posicao_da_gola")
	p.mascara_cenario = lenco.raio_alcance.collision_mask if lenco.raio_alcance else 1
	var excluidos: Array[RID] = []
	if lenco.jogador:
		excluidos.append(lenco.jogador.get_rid())
	p.excluir = excluidos
	p.ignorar = lenco.jogador
	p.apoio_desativado.connect(lenco._soltar_apoio_projetil.bind(p))
	p.acertou.connect(lenco._ao_projetil_acertar.bind(p))
	p.bateu_no_cenario.connect(lenco._ao_projetil_bater)
	p.tree_exiting.connect(lenco._ao_projetil_voltar.bind(p))
	lenco.add_child(p)
	p.lancar(ponta, lenco.dir_acao)
	lenco.projeteis.append(p)
	if lenco.efeitos:
		lenco.efeitos.faiscas_em(ponta, 10, 120.0)

func _posicao_da_gola() -> Vector2:
	return lenco.origem_anterior

func _ao_projetil_acertar(alvo: Node, p: OpheliaProjetilLenco) -> void:
	if lenco.efeitos and is_instance_valid(p):
		lenco.efeitos.faiscas_em(p.global_position, 14, 180.0)
	lenco.projetil_acertou.emit(alvo)

func _ao_projetil_bater(onde: Vector2) -> void:
	if lenco.efeitos:
		lenco.efeitos.faiscas_em(onde, 12, 150.0)

func _ao_projetil_voltar(p: OpheliaProjetilLenco) -> void:
	# Libera somente a carga deste disparo.
	lenco._soltar_apoio_projetil(p)
	lenco.projeteis.erase(p)
	if lenco.efeitos:
		lenco.efeitos.faiscas_em(lenco.origem_anterior, 8, 90.0)

func _ao_ataque_normal_atingir(contato: Node) -> void:
	if lenco.estado_atual != lenco.EstadoLenco.ATAQUE or lenco.ataque_a_distancia:
		return
	if lenco.tempo_estado < lenco.duracao_formacao_ataque * 0.6:
		return
	var alvo: Node = OpheliaDano.encontrar_receptor(contato, lenco.jogador)
	if alvo == null or alvo.get_instance_id() in lenco.alvos_atingidos:
		return
	lenco.alvos_atingidos.append(alvo.get_instance_id())
	OpheliaDano.aplicar(alvo, lenco.dano_ataque_normal)
