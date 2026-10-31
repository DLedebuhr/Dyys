extends Control
## Anima a textura base de cada TextureProgressBar. Não usa SpriteFrames.
@export var vitalidade: Node
@export var vidas: Array[TextureProgressBar] = []
@export_group("Recuperação do coração")
@export_range(0.05, 1.0, 0.05) var escala_inicial_cura: float = 0.25
@export_range(0.1, 2.0, 0.05) var duracao_crescer: float = 0.65
@export_range(1.0, 1.3, 0.01) var escala_pulsada: float = 1.08
@export_range(0.03, 0.5, 0.01) var duracao_pulsada_subir: float = 0.12
@export_range(0.03, 0.5, 0.01) var duracao_pulsada_voltar: float = 0.18
@export_range(0.1, 1.0, 0.05) var tempo_relativo_fruta: float = 0.45
@export_group("Partículas brancas da barra")
@export_range(0, 600, 1) var quantidade_explosao: int = 140
@export_range(0, 30, 1) var quantidade_cintilo: int = 9
@export_range(0.2, 2.0, 0.05) var duracao_particulas: float = 1.0
@export_range(0.1, 2.0, 0.05) var intensidade_particulas: float = 0.7

@export_group("Formato e visibilidade das partículas")
@export var textura_formato_particulas: Texture2D # Vazio = usa a imagem Progress de cada vida.
@export_range(0.01, 1.0, 0.01) var limite_alpha: float = 0.12
@export_range(0.5, 4.0, 0.05) var tamanho_particula_px: float = 1.2
@export_range(5.0, 150.0, 1.0) var velocidade_explosao_px: float = 35.0
@export_range(0.0, 0.3, 0.01) var tempo_manter_formato: float = 0.08
var _amostras_texturas: Dictionary = {}
var _avisos_texturas: Dictionary = {}

var _valores: Array[float] = []
var _escalas: Array[Vector2] = []
var _pivos: Array[Vector2] = []
var _cores: Array[Color] = []
var _tweens: Array[Tween] = []
var _particulas: Array[Dictionary] = []
var _inicializada: bool = false
@onready var _desenho_particulas: Node2D = get_node_or_null("Particulas") as Node2D

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = false
	if _desenho_particulas == null:
		push_warning("BarraVida: adicione um filho Node2D chamado Particulas.")
	else:
		_desenho_particulas.z_index = 10
		_desenho_particulas.draw.connect(_desenhar_particulas)
	for vida in vidas:
		_valores.append(0.0)
		_escalas.append(vida.scale if is_instance_valid(vida) else Vector2.ONE)
		_pivos.append(vida.pivot_offset if is_instance_valid(vida) else Vector2.ZERO)
		_cores.append(vida.self_modulate if is_instance_valid(vida) else Color.WHITE)
		_tweens.append(null)
		if is_instance_valid(vida):
			vida.min_value = 0.0
			vida.max_value = 1.0
			vida.step = 0.0
			vida.clip_contents = false
			vida.mouse_filter = Control.MOUSE_FILTER_IGNORE
			# Compatibilidade com a montagem anterior; os sprites não participam mais.
			for filho in vida.get_children():
				if filho is AnimatedSprite2D:
					filho.stop()
					filho.hide()
	call_deferred("_conectar")

func _conectar() -> void:
	if not is_instance_valid(vitalidade):
		var jogador: Node = get_tree().get_first_node_in_group("jogador")
		if jogador != null:
			vitalidade = jogador.get_node_or_null("Vitalidade")
	if not is_instance_valid(vitalidade) or not vitalidade.has_signal("vida_alterada"):
		push_warning("BarraVida: arraste Vitalidade para o Inspetor.")
		return
	vitalidade.connect("vida_alterada", _atualizar)
	_atualizar(float(vitalidade.get("vida_atual")), int(vitalidade.get("vida_maxima")))

func _atualizar(atual: float, maxima: int) -> void:
	var fruta: bool = vitalidade.has_method("esta_consumindo_fruta") and bool(vitalidade.call("esta_consumindo_fruta"))
	for i in range(vidas.size()):
		var vida: TextureProgressBar = vidas[i]
		if not is_instance_valid(vida):
			continue
		var antes: float = _valores[i]
		var depois: float = clampf(atual - float(i), 0.0, 1.0)
		vida.visible = i < maxima
		vida.value = depois
		_valores[i] = depois
		if not vida.visible:
			_cancelar(i)
		elif not _inicializada:
			_cancelar(i)
		elif not is_equal_approx(antes, depois):
			_cancelar(i)
			if depois < antes:
				_emitir_particulas(i, false, antes - depois, antes, depois)
			else:
				_recuperar(i, fruta)
	_inicializada = true

