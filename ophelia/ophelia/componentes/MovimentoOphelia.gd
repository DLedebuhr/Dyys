extends RefCounted
## Componente especializado; o coordenador fornece o estado e as referências.
var corpo
# Levanta rapidamente antes de andar; pular pode interromper essa transição.
const DURACAO_LEVANTAR: float = 0.22

# Configurar o componente
# ---------------------
# Guarda a referência do coordenador usada por este componente.
func configurar(coordenador) -> void:

	corpo = coordenador

# Em gancho
# ---------------------
# Retorna em gancho.
func _em_gancho() -> bool:

	# Gancho num ponto firme (parede, chão, objeto pesado). Num objeto leve a corda não segura a personagem.
	return corpo.lenco != null and corpo.lenco.estado_atual == corpo.lenco.EstadoLenco.GANCHO and not corpo.lenco.ancora_leve

# Balancando
# ---------------------
# Processa balancando.
func _balancando() -> bool:

	return corpo._em_gancho() and corpo.lenco.corda_esticada and not corpo.is_on_floor()

# Atualizar temporizadores
# ---------------------
# Atualiza temporizadores.
func _atualizar_temporizadores(delta: float) -> void:

	corpo.tempo_embalo = maxf(corpo.tempo_embalo - delta, 0.0)
	# Coyote Time: permite pular pouco depois de deixar uma plataforma

	if corpo.is_on_floor():

		corpo.tempo_embalo = 0.0
		corpo.pode_cortar_pulo = true
		corpo.tempo_coyote = corpo.coyote_time_limite

	else:

		corpo.tempo_coyote -= delta
	# Jump Buffer: guarda a intenção de pulo pouco antes de tocar o chão

	if corpo.acao_ativada("ControlePular"):

		corpo.tempo_jump_buffer = corpo.jump_buffer_limite

	else:

		corpo.tempo_jump_buffer -= delta

# Processar inputs estado
# ---------------------
# Processa inputs estado.
func _processar_inputs_estado() -> void:

	if corpo.esta_levantando:

		var nome: String = corpo._nome_anim("Levantar")

		if corpo.sprite.animation != nome or not corpo.sprite.is_playing():

			corpo.esta_levantando = false

	if corpo.acao_ativada("ControleCorrer"):

		corpo.esta_correndo = not corpo.esta_correndo

	var tem_teto: bool = corpo.raycast_teto != null and corpo.raycast_teto.is_colliding()
	var quer_pular: bool = corpo.acao_ativada("ControlePular")

	if corpo.sentou_por_inatividade and quer_pular and not tem_teto:

		corpo._definir_estado_sentada(false)
		corpo.esta_levantando = false
		return

	if corpo.acao_ativada("ControleSentarLevantar") and corpo.is_on_floor() and not corpo._reacao_trava():

		if corpo.esta_sentada:

			if not tem_teto:

				_iniciar_levantar()

		elif not corpo.esta_levantando:

			corpo.sentou_por_inatividade = false
			corpo.esta_sentada = true
			corpo._tocar("Sentar", true)

		return

	if corpo.sentou_por_inatividade and not tem_teto:

		var quer_mover: bool = not is_zero_approx(Input.get_axis("ControleAndarEsquerda", "ControleAndarDireita"))

		if quer_mover or corpo.tem_acao_pendente():

			_iniciar_levantar()

# Iniciar levantar
# ---------------------
# Inicia levantar.
func _iniciar_levantar() -> void:

	corpo.sentou_por_inatividade = false
	corpo.esta_sentada = false
	var nome: String = corpo._nome_anim("Levantar")

	if not corpo._tem_anim(nome) or corpo.sprite.sprite_frames.get_frame_count(nome) == 0:

		corpo.esta_levantando = false
		return

	corpo.esta_levantando = true
	corpo.velocity.x = 0.0
	corpo._tocar("Levantar", true)
	var duracao: float = maxf(corpo._duracao_animacao(nome), 0.01)
	var taxa: float = duracao / DURACAO_LEVANTAR
	corpo.sprite.play(nome, taxa)

# Definir estado sentada
# ---------------------
# Define estado sentada.
func _definir_estado_sentada(sentar: bool) -> void:

	corpo.esta_sentada = sentar
	corpo.sentou_por_inatividade = false

# Processar planar
# ---------------------
# Processa planar.
func _processar_planar() -> void:

	if corpo._reacao_trava():

		return

	if corpo.planando:

		if corpo.is_on_floor():

			corpo._encerrar_planar()  # Pousou

		elif corpo._em_gancho():

			corpo._encerrar_planar()  # Prendeu o gancho: cancela

		elif not corpo.pode_usar(OpheliaHabilidades.PLANAR):

			corpo._encerrar_planar()  # A permissão acabou (ex.: o modo debug foi desligado)

		elif corpo.planar_segurando_tecla and not Input.is_action_pressed("ControlePular"):

			corpo._encerrar_planar()  # Soltou a tecla: volta a cair normalmente

		elif not corpo.planar_segurando_tecla and corpo.acao_ativada("ControlePular"):

			corpo._encerrar_planar()  # Modo toggle: apertou de novo para cancelar
			corpo.tempo_jump_buffer = 0.0

		return
	# Só começa fora do chão, depois do coyote time, sem gancho e se a habilidade estiver liberada

	if corpo.acao_ativada("ControlePular") \
			and not corpo.is_on_floor() \
			and corpo.tempo_coyote <= 0.0 \
			and not corpo._em_gancho() \
			and corpo.pode_usar(OpheliaHabilidades.PLANAR):

		corpo._iniciar_planar()

