extends RefCounted
## Componente especializado; o coordenador fornece o estado e as referências.
var lenco

func configurar(coordenador) -> void:
	lenco = coordenador

func _calcular_offset_gola(delta: float) -> Vector2:
	var alvo = lenco._offset_do_dicionario(lenco.offset_gola_por_animacao)
	lenco.offset_gola_atual = lenco.offset_gola_atual.lerp(alvo, 1.0 - exp(-lenco.suavidade_offset_gola * delta))
	return lenco.offset_gola_atual

func _offset_do_dicionario(dic: Dictionary) -> Vector2:
	var alvo = Vector2.ZERO
	var anim = lenco.sprite_jogador as AnimatedSprite2D
	if anim:
		var nome = String(anim.animation)
		if dic.has(nome):
			var dado = dic[nome]
			if dado is Array and not dado.is_empty():
				alvo = dado[clampi(anim.frame, 0, dado.size() - 1)]
			elif dado is Vector2:
				alvo = dado
			if anim.flip_h:
				alvo.x = -alvo.x
	return alvo

func _calcular_offsets_fitas(delta: float) -> void:
	var k = 1.0 - exp(-lenco.suavidade_offset_gola * delta)
	lenco.offset_tras_atual = lenco.offset_tras_atual.lerp(lenco._offset_do_dicionario(lenco.offset_fita_tras_por_animacao), k)
	lenco.offset_frente_atual = lenco.offset_frente_atual.lerp(lenco._offset_do_dicionario(lenco.offset_fita_frente_por_animacao), k)

func _atualizar_frontal(_delta: float) -> void:
	lenco.frontal = lenco.jogador.progresso_pose_frontal()

func _olhando_esquerda() -> bool:
	return lenco.jogador.olhando_esquerda

func _acompanhar_origem(origem: Vector2) -> void:
	if not lenco.origem_inicializada:
		lenco.origem_anterior = origem
		lenco.origem_inicializada = true
		for i in range(lenco.pontos_por_fita):
			lenco.pontos_tras[i] = origem
			lenco.pontos_frente[i] = origem
			lenco.pontos_inicio_tras[i] = origem
			lenco.pontos_inicio_frente[i] = origem
		return

	var deslocamento = origem - lenco.origem_anterior
	lenco.origem_anterior = origem

	for i in range(1, lenco.pontos_por_fita):
		var t = float(i) / float(lenco.pontos_por_fita - 1)
		var fator = lerpf(1.0, 0.5, t) # a ponta mantém um pouco de inércia
		lenco.pontos_tras[i] += deslocamento * fator
		lenco.pontos_frente[i] += deslocamento * fator
		lenco.pontos_inicio_tras[i] += deslocamento * fator
		lenco.pontos_inicio_frente[i] += deslocamento * fator

func _peso_ponto(t: float, taxa_base: float, taxa_ponta: float, delta: float) -> float:
	return 1.0 - exp(-lerpf(taxa_base, taxa_ponta, t) * delta)

func _ondas_repouso(t: float, amp: float, fator_ponta: float) -> Vector2:
	var onda_tras = sin(lenco.tempo_balanco - (t * 3.0)) * (amp * 0.92 * fator_ponta)
	var onda_frente = cos(lenco.tempo_balanco - (t * 2.6)) * (amp * 1.08 * fator_ponta)
	var onda_sec = sin((lenco.tempo_balanco * 1.5) - (t * 5.0)) * (amp * 0.23 * fator_ponta)
	return Vector2(onda_tras + onda_sec, -onda_frente - onda_sec)

func _amostrar_caminho(offsets: Array[Vector2], pos: float) -> Vector2:
	var ultimo = offsets.size() - 1
	var i1 = clampi(int(floor(pos)), 0, ultimo)
	var i2 = mini(i1 + 1, ultimo)
	var i0 = maxi(i1 - 1, 0)
	var i3 = mini(i2 + 1, ultimo)
	return offsets[i1].cubic_interpolate(offsets[i2], offsets[i0], offsets[i3], pos - float(i1))

