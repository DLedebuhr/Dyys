extends RefCounted
## Componente especializado; o coordenador fornece o estado e as referências.
var corpo

func configurar(coordenador) -> void:
	corpo = coordenador

func agradecer_ajuda() -> void:
	corpo.tocar_reacao(corpo.REACAO_AGRADECER_AJUDA)

func tocar_reacao(id: StringName) -> void:
	if id != corpo.REACAO_IRRITADA and id != corpo.REACAO_AGRADECER_AJUDA and id != corpo.REACAO_PARADA:
		push_warning("OPHELIA: reação desconhecida '%s'." % id)
		return
	corpo.reacao_pendente = id
	corpo.tempo_espera_reacao = corpo.espera_maxima_reacao

func cancelar_reacao() -> void:
	corpo.reacao_atual = &""
	corpo.estado_pose = corpo.EstadoPose.Normal

	corpo.reacao_pendente = &""
	corpo.pulo_apos_transicao = false
	corpo.tempo_transicao_pose = 0.0
	corpo.tempo_ocioso = 0.0
	corpo.tempo_frontal_imovel = 0.0

func _processar_reacoes(delta: float) -> void:
	var direcao = Input.get_axis("ControleAndarEsquerda", "ControleAndarDireita")
	var quer_pular: bool = corpo.entrada.pressionou("ControlePular") or corpo.tem_pedido(&"ControlePular")
	var agindo = Input.is_anything_pressed() or absf(corpo.velocity.x) > 10.0 or not corpo.is_on_floor()

	if corpo.estado_pose != corpo.EstadoPose.Normal and not corpo.is_on_floor():
		corpo.cancelar_reacao()
		return

	if corpo.estado_pose == corpo.EstadoPose.Entrando or corpo.estado_pose == corpo.EstadoPose.Saindo:
		corpo.tempo_transicao_pose = maxf(corpo.tempo_transicao_pose - delta, 0.0)
		if corpo.estado_pose == corpo.EstadoPose.Saindo and quer_pular:
			corpo.pulo_apos_transicao = true
	elif corpo.estado_pose == corpo.EstadoPose.EsperarMovimento:
		corpo.tempo_frontal_imovel = maxf(corpo.tempo_frontal_imovel - delta, 0.0)
		# Chapéu/debug e teclas sem ação não tiram a personagem da espera.
		var outra_acao: bool = corpo.tem_acao_pendente()
		for acao in ["ControleSentarLevantar", "ControleAtaqueLenco", "ControleDefesaLenco", "ControleFixarLenco"]:
			if InputMap.has_action(acao) and corpo.entrada.pressionou(acao):
				outra_acao = true
		if not is_zero_approx(direcao) or quer_pular or outra_acao:
			corpo.pulo_apos_transicao = quer_pular
			corpo._iniciar_saida_frontal(direcao)

	if corpo.reacao_pendente != &"":
		corpo.tempo_espera_reacao -= delta
		if corpo.tempo_espera_reacao <= 0.0:
			corpo.reacao_pendente = &""
		elif corpo._pode_iniciar_reacao(corpo.reacao_pendente, agindo):
			var pedido = corpo.reacao_pendente
			corpo.reacao_pendente = &""
			corpo._iniciar_reacao(pedido)

	if corpo.estado_pose == corpo.EstadoPose.Normal and corpo.reacao_pendente == &"" and corpo._livre_para_reagir() and not agindo:
		corpo.tempo_ocioso += delta
		if corpo.tempo_ocioso >= corpo.tempo_parada:
			corpo.tempo_ocioso = 0.0
			corpo.sentou_por_inatividade = true
			corpo.esta_sentada = true
			corpo.esta_levantando = false
			corpo._tocar("Sentar", true)
	else:
		corpo.tempo_ocioso = 0.0

func _livre_para_reagir() -> bool:
	return corpo.is_on_floor() and not corpo.esta_sentada and not corpo.esta_levantando and not corpo.planando \
			and (corpo.lenco == null or corpo.lenco.estado_atual == corpo.lenco.EstadoLenco.REPOUSO)

func _pode_iniciar_reacao(id: StringName, agindo: bool) -> bool:
	if id == corpo.REACAO_PARADA and agindo:
		return false
	if not corpo._livre_para_reagir():
		return false
	return corpo.estado_pose == corpo.EstadoPose.Normal or corpo.estado_pose == corpo.EstadoPose.EsperarMovimento

func _iniciar_reacao(id: StringName) -> void:
	var ja_de_frente = corpo.estado_pose == corpo.EstadoPose.EsperarMovimento
	corpo.reacao_atual = id
	corpo.tempo_ocioso = 0.0
	corpo.pulo_apos_transicao = false
	if ja_de_frente:
		corpo._comecar_animacao_reacao()
		return
	corpo.estado_pose = corpo.EstadoPose.Entrando

	corpo.lado_transicao = corpo.olhando_esquerda
	corpo._tocar_transicao_pose(false)

