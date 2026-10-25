extends RefCounted
## Componente especializado; o coordenador fornece o estado e as referências.
var corpo

func configurar(coordenador) -> void:
	corpo = coordenador

func _preparar_animacoes_reacao() -> void:
	if corpo.sprite.sprite_frames == null:
		return
	# Recursos próprios: não altera os SpriteFrames de outras personagens.
	corpo.sprite.sprite_frames = corpo.sprite.sprite_frames.duplicate() as SpriteFrames
	for sufixo in ["Base", "Chapeu"]:
		var transicao: String = "Transicao" + String(sufixo)
		var configurados: Array[Texture2D] = corpo.quadros_transicao_base if sufixo == "Base" else corpo.quadros_transicao_chapeu
		if not configurados.is_empty() or not corpo._tem_anim(transicao):
			if not corpo._tem_anim(transicao):
				corpo.sprite.sprite_frames.add_animation(transicao)
			corpo.sprite.sprite_frames.clear(transicao)
			for textura in configurados:
				if textura != null:
					corpo.sprite.sprite_frames.add_frame(transicao, textura)
			if corpo.sprite.sprite_frames.get_frame_count(transicao) == 0:
				# A cena enviada não contém os quadros intermediários da transição.
				# Fallback explícito: perfil -> frente, usando as poses existentes.
				for pose in ["Parado" + sufixo, "EsperarMovimento" + sufixo, "Esperar" + sufixo]:
					if corpo._tem_anim(pose) and corpo.sprite.sprite_frames.get_frame_count(pose) > 0:
						corpo.sprite.sprite_frames.add_frame(transicao, corpo.sprite.sprite_frames.get_frame_texture(pose, 0))
						if pose.begins_with("Esperar"):
							break
			if corpo.sprite.sprite_frames.get_frame_count(transicao) == 0:
				corpo.sprite.sprite_frames.remove_animation(transicao)
				continue
			corpo.sprite.sprite_frames.set_animation_speed(transicao, 8.0)
		if corpo._tem_anim(transicao):
			corpo.sprite.sprite_frames.set_animation_loop(transicao, false)
		for pose in ["Irritada", "Agradecer", "Esperar", "EsperarMovimento"]:
			var nome: String = String(pose) + String(sufixo)
			if corpo._tem_anim(nome):
				corpo.sprite.sprite_frames.set_animation_loop(nome, pose.begins_with("Esperar"))

func _aplicar_espelho() -> void:
	if not corpo.sprite:
		return
	var nome = String(corpo.sprite.animation)
	var sem_espelho = false
	for prefixo in corpo.ANIMACOES_SEM_ESPELHO:
		if nome.begins_with(prefixo):
			sem_espelho = true
	var lado = corpo.lado_transicao if corpo.estado_pose == corpo.EstadoPose.Entrando or corpo.estado_pose == corpo.EstadoPose.Saindo else corpo.olhando_esquerda
	corpo.sprite.flip_h = lado and not sem_espelho

func _duracao_animacao(nome: String) -> float:
	var quadros = corpo.sprite.sprite_frames
	var fps = quadros.get_animation_speed(nome)
	if fps <= 0.0:
		return 0.0
	var total = 0.0
	for i in quadros.get_frame_count(nome):
		total += quadros.get_frame_duration(nome, i)
	return total / fps

func _anim_da_reacao(id: StringName) -> String:
	if id == corpo.REACAO_IRRITADA:
		return "Irritada"
	if id == corpo.REACAO_AGRADECER_AJUDA:
		return "Agradecer"
	return "Esperar"

func definir_chapeu(usar: bool) -> void:
	if corpo.usando_chapeu == usar:
		return
	var antigo = String(corpo.sprite.animation) if corpo.sprite else ""
	var frame_anterior = corpo.sprite.frame if corpo.sprite else 0
	var progresso_anterior = corpo.sprite.frame_progress if corpo.sprite else 0.0
	var velocidade_anterior = corpo.sprite.get_playing_speed() if corpo.sprite else 1.0
	corpo.usando_chapeu = usar
	var base = antigo.trim_suffix("Chapeu").trim_suffix("Base")
	var novo = corpo._nome_anim(base)
	if corpo._tem_anim(novo):
		var taxa = velocidade_anterior / maxf(absf(corpo.sprite.speed_scale), 0.001)
		var manter_pausa: bool = corpo.estado_pose == corpo.EstadoPose.EsperarMovimento and corpo.tempo_frontal_imovel > 0.0
		corpo.sprite.play(novo, taxa, taxa < 0.0)
		var ultimo = corpo.sprite.sprite_frames.get_frame_count(novo) - 1
		corpo.sprite.set_frame_and_progress(clampi(frame_anterior, 0, ultimo), progresso_anterior)
		if manter_pausa:
			corpo.sprite.pause()

func _nome_anim(nome: String) -> String:
	return nome + ("Chapeu" if corpo.usando_chapeu else "Base")

func _tem_anim(nome: String) -> bool:
	return corpo.sprite != null and corpo.sprite.sprite_frames != null and corpo.sprite.sprite_frames.has_animation(nome)

func _tocar(nome: String, reiniciar: bool = false) -> void:
	var alvo = corpo._nome_anim(nome)
	if not corpo._tem_anim(alvo):
		return
	if corpo.sprite.animation == alvo and not reiniciar:
		return
	# Trocou só o chapéu (mesma animação, outra versão)? Mantém o frame em vez de recomeçar.
	var mesma_animacao = not reiniciar and String(corpo.sprite.animation).begins_with(nome)
	var frame_antes = corpo.sprite.frame
	if reiniciar:
		corpo.sprite.stop()
	corpo.sprite.play(alvo)
	if mesma_animacao:
		var ultimo = corpo.sprite.sprite_frames.get_frame_count(alvo) - 1
		corpo.sprite.set_frame_and_progress(mini(frame_antes, ultimo), 0.0)

func _atualizar_animacoes() -> void:
	if not corpo.sprite or not corpo.sprite.sprite_frames:
		return

	# NO AR: pular, planar e balançar usam a mesma animação de pulo
	# (o planar ganha o efeito das asas pelo nó Asas)
	if not corpo.is_on_floor():
		corpo.esta_levantando = false
		corpo._tocar("Pular")
		return

	# Espera a animação 'Levantar' terminar
	if corpo.esta_levantando:
		if corpo.sprite.animation != corpo._nome_anim("Levantar") or not corpo.sprite.is_playing():
			corpo.esta_levantando = false
		else:
			return

	# A pose frontal tem prioridade sobre a locomoção e não reinicia a transição inversa.
	if corpo.estado_pose == corpo.EstadoPose.Entrando or corpo.estado_pose == corpo.EstadoPose.Saindo:
		return
	if corpo.estado_pose == corpo.EstadoPose.Reagindo:
		return
	if corpo.estado_pose == corpo.EstadoPose.EsperarMovimento:
		corpo._tocar(corpo._nome_espera_frontal())
		if corpo.tempo_frontal_imovel > 0.0:
			corpo.sprite.pause()
			corpo.sprite.set_frame_and_progress(0, 0.0)
		elif not corpo.sprite.is_playing():
			corpo.sprite.play()
		return

	if corpo.esta_sentada:
		corpo._tocar("Sentar")
	elif absf(corpo.velocity.x) > 10.0:
		corpo._tocar("Correr" if corpo.esta_correndo else "Andar")
	else:
		corpo._tocar("Parado")