func _recuperar(indice: int, fruta: bool) -> void:
	var vida: TextureProgressBar = vidas[indice]
	var fator: float = tempo_relativo_fruta if fruta else 1.0
	# Recalcula o centro para respeitar o tamanho atual do indicador.
	vida.pivot_offset = vida.size * 0.5
	vida.scale = _escalas[indice] * escala_inicial_cura
	var cor: Color = _cores[indice]
	cor.a = 0.0
	vida.self_modulate = cor
	var tween: Tween = create_tween().set_parallel(true)
	_tweens[indice] = tween
	tween.tween_property(vida, "scale", _escalas[indice], maxf(0.01, duracao_crescer * fator)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(vida, "self_modulate:a", _cores[indice].a, maxf(0.01, duracao_crescer * fator)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(vida, "scale", _escalas[indice] * escala_pulsada, maxf(0.01, duracao_pulsada_subir * fator)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.chain().tween_callback(_emitir_particulas.bind(indice, true, 1.0))
	tween.chain().tween_property(vida, "scale", _escalas[indice], maxf(0.01, duracao_pulsada_voltar * fator)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.finished.connect(_ao_terminar.bind(indice, tween))

func _cancelar(indice: int) -> void:
	if _tweens[indice] != null and _tweens[indice].is_valid():
		_tweens[indice].kill()
	_tweens[indice] = null
	for i in range(_particulas.size() - 1, -1, -1):
		if int(_particulas[i]["indice"]) == indice and float(_particulas[i]["atraso"]) > 0.0:
			_particulas.remove_at(i)
	if is_instance_valid(vidas[indice]):
		vidas[indice].scale = _escalas[indice]
		vidas[indice].pivot_offset = _pivos[indice]
		vidas[indice].self_modulate = _cores[indice]

func _ao_terminar(indice: int, tween: Tween) -> void:
	if _tweens[indice] == tween:
		# Não cancela os cintilos já agendados para desaparecer suavemente.
		_tweens[indice] = null
		if is_instance_valid(vidas[indice]):
			vidas[indice].scale = _escalas[indice]
			vidas[indice].pivot_offset = _pivos[indice]
			vidas[indice].self_modulate = _cores[indice]

func _emitir_particulas(indice: int, cintilo: bool, proporcao: float, antes: float = 1.0, depois: float = 0.0) -> void:
	if not is_instance_valid(vidas[indice]) or not vidas[indice].visible:
		return
	var vida: TextureProgressBar = vidas[indice]
	var textura: Texture2D = textura_formato_particulas if textura_formato_particulas != null else vida.texture_progress
	if textura == null:
		_avisar_uma_vez(indice, "Coloque o coração em Textures > Progress ou em Textura Formato Particulas.")
		return
	var amostras: PackedVector3Array = _obter_amostras(textura)
	if amostras.is_empty():
		_avisar_uma_vez(indice, "Não foi possível ler pixels visíveis da textura do coração. Use uma PNG com transparência e Compress Mode Lossless.")
		return
	var retangulo: Rect2 = _retangulo_textura(vida, textura)
	var transformacao: Transform2D = get_global_transform().affine_inverse() * vida.get_global_transform()
	var centro: Vector2 = transformacao * retangulo.get_center()
	var elegiveis: PackedVector3Array = PackedVector3Array()
	for ponto in amostras:
		var local: Vector2 = _ponto_na_textura(vida, Vector2(ponto.x, ponto.y), textura)
		var uv_desenho: Vector2 = (local - retangulo.position) / retangulo.size.max(Vector2.ONE * 0.001)
		if cintilo or _parte_perdida(vida.fill_mode, uv_desenho, antes, depois):
			elegiveis.append(ponto)
	if elegiveis.is_empty():
		return
	var escala_tela: float = _escala_da_barra_na_tela()
	var quantidade: int = quantidade_cintilo if cintilo else int(ceilf(float(quantidade_explosao) * proporcao))
	for i in range(quantidade):
		# Amostragem distribuída pelo desenho todo, não em um círculo aleatório.
		var indice_ponto: int = mini(int((float(i) + 0.5) * float(elegiveis.size()) / float(maxi(quantidade, 1))), elegiveis.size() - 1)
		var ponto: Vector3 = elegiveis[indice_ponto]
		var uv: Vector2 = Vector2(ponto.x, ponto.y)
		var posicao: Vector2 = transformacao * _ponto_na_textura(vida, uv, textura)
		var direcao: Vector2 = (posicao - centro).normalized()
		if direcao.is_zero_approx():
			direcao = Vector2.RIGHT.rotated(randf() * TAU)
		var velocidade: Vector2
		if cintilo:
			posicao += direcao * 2.2 / escala_tela
			velocidade = direcao * randf_range(5.0, 12.0) / escala_tela
		else:
			velocidade = direcao.rotated(randf_range(-0.15, 0.15)) * velocidade_explosao_px * randf_range(0.65, 1.15) / escala_tela
		var duracao: float = maxf(0.1, duracao_particulas * randf_range(0.8, 1.15))
		_particulas.append({"indice": indice, "p": posicao, "v": velocidade, "idade": 0.0, "duracao": duracao, "atraso": randf_range(0.0, 0.18) if cintilo else 0.0, "r": tamanho_particula_px * randf_range(0.85, 1.15) / escala_tela, "cintilo": cintilo, "alpha": ponto.z})
	if is_instance_valid(_desenho_particulas):
		_desenho_particulas.queue_redraw()

func _obter_amostras(textura: Texture2D) -> PackedVector3Array:
	var chave: int = textura.get_instance_id()
	if _amostras_texturas.has(chave):
		return _amostras_texturas[chave]
	var pontos: PackedVector3Array = PackedVector3Array()
	var imagem: Image = textura.get_image()
	if imagem == null or imagem.is_empty():
		return pontos
	if imagem.is_compressed() and imagem.decompress() != OK:
		return pontos
	var largura: int = imagem.get_width()
	var altura: int = imagem.get_height()
	var passo: int = maxi(1, int(ceilf(float(maxi(largura, altura)) / 512.0)))
	for y in range(0, altura, passo):
		for x in range(0, largura, passo):
			var alpha: float = imagem.get_pixel(x, y).a
			if alpha > limite_alpha:
				pontos.append(Vector3((float(x) + 0.5) / float(largura), (float(y) + 0.5) / float(altura), alpha))
	_amostras_texturas[chave] = pontos
	return pontos

func _retangulo_textura(vida: TextureProgressBar, formato: Texture2D) -> Rect2:
	if vida.nine_patch_stretch:
		return Rect2(Vector2.ZERO, vida.size)
	var textura: Texture2D = vida.texture_progress if vida.texture_progress != null else formato
	return Rect2(vida.texture_progress_offset, textura.get_size())

func _ponto_na_textura(vida: TextureProgressBar, uv: Vector2, formato: Texture2D) -> Vector2:
	var textura: Texture2D = vida.texture_progress if vida.texture_progress != null else formato
	var tamanho: Vector2 = textura.get_size()
	if not vida.nine_patch_stretch:
		# Sem Nine Patch, o Godot desenha a textura no tamanho original, não no size do nó.
		return vida.texture_progress_offset + uv * tamanho
	return Vector2(
		_mapear_eixo(uv.x * tamanho.x, tamanho.x, vida.size.x, float(vida.stretch_margin_left), float(vida.stretch_margin_right)),
		_mapear_eixo(uv.y * tamanho.y, tamanho.y, vida.size.y, float(vida.stretch_margin_top), float(vida.stretch_margin_bottom))
	)

func _mapear_eixo(ponto: float, origem: float, destino: float, margem_inicio: float, margem_fim: float) -> float:
	if margem_inicio + margem_fim <= 0.0:
		return ponto / maxf(origem, 0.001) * destino
	var inicio_origem: float = minf(margem_inicio, origem)
	var fim_origem: float = minf(margem_fim, maxf(0.0, origem - inicio_origem))
	var fator: float = minf(1.0, destino / maxf(inicio_origem + fim_origem, 0.001))
	var inicio_destino: float = inicio_origem * fator
	var fim_destino: float = fim_origem * fator
	if ponto < inicio_origem:
		return ponto / maxf(inicio_origem, 0.001) * inicio_destino
	if ponto > origem - fim_origem:
		return destino - (origem - ponto) / maxf(fim_origem, 0.001) * fim_destino
	return inicio_destino + (ponto - inicio_origem) / maxf(origem - inicio_origem - fim_origem, 0.001) * maxf(0.0, destino - inicio_destino - fim_destino)

func _parte_perdida(modo: int, uv: Vector2, antes: float, depois: float) -> bool:
	var fracao: float = uv.x
	match modo:
		TextureProgressBar.FILL_RIGHT_TO_LEFT:
			fracao = 1.0 - uv.x
		TextureProgressBar.FILL_TOP_TO_BOTTOM:
			fracao = uv.y
		TextureProgressBar.FILL_BOTTOM_TO_TOP:
			fracao = 1.0 - uv.y
		TextureProgressBar.FILL_BILINEAR_LEFT_AND_RIGHT:
			fracao = absf(uv.x - 0.5) * 2.0
		TextureProgressBar.FILL_BILINEAR_TOP_AND_BOTTOM:
			fracao = absf(uv.y - 0.5) * 2.0
		TextureProgressBar.FILL_CLOCKWISE, TextureProgressBar.FILL_COUNTER_CLOCKWISE, TextureProgressBar.FILL_CLOCKWISE_AND_COUNTER_CLOCKWISE:
			return true # As vidas usam preenchimento linear; radial dispersa o desenho inteiro.
	return fracao >= depois and fracao <= antes

func _escala_da_barra_na_tela() -> float:
	var escala: Vector2 = get_global_transform_with_canvas().get_scale().abs()
	return maxf(maxf(escala.x, escala.y), 0.001)

func _avisar_uma_vez(indice: int, texto: String) -> void:
	if not _avisos_texturas.has(indice):
		_avisos_texturas[indice] = true
		push_warning("BarraVida / %s: %s" % [vidas[indice].name, texto])

func _process(delta: float) -> void:
	for i in range(_particulas.size() - 1, -1, -1):
		var p: Dictionary = _particulas[i]
		if float(p["atraso"]) > 0.0:
			p["atraso"] -= delta
			continue
		var idade_anterior: float = float(p["idade"])
		p["idade"] += delta
		var espera: float = 0.0 if bool(p["cintilo"]) else tempo_manter_formato
		var movimento_delta: float = maxf(0.0, float(p["idade"]) - espera) - maxf(0.0, idade_anterior - espera)
		p["p"] += p["v"] * movimento_delta
		p["v"] *= exp(-1.2 * movimento_delta)
		if float(p["idade"]) >= float(p["duracao"]):
			_particulas.remove_at(i)
	if is_instance_valid(_desenho_particulas):
		_desenho_particulas.queue_redraw()

func _desenhar_particulas() -> void:
	_desenho_particulas.draw_set_transform_matrix(_desenho_particulas.get_global_transform().affine_inverse() * get_global_transform())
	for p in _particulas:
		if float(p["atraso"]) > 0.0:
			continue
		var t: float = clampf(float(p["idade"]) / float(p["duracao"]), 0.0, 1.0)
		var entrada: float = smoothstep(0.0, 0.12, t) if bool(p["cintilo"]) else 1.0
		var alfa: float = entrada * (1.0 - smoothstep(0.2, 1.0, t)) * intensidade_particulas * float(p["alpha"])
		var posicao: Vector2 = p["p"]
		var raio: float = float(p["r"]) * (1.0 - t * 0.35)
		_desenho_particulas.draw_circle(posicao, raio * 2.2, Color(1, 1, 1, alfa * 0.07), true, -1.0, true)
		if bool(p["cintilo"]):
			var ponta: float = raio * (1.5 + sin(t * PI) * 1.5)
			_desenho_particulas.draw_line(posicao - Vector2(ponta, 0), posicao + Vector2(ponta, 0), Color(1, 1, 1, alfa), maxf(0.6 / _escala_da_barra_na_tela(), raio * 0.55), true)
			_desenho_particulas.draw_line(posicao - Vector2(0, ponta), posicao + Vector2(0, ponta), Color(1, 1, 1, alfa), maxf(0.6 / _escala_da_barra_na_tela(), raio * 0.55), true)
		else:
			_desenho_particulas.draw_circle(posicao, raio, Color(1, 1, 1, alfa), true, -1.0, true)