func _tocar_transicao_pose(saindo: bool) -> void:
	var nome = corpo._nome_anim("Transicao")
	if not corpo._tem_anim(nome):
		corpo._concluir_transicao_pose()
		return
	corpo.duracao_transicao_atual = maxf(corpo.duracao_transicao_pose, 0.05)
	corpo.tempo_transicao_pose = corpo.duracao_transicao_atual
	var velocidade = maxf(corpo._duracao_animacao(nome), 0.01) / corpo.duracao_transicao_atual
	corpo.sprite.stop()
	corpo.sprite.flip_h = corpo.lado_transicao
	corpo.sprite.play(nome, -velocidade if saindo else velocidade, saindo)

func _comecar_animacao_reacao() -> void:

	if corpo.reacao_atual == corpo.REACAO_PARADA:
		corpo._entrar_esperar_movimento()
		return
	corpo.estado_pose = corpo.EstadoPose.Reagindo
	var anim = corpo._anim_da_reacao(corpo.reacao_atual)
	var nome = corpo._nome_anim(anim)
	if not corpo._tem_anim(nome):
		push_warning("OPHELIA: não existe a animação '%s'." % nome)
		corpo._entrar_esperar_movimento()
		return
	var duracao_reacao: float = maxf(corpo.duracao_irritada if corpo.reacao_atual == corpo.REACAO_IRRITADA else corpo.duracao_agradecer, 0.01)
	var velocidade = maxf(corpo._duracao_animacao(nome), 0.01) / duracao_reacao
	corpo.sprite.stop()
	corpo.sprite.flip_h = false
	corpo.sprite.play(nome, velocidade)
	corpo._log_reacao("%s iniciada" % corpo.reacao_atual)

func _entrar_esperar_movimento() -> void:
	corpo._log_reacao("%s concluída; EsperarMovimento" % corpo.reacao_atual)
	corpo.reacao_atual = &""

	corpo.estado_pose = corpo.EstadoPose.EsperarMovimento
	corpo.tempo_ocioso = 0.0
	corpo.tempo_frontal_imovel = 10.0
	# Primeiro quadro frontal neutro; não congela a reverência final.
	corpo._tocar(corpo._nome_espera_frontal(), true)
	corpo.sprite.pause()
	corpo.sprite.set_frame_and_progress(0, 0.0)

func _iniciar_saida_frontal(direcao: float) -> void:
	if not is_zero_approx(direcao):
		corpo.olhando_esquerda = direcao < 0.0
	corpo.lado_transicao = corpo.olhando_esquerda
	corpo.estado_pose = corpo.EstadoPose.Saindo

	corpo._tocar_transicao_pose(true)

func _concluir_transicao_pose() -> void:
	if corpo.estado_pose == corpo.EstadoPose.Entrando:
		corpo._comecar_animacao_reacao()
	elif corpo.estado_pose == corpo.EstadoPose.Saindo:
		corpo.estado_pose = corpo.EstadoPose.Normal

		corpo.reacao_atual = &""
		corpo.tempo_transicao_pose = 0.0
		if corpo.pulo_apos_transicao:
			corpo.tempo_jump_buffer = corpo.jump_buffer_limite
		corpo.pulo_apos_transicao = false

func _ao_terminar_animacao_reacao() -> void:
	if corpo.estado_pose == corpo.EstadoPose.Entrando or corpo.estado_pose == corpo.EstadoPose.Saindo:
		if String(corpo.sprite.animation).begins_with("Transicao"):
			corpo._concluir_transicao_pose()
	elif corpo.estado_pose == corpo.EstadoPose.Reagindo:
		if corpo.sprite.animation == corpo._nome_anim(corpo._anim_da_reacao(corpo.reacao_atual)):
			corpo._entrar_esperar_movimento()

func _reacao_trava() -> bool:
	return corpo.estado_pose != corpo.EstadoPose.Normal

func progresso_pose_frontal() -> float:
	match corpo.estado_pose:
		corpo.EstadoPose.Entrando:
			return 1.0 - clampf(corpo.tempo_transicao_pose / maxf(corpo.duracao_transicao_atual, 0.01), 0.0, 1.0)
		corpo.EstadoPose.Saindo:
			return clampf(corpo.tempo_transicao_pose / maxf(corpo.duracao_transicao_atual, 0.01), 0.0, 1.0)
		corpo.EstadoPose.Reagindo, corpo.EstadoPose.EsperarMovimento:
			return 1.0
	return 0.0

func _nome_espera_frontal() -> String:
	# EsperarMovimento é a pose neutra; após os dez segundos toca Esperar.
	if corpo.tempo_frontal_imovel <= 0.0 and corpo._tem_anim(corpo._nome_anim("Esperar")):
		return "Esperar"
	return "EsperarMovimento" if corpo._tem_anim(corpo._nome_anim("EsperarMovimento")) else "Esperar"

func _log_reacao(texto: String) -> void:
	if corpo.imprimir_reacoes:
		print("Reação: ", texto)