func _aplicar_forma(origem: Vector2, dir: Vector2, alcance: float,
		offsets_verde: Array[Vector2], offsets_vermelho: Array[Vector2], delta: float, duracao: float) -> void:
	# Posição final de cada ponto da figura (índice 0 = origem)
	var final_verde: Array[Vector2] = []
	var final_vermelho: Array[Vector2] = []
	for k in range(lenco.pontos_por_fita):
		var tk = float(k) / float(lenco.pontos_por_fita - 1)
		var eixo = origem + (dir * (alcance * tk))
		final_verde.append(eixo + lenco._amostrar_caminho(offsets_verde, tk * 4.0))
		final_vermelho.append(eixo + lenco._amostrar_caminho(offsets_vermelho, tk * 4.0))

	lenco._mover_para_figura(final_verde, final_vermelho, delta, duracao)

func _mover_para_figura(final_verde: Array[Vector2], final_vermelho: Array[Vector2], delta: float, duracao: float) -> void:
	var linear = clampf(lenco.tempo_estado / maxf(duracao, 0.01), 0.0, 1.0)
	var u = smoothstep(0.0, 1.0, linear) # 0 = tudo na origem, 1 = figura completa
	# No começo, mistura a pose em que o lenço estava para não dar um salto
	var mistura_inicio = 1.0 - smoothstep(0.0, 0.25, linear)

	for i in range(1, lenco.pontos_por_fita):
		var t = float(i) / float(lenco.pontos_por_fita - 1)

		# O ponto i anda de 0 até i (em "unidades de ponto") sobre o caminho da figura:
		# quando u = 1/8 a ponta está na posição final do ponto 1, em 2/8 na do ponto 2, etc.
		var s_caminho = float(i) * u
		var alvo_verde = lenco._amostrar_caminho(final_verde, s_caminho)
		var alvo_vermelho = lenco._amostrar_caminho(final_vermelho, s_caminho)

		alvo_verde = alvo_verde.lerp(lenco.pontos_inicio_frente[i], mistura_inicio)
		alvo_vermelho = alvo_vermelho.lerp(lenco.pontos_inicio_tras[i], mistura_inicio)

		# Suavização leve (a ponta segue o caminho de perto)
		var peso_lerp = lenco._peso_ponto(t, 30.0, 45.0, delta)
		lenco.pontos_frente[i] = lenco.pontos_frente[i].lerp(alvo_verde, peso_lerp)
		lenco.pontos_tras[i] = lenco.pontos_tras[i].lerp(alvo_vermelho, peso_lerp)

func _suavizar_curva(pts: Array[Vector2]) -> PackedVector2Array:
	var saida = PackedVector2Array()
	var n = pts.size()
	var sub = maxi(lenco.subdivisoes_curva, 1)
	for i in range(n - 1):
		var p0 = pts[maxi(i - 1, 0)]
		var p1 = pts[i]
		var p2 = pts[i + 1]
		var p3 = pts[mini(i + 2, n - 1)]
		for s in range(sub):
			saida.append(p1.cubic_interpolate(p2, p0, p3, float(s) / float(sub)))
	saida.append(pts[n - 1])
	return saida

func _atualizar_indicador_alcance(origem: Vector2, delta: float) -> void:
	lenco.origem_alcance = origem

	if not lenco.indicador_alcance_ativo:
		lenco.alcance_visivel = 0.0
		return

	# Botão (segurar ou alternar)
	var botao = false
	if lenco.alcance_alternar:
		if lenco.jogador.entrada.pressionou(lenco.ACAO_ALCANCE):
			lenco.alcance_alternado = not lenco.alcance_alternado
		botao = lenco.alcance_alternado
	else:
		botao = Input.is_action_pressed(lenco.ACAO_ALCANCE)

	# Aviso temporário (clicou sem ter onde prender)
	lenco.tempo_aviso_alcance = maxf(lenco.tempo_aviso_alcance - delta, 0.0)
	var mostrando = botao or lenco.tempo_aviso_alcance > 0.0

	# Ao começar a mostrar, dispara o anel que se expande a partir do personagem
	if mostrando and not lenco.mostrando_alcance_antes:
		lenco.pulso_alcance = 0.0
	lenco.mostrando_alcance_antes = mostrando
	lenco.pulso_alcance = minf(lenco.pulso_alcance + delta / 0.35, 1.0)

	# Aparece rápido e some devagar
	var alvo = 1.0 if mostrando else 0.0
	lenco.alcance_visivel = move_toward(lenco.alcance_visivel, alvo, delta * (6.0 if mostrando else 3.0))
	lenco.tempo_visual_alcance += delta