# Iniciar planar
# ---------------------
# Inicia planar.
func _iniciar_planar() -> void:

	corpo.planando = true
	corpo.tempo_jump_buffer = 0.0 # Não deixa o pulo "guardado" disparar ao pousar
	corpo.velocity.y = maxf(corpo.velocity.y, 0.0) # Se estava subindo, começa a planar do topo
	corpo.esta_levantando = false

# Encerrar planar
# ---------------------
# Encerra planar.
func _encerrar_planar() -> void:

	corpo.planando = false

# Aplicar gravidade
# ---------------------
# Aplica gravidade.
func _aplicar_gravidade(delta: float) -> void:

	if not corpo.is_on_floor():

		var grav = corpo.get_gravity().y
		# Planando: gravidade reduzida e velocidade de queda limitada

		if corpo.planando:

			corpo.velocity.y = minf(corpo.velocity.y + grav * corpo.planar_gravidade * delta, corpo.velocidade_queda_planando)
			return
		# Queda pesada só fora do balanço (no balanço a gravidade é simétrica)

		if corpo.velocity.y > 0 and not corpo._balancando():

			corpo.velocity.y += grav * corpo.gravidade_multiplicador_queda * delta

		else:

			corpo.velocity.y += grav * delta

# Processar pulo
# ---------------------
# Processa pulo.
func _processar_pulo() -> void:

	# Durante Irritada/Agradecer ela fica parada: sem pulo

	if corpo._reacao_trava():

		corpo.tempo_jump_buffer = 0.0
		return
	# O pulo é acionado se houver registro no Buffer E no Coyote Time

	if corpo.tempo_jump_buffer > 0.0 and corpo.tempo_coyote > 0.0:

		if corpo.esta_sentada and corpo.raycast_teto != null and corpo.raycast_teto.is_colliding():

			return

		corpo.esta_levantando = false
		corpo.velocity.y = corpo.forca_pulo
		corpo.pode_cortar_pulo = true
		corpo.tempo_jump_buffer = 0.0 # Consome o buffer
		corpo.tempo_coyote = 0.0      # Consome o coyote
		# Cancela o estado de sentada ao pular

		if corpo.esta_sentada and not (corpo.raycast_teto and corpo.raycast_teto.is_colliding()):

			corpo._definir_estado_sentada(false)
	# Pulo variável: corta a altura se soltar a tecla no ar

	if corpo.entrada.soltou("ControlePular") and corpo.velocity.y < 0.0 and corpo.pode_cortar_pulo:

		corpo.velocity.y *= 0.5

# Processar movimento horizontal
# ---------------------
# Processa movimento horizontal.
func _processar_movimento_horizontal(delta: float) -> void:

	# O comando já foi aceito, mas o corpo só se desloca após terminar Levantar.

	if corpo.esta_levantando and corpo.is_on_floor():

		corpo.velocity.x = 0.0
		var direcao_levantar: float = Input.get_axis("ControleAndarEsquerda", "ControleAndarDireita")

		if not is_zero_approx(direcao_levantar):

			corpo.olhando_esquerda = direcao_levantar < 0.0

		return
	# Durante Irritada/Agradecer ela fica parada: só desacelera

	if corpo._reacao_trava():

		corpo.velocity.x = move_toward(corpo.velocity.x, 0.0, corpo.atrito * delta)
		return
	# Sentada no chão: só desacelera

	if corpo.esta_sentada and corpo.is_on_floor():

		corpo.velocity.x = move_toward(corpo.velocity.x, 0.0, corpo.atrito * delta)
		return

	var direcao = Input.get_axis("ControleAndarEsquerda", "ControleAndarDireita")
	# Balançando na corda esticada: sem atrito nem aceleração própria,
	# o lenço cuida do embalo. Só vira o sprite.

	if corpo._balancando():

		if direcao != 0.0:

			corpo.olhando_esquerda = (direcao < 0.0)

		return

	var vel_maxima = corpo.velocidade_correr if corpo.esta_correndo else corpo.velocidade_andar
	# Depois de um impulso no ar (propulsor) o embalo horizontal se mantém: só ajuda a ir para o lado apertado

	if corpo.tempo_embalo > 0.0 and not corpo.is_on_floor():

		if direcao != 0.0:

			corpo.olhando_esquerda = (direcao < 0.0)
			var alvo_x = direcao * vel_maxima

			if absf(corpo.velocity.x) < absf(alvo_x) or signf(corpo.velocity.x) != signf(alvo_x):

				corpo.velocity.x = move_toward(corpo.velocity.x, alvo_x, corpo.aceleracao * delta)

		return

	if direcao != 0.0:

		corpo.velocity.x = move_toward(corpo.velocity.x, direcao * vel_maxima, corpo.aceleracao * delta)
		corpo.olhando_esquerda = (direcao < 0.0)

	else:

		corpo.velocity.x = move_toward(corpo.velocity.x, 0.0, corpo.atrito * delta)

# Aplicar impulso
# ---------------------
# Aplica impulso.
func aplicar_impulso(impulso: Vector2, embalo: float = 0.0, velocidade_max: float = 0.0) -> void:

	corpo.velocity += impulso

	if velocidade_max > 0.0:

		corpo.velocity = corpo.velocity.limit_length(velocidade_max)

	corpo.tempo_embalo = maxf(corpo.tempo_embalo, embalo)
	corpo.pode_cortar_pulo = false   # Soltar o pulo não corta a subida causada pelo impulso
