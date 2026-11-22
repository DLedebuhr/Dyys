extends Node2D
## Materialização com amostragem dos pixels originais, na silhueta e na cor da arte.
## A versão com chapéu de Ophelia só aparece após o sinal concluido.
signal concluido()

var _pontos: PackedVector2Array = PackedVector2Array()
var _cores: PackedColorArray = PackedColorArray()
var _velocidades: PackedVector2Array = PackedVector2Array()
var _tamanhos: PackedFloat32Array = PackedFloat32Array()
var _duracao: float = 1.4
var _tempo: float = 0.0
var _formando: bool = false
var _espera_forma: float = 0.10
var _resistencia: float = 1.8
var _seguir: Node2D
var _silhueta: Sprite2D
var _concluiu: bool = false
# Amostras da miniatura no início: não criamos um sprite intermediário.
var _pontos_icone: PackedVector2Array = PackedVector2Array()
var _cores_icone: PackedColorArray = PackedColorArray()
var _deslocamento_inicial: Vector2 = Vector2.ZERO
var _escala_inicial_formacao: float = 0.3
var _escala_final: float = 1.0

func iniciar(textura: Texture2D, posicao_global: Vector2, escala: float, espelhar: bool, formando: bool, duracao: float, velocidade: float, limite: int, seguir: Node2D = null, textura_icone: Texture2D = null, posicao_icone_global: Vector2 = Vector2.ZERO, escala_icone: float = 0.25, espelhar_icone: bool = false) -> void:
	top_level = true
	global_position = posicao_global
	_seguir = seguir if formando else null
	_formando = formando
	_escala_final = escala
	_concluiu = false
	_deslocamento_inicial = posicao_icone_global - posicao_global if formando else Vector2.ZERO
	_escala_inicial_formacao = clampf(escala_icone / maxf(escala, 0.001), 0.05, 1.0)
	_pontos_icone.clear()
	_cores_icone.clear()
	var imagem_icone: Image
	var candidatos_icone: Array[Vector2i] = []
	if formando and textura_icone != null:
		imagem_icone = textura_icone.get_image()
		if imagem_icone != null and imagem_icone.is_compressed() and imagem_icone.decompress() != OK:
			imagem_icone = null
		if imagem_icone != null and not imagem_icone.is_empty():
			var passo_icone: int = maxi(1, int(ceilf(float(maxi(imagem_icone.get_width(), imagem_icone.get_height())) / 140.0)))
			for yi in range(0, imagem_icone.get_height(), passo_icone):
				for xi in range(0, imagem_icone.get_width(), passo_icone):
					if imagem_icone.get_pixel(xi, yi).a > 0.15:
						candidatos_icone.append(Vector2i(xi, yi))
	_duracao = maxf(duracao, 0.10)
	_tempo = 0.0
	_pontos.clear()
	_cores.clear()
	_velocidades.clear()
	_tamanhos.clear()
	if is_instance_valid(_silhueta):
		_silhueta.queue_free()
	_silhueta = Sprite2D.new()
	_silhueta.texture = textura
	_silhueta.scale = Vector2.ONE * (escala * _escala_inicial_formacao if formando else escala)
	_silhueta.flip_h = espelhar
	_silhueta.modulate.a = 0.0
	add_child(_silhueta)
	if textura == null:
		_finalizar()
		return
	var imagem: Image = textura.get_image()
	if imagem == null or imagem.is_empty():
		_finalizar()
		return
	if imagem.is_compressed() and imagem.decompress() != OK:
		_finalizar()
		return
	var largura: int = imagem.get_width()
	var altura: int = imagem.get_height()
	# A amostragem cobre a silhueta inteira, e não somente uma parte do chapéu.
	var passo: int = maxi(1, int(ceilf(float(maxi(largura, altura)) / 150.0)))
	var candidatos: Array[Vector2i] = []
	for y in range(0, altura, passo):
		for x in range(0, largura, passo):
			if imagem.get_pixel(x, y).a > 0.15:
				candidatos.append(Vector2i(x, y))
	candidatos.shuffle()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var centro := Vector2.ZERO
	var quantidade: int = mini(candidatos.size(), maxi(limite, 1))
	for i in range(quantidade):
		var pixel: Vector2i = candidatos[i]
		var ponto := (Vector2(pixel) + Vector2.ONE * 0.5 - Vector2(largura, altura) * 0.5) * escala
		if espelhar:
			ponto.x = -ponto.x
		_pontos.append(ponto)
		_cores.append(imagem.get_pixelv(pixel))
		# No início, cada partícula ocupa um pixel da miniatura real.
		# O formato acompanha a orientação no instante em que o marcador chegou.
		if not candidatos_icone.is_empty() and imagem_icone != null:
			var pixel_icone: Vector2i = candidatos_icone[rng.randi_range(0, candidatos_icone.size() - 1)]
			var pos_icone := (Vector2(pixel_icone) + Vector2.ONE * 0.5 - Vector2(imagem_icone.get_size()) * 0.5) * escala_icone
			if espelhar_icone:
				pos_icone.x = -pos_icone.x
			_pontos_icone.append(_deslocamento_inicial + pos_icone)
			_cores_icone.append(imagem_icone.get_pixelv(pixel_icone))
		else:
			_pontos_icone.append(_deslocamento_inicial + ponto * _escala_inicial_formacao)
			_cores_icone.append(imagem.get_pixelv(pixel))
		centro += ponto
	centro /= maxf(float(_pontos.size()), 1.0)
	for i in range(_pontos.size()):
		var radial := (_pontos[i] - centro).normalized()
		if radial.is_zero_approx():
			radial = Vector2.RIGHT.rotated(rng.randf() * TAU)
		_velocidades.append(radial.rotated(rng.randf_range(-0.45, 0.45)) * velocidade * rng.randf_range(0.4, 1.0))
		_tamanhos.append(maxf(float(passo) * escala, 0.75))
	queue_redraw()