func _desenhar_alcance() -> void:
	if lenco.alcance_visivel <= 0.01:
		return

	var centro = lenco.to_local(lenco.origem_alcance)
	var raio = lenco.alcance_gancho
	var a = lenco.alcance_visivel

	# Preenchimento suave
	lenco.draw_circle(centro, raio, Color(lenco.cor_alcance, 0.07 * a))

	# Anel contínuo fino
	lenco.draw_arc(centro, raio, 0.0, TAU, 128, Color(lenco.cor_alcance, 0.35 * a), 1.5, true)

	# Anel tracejado girando devagar
	var tracos = 48
	var passo = TAU / float(tracos)
	var giro = lenco.tempo_visual_alcance * 0.15
	for k in range(0, tracos, 2):
		var inicio = giro + float(k) * passo
		lenco.draw_arc(centro, raio, inicio, inicio + passo * 0.8, 6, Color(lenco.cor_alcance, 0.85 * a), 3.0, true)

	# Anel que se expande ao aparecer
	if lenco.pulso_alcance < 1.0:
		var e = 1.0 - pow(1.0 - lenco.pulso_alcance, 3.0)
		lenco.draw_arc(centro, raio * e, 0.0, TAU, 96, Color(lenco.cor_alcance, (1.0 - lenco.pulso_alcance) * 0.6 * a), 2.5, true)

func _atualizar_repouso_firme(origem: Vector2, delta: float) -> void:

	var dir_costas = 1.0 if lenco._olhando_esquerda() else -1.0

	var vel_x: float = lenco.jogador.velocity.x if lenco.jogador else 0.0
	var vel_normalizada: float = clampf(absf(vel_x) / 320.0, 0.0, 1.0)
	lenco.vel_suave = lerpf(lenco.vel_suave, vel_normalizada, 4.0 * delta)

	# Parado mantém o balanço lento; andar e correr são mais contidos
	# (a curva ^1.5 deixa o andar bem suave e o correr só um pouco maior)
	var intensidade = pow(lenco.vel_suave, 1.5)
	var freq_vento = lerpf(2.2, 7.5, lenco.vel_suave)
	var amp_vento = lerpf(10.0, 19.0, intensidade)
	lenco.tempo_balanco += delta * freq_vento

	# Ângulo de caimento: 40° (parado, mais elevado) -> ~15° (andar) -> -10° (correr)
	var angulo_caimento = lerpf(deg_to_rad(40.0), deg_to_rad(-10.0), lenco.vel_suave)
	var dir_caimento = Vector2(dir_costas * cos(angulo_caimento), sin(angulo_caimento))

	# De frente: cada fita cai para o seu lado do pescoço. A da frente fica no lado em que já estava e a
	# de TRÁS é a que atravessa (por trás do corpo). Com 'frontal' = 0 as duas caem juntas, como sempre foi.
	var f = smoothstep(0.0, 1.0, lenco.frontal)
	var lado_tras = -dir_costas
	if lenco.inverter_lados_frente:
		lado_tras = -lado_tras
	var ang_frente = deg_to_rad(lenco.angulo_caimento_frente)
	var dir_tras = dir_caimento.lerp(Vector2(lado_tras * cos(ang_frente), sin(ang_frente)), f).normalized()
	var dir_frente = dir_caimento.lerp(Vector2(-lado_tras * cos(ang_frente), sin(ang_frente)), f).normalized()
	var perp_tras = Vector2(-dir_tras.y, dir_tras.x)
	var perp_frente = Vector2(-dir_frente.y, dir_frente.x)

	# Origem de cada fita: a mesma de lado; de frente, uma de cada lado do pescoço
	var separacao = Vector2(lado_tras * lenco.separacao_pescoco_frente * f, 0.0)
	var origem_tras = origem + lenco.offset_tras_atual + separacao
	var origem_frente = origem + lenco.offset_frente_atual - separacao
	lenco.pontos_tras[0] = origem_tras
	lenco.pontos_frente[0] = origem_frente

	# Arrasto vertical suavizado (pulo/queda): sobe -> lenço desce, cai -> lenço sobe
	var vel_y: float = lenco.jogador.velocity.y if lenco.jogador else 0.0
	lenco.vel_y_suave = lerpf(lenco.vel_y_suave, vel_y, 1.0 - exp(-7.0 * delta))
	var arrasto_v = clampf(-lenco.vel_y_suave * lenco.sensibilidade_arrasto_pulo, -45.0, 45.0)

	# Arrasto horizontal: o lenço fica "para trás" do movimento
	var arrasto_h = clampf(-vel_x * 0.05, -30.0, 30.0)

	# Logo após soltar Q/E o lenço volta devagar e vai ganhando agilidade até o normal
	lenco.tempo_retorno += delta
	var k_retorno = smoothstep(0.0, 1.0, clampf(lenco.tempo_retorno / maxf(lenco.duracao_retorno, 0.01), 0.0, 1.0))
	var agilidade = lerpf(0.3, 1.0, k_retorno)

	for i in range(1, lenco.pontos_por_fita):
		var t = float(i) / float(lenco.pontos_por_fita - 1)
		var dist_segmento = lenco.comprimento_maximo * t
		var fator_ponta = pow(t, 1.2)

		# Forma do movimento do código antigo, com a intensidade atual
		var ondas = lenco._ondas_repouso(t, amp_vento, fator_ponta)
		var onda_tras = ondas.x
		var onda_frente = ondas.y

		var offset_inercia = Vector2(arrasto_h * fator_ponta, arrasto_v * fator_ponta)
		var pos_base_tras = origem_tras + (dir_tras * dist_segmento) + offset_inercia
		var pos_base_frente = origem_frente + (dir_frente * dist_segmento) + offset_inercia

		var pos_alvo_tras = pos_base_tras + (perp_tras * onda_tras)
		var pos_alvo_frente = pos_base_frente + (perp_frente * onda_frente)

		# Base firme (30) -> ponta solta: mais frouxa parado (5) e mais ágil ao correr (11), como no código antigo
		var peso_lerp = lenco._peso_ponto(t, 30.0 * agilidade, (5.0 + 6.0 * lenco.vel_suave) * agilidade, delta)
		lenco.pontos_tras[i] = lenco.pontos_tras[i].lerp(pos_alvo_tras, peso_lerp)
		lenco.pontos_frente[i] = lenco.pontos_frente[i].lerp(pos_alvo_frente, peso_lerp)

func _caminho_circular_defesa(origem: Vector2, centro: Vector2, raio: float,
		inicio: float, extra: float, lado_saida: float) -> Array[Vector2]:
	var caminho: Array[Vector2] = []
	var entrada = centro + Vector2(cos(inicio) * lenco.frente_defesa, sin(inicio)) * raio
	# Trecho reto da gola até a borda, preservado até o fim da defesa.
	for i in range(25):
		caminho.append(origem.lerp(entrada, float(i) / 24.0))
	# Trás percorre o semicírculo superior; frente percorre o inferior.
	# O fim de cada arco encontra a saída do outro na altura da gola.
	var fim = (-PI - inicio) if lado_saida > 0.0 else (PI - inicio)
	fim -= extra
	for i in range(1, 97):
		var angulo = lerpf(inicio, fim, float(i) / 96.0)
		caminho.append(centro + Vector2(cos(angulo) * lenco.frente_defesa, sin(angulo)) * raio)
	return caminho

func _revelar_caminho_defesa(caminho: Array[Vector2], inicial: Array[Vector2],
		progresso: float, mistura: float) -> Array[Vector2]:
	# Avanço por distância: sem atalhos entre os pontos da circunferência.
	var distancias: Array[float] = [0.0]
	for i in range(1, caminho.size()):
		distancias.append(distancias[i - 1] + caminho[i - 1].distance_to(caminho[i]))
	var total = distancias[distancias.size() - 1]
	var resultado: Array[Vector2] = []
	var segmento = 1
	for i in range(129):
		var t = float(i) / 128.0
		var distancia = total * t * progresso
		while segmento < caminho.size() - 1 and distancias[segmento] < distancia:
			segmento += 1
		var comprimento = distancias[segmento] - distancias[segmento - 1]
		var fator = clampf((distancia - distancias[segmento - 1]) / maxf(comprimento, 0.0001), 0.0, 1.0)
		var ponto = caminho[segmento - 1].lerp(caminho[segmento], fator)
		if mistura > 0.0:
			var anterior = lenco._amostrar_caminho(inicial, t * float(inicial.size() - 1))
			ponto = ponto.lerp(anterior, mistura)
		resultado.append(ponto)
	return resultado