func _process(delta: float) -> void:
	if is_instance_valid(_seguir):
		global_position = _seguir.global_position
	_tempo = minf(_tempo + delta, _duracao + (_espera_forma if not _formando else 0.0))
	if _formando:
		var p: float = smoothstep(0.0, 1.0, clampf(_tempo / _duracao, 0.0, 1.0))
		var escala_transicao: float = lerpf(_escala_inicial_formacao, 1.0, p)
		if is_instance_valid(_silhueta):
			_silhueta.position = _deslocamento_inicial.lerp(Vector2.ZERO, p)
			_silhueta.scale = Vector2.ONE * _escala_final * escala_transicao
			_silhueta.modulate.a = smoothstep(0.58, 0.96, p)
	queue_redraw()
	if _tempo >= _duracao + (_espera_forma if not _formando else 0.0):
		# O sprite real só aparece quando todas as partículas já formaram o desenho.
		_finalizar()

func _finalizar() -> void:
	if _concluiu:
		return
	_concluiu = true
	concluido.emit()
	queue_free()

func _draw() -> void:
	var decorrido: float = _tempo if _formando else maxf(0.0, _tempo - _espera_forma)
	var progresso: float = clampf(decorrido / _duracao, 0.0, 1.0)
	var dispersao: float = 1.0 - progresso if _formando else progresso
	var deslocamento: float = (1.0 - exp(-_resistencia * _duracao * dispersao)) / _resistencia
	# Materialização visível por toda a duração, completando os detalhes até o fim.
	var alfa: float = smoothstep(0.0, 0.30, progresso) if _formando else 1.0 - smoothstep(0.35, 1.0, progresso)
	var forma: float = smoothstep(0.0, 1.0, progresso) if _formando else 1.0
	var fator_escala: float = lerpf(_escala_inicial_formacao, 1.0, forma) if _formando else 1.0
	var centro: Vector2 = _deslocamento_inicial.lerp(Vector2.ZERO, forma) if _formando else Vector2.ZERO
	for i in range(_pontos.size()):
		var posicao: Vector2
		var cor: Color = _cores[i]
		if _formando and i < _pontos_icone.size():
			# Transição geométrica: miniatura -> formato real, sem imagem extra.
			posicao = _pontos_icone[i].lerp(_pontos[i], forma)
			posicao += _velocidades[i] * deslocamento * fator_escala
			cor = _cores_icone[i].lerp(_cores[i], forma)
		else:
			posicao = centro + _pontos[i] * fator_escala + _velocidades[i] * deslocamento * fator_escala + Vector2(0, 6.0 * _duracao * _duracao * dispersao * dispersao)
		var tamanho: float = _tamanhos[i] * fator_escala * lerpf(1.0, 0.14, dispersao)
		# Partículas presentes desde o início: nada aparece entre o ícone e elas.
		cor.a *= 1.0 if _formando else alfa
		draw_rect(Rect2(posicao - Vector2.ONE * tamanho * 0.5, Vector2.ONE * tamanho), cor)