func _redesenhar_line2d() -> void:
	if not lenco.fita_tras or not lenco.fita_frente:
		return

	lenco.fita_tras.clear_points()
	lenco.fita_frente.clear_points()

	# Usa o mesmo caminho denso durante toda a defesa, sem trocar a curva no fechamento.
	if lenco.estado_atual == lenco.EstadoLenco.DEFESA:
		if not lenco.caminho_defesa_tras.is_empty() and not lenco.caminho_defesa_frente.is_empty():
			for pt in lenco.caminho_defesa_tras:
				lenco.fita_tras.add_point(lenco.fita_tras.to_local(pt + lenco.tremor_visual))
			for pt in lenco.caminho_defesa_frente:
				lenco.fita_frente.add_point(lenco.fita_frente.to_local(pt + lenco.tremor_visual))
			return

	for pt in lenco._suavizar_curva(lenco.pontos_tras):
		lenco.fita_tras.add_point(lenco.fita_tras.to_local(pt + lenco.tremor_visual))
	for pt in lenco._suavizar_curva(lenco.pontos_frente):
		lenco.fita_frente.add_point(lenco.fita_frente.to_local(pt + lenco.tremor_visual))

func _draw() -> void:
	lenco._desenhar_alcance()
	lenco._desenhar_origens_debug()
	lenco._desenhar_indicador_modo()

	if not lenco.textura_ponta: return

	if lenco.pontos_tras.size() >= lenco.pontos_por_fita:
		lenco._desenhar_ponta_no_ponto(lenco.pontos_tras[lenco.pontos_por_fita - 2], lenco.pontos_tras[lenco.pontos_por_fita - 1])

	if lenco.pontos_frente.size() >= lenco.pontos_por_fita:
		lenco._desenhar_ponta_no_ponto(lenco.pontos_frente[lenco.pontos_por_fita - 2], lenco.pontos_frente[lenco.pontos_por_fita - 1])

func _desenhar_indicador_modo() -> void:
	if not lenco.modo_distancia or lenco.pontos_tras.size() < lenco.pontos_por_fita:
		return
	var pulso = 0.6 + 0.25 * sin(Time.get_ticks_msec() * 0.008)
	var cor = lenco._cor_do_lenco().lerp(Color.WHITE, 0.5)
	for ponto in [lenco.pontos_tras[lenco.pontos_por_fita - 1], lenco.pontos_frente[lenco.pontos_por_fita - 1]]:
		var c = lenco.to_local(ponto)
		lenco.draw_circle(c, 12.0, Color(cor, 0.10 * pulso))
		lenco.draw_circle(c, 8.0, Color(cor, 0.20 * pulso))
		lenco.draw_circle(c, 4.0, Color(cor, 0.45 * pulso))

func _desenhar_origens_debug() -> void:
	if not lenco.mostrar_origens_debug or lenco.jogador == null or not lenco.jogador.has_method("em_modo_debug"):
		return
	if not lenco.jogador.em_modo_debug():
		return
	var centro = lenco.to_local(lenco.origem_anterior)
	lenco.draw_circle(centro, 3.0, Color(0.2, 0.9, 1.0))
	lenco.draw_circle(lenco.to_local(lenco.origem_anterior + lenco.offset_tras_atual), 2.0, Color(1.0, 0.3, 0.9))
	lenco.draw_circle(lenco.to_local(lenco.origem_anterior + lenco.offset_frente_atual), 2.0, Color(1.0, 0.9, 0.2))
	var anim = lenco.sprite_jogador as AnimatedSprite2D
	if anim:
		var texto = "%s  quadro %d  off=(%.0f, %.0f)" % [anim.animation, anim.frame, lenco.offset_gola_atual.x, lenco.offset_gola_atual.y]
		lenco.draw_string(ThemeDB.fallback_font, centro + Vector2(10.0, -6.0), texto, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, Color(1, 1, 1))

func _desenhar_ponta_no_ponto(ponto_anterior: Vector2, ponto_final: Vector2) -> void:
	var pos_local = lenco.to_local(ponto_final)
	var direcao = (ponto_final - ponto_anterior).normalized()
	var angulo = direcao.angle()

	var rect = Rect2(-lenco.tamanho_ponta / 2.0, lenco.tamanho_ponta)

	lenco.draw_set_transform(pos_local, angulo)
	lenco.draw_texture_rect(lenco.textura_ponta, rect, false)
	lenco.draw_set_transform(Vector2.ZERO, 0.0)

func _centro_corpo() -> Vector2:
	return lenco.jogador.colisor_corpo.global_position

func _cor_do_lenco() -> Color:
	if lenco.fita_tras:
		var g = lenco.fita_tras.gradient
		if g != null and g.get_point_count() > 0:
			return g.get_color(g.get_point_count() - 1)
		return lenco.fita_tras.default_color
	return Color(0.6, 0.6, 1.0)
