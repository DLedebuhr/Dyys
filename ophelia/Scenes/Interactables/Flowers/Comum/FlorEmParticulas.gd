extends Node2D

static var _amostras: Dictionary = {}

var _pontos: PackedVector2Array = PackedVector2Array()
var _cores: PackedColorArray = PackedColorArray()
var _velocidades: PackedVector2Array = PackedVector2Array()
var _tamanhos: PackedFloat32Array = PackedFloat32Array()
var _tempo: float = 0.0
var _tempo_forma: float = 0.16
var _duracao: float = 0.9
var _resistencia: float = 1.8

# Capturar a flor na posição atual
# ---------------------
# Usa somente os pixels visíveis da ponta; o triângulo pertence a outro nó e fica no galho.
func iniciar(sprite: Sprite2D, tempo_forma: float, duracao: float, velocidade: float, limite: int, base_preservada: PackedVector2Array = PackedVector2Array()) -> void:

	_tempo_forma = tempo_forma
	_duracao = duracao
	top_level = true
	global_transform = Transform2D(0.0, sprite.global_position)
	z_as_relative = false
	z_index = 0
	var dados: Dictionary = _obter_amostras(sprite.texture, limite, base_preservada)

	if dados.is_empty():

		queue_free()
		return

	var pixels: PackedVector2Array = dados["pontos"]
	var cores: PackedColorArray = dados["cores"]
	var passo: float = float(dados["passo"])
	var transformacao: Transform2D = sprite.global_transform
	var tamanho: Vector2 = sprite.texture.get_size()
	var offset: Vector2 = sprite.offset - (tamanho * 0.5 if sprite.centered else Vector2.ZERO)
	var centro: Vector2 = Vector2.ZERO

	for ponto in pixels:

		var local: Vector2 = ponto

		if sprite.flip_h:

			local.x = tamanho.x - local.x

		if sprite.flip_v:

			local.y = tamanho.y - local.y

		var posicao: Vector2 = transformacao * (offset + local) - global_position
		_pontos.append(posicao)
		centro += posicao

	centro /= maxf(_pontos.size(), 1)
	var escala: float = maxf(transformacao.x.length(), transformacao.y.length())
	var cor_no: Color = sprite.modulate * sprite.self_modulate

	for i in range(_pontos.size()):

		var radial: Vector2 = (_pontos[i] - centro).normalized()

		if radial == Vector2.ZERO:

			radial = Vector2.RIGHT.rotated(randf() * TAU)

		_velocidades.append(radial.rotated(randf_range(-0.45, 0.45)) * velocidade * randf_range(0.4, 1.0))
		_cores.append(cores[i] * cor_no)
		_tamanhos.append(maxf(passo * escala, 0.45))

	queue_redraw()

# Ler os pixels da textura uma vez
# ---------------------
# Reutiliza a amostragem das três variações e limita o número de partículas.
func _obter_amostras(textura: Texture2D, limite: int, base_preservada: PackedVector2Array) -> Dictionary:

	if textura == null:

		return {}

	var chave: String = "%d:%d:%d" % [textura.get_instance_id(), limite, hash(base_preservada)]

	if _amostras.has(chave):

		return _amostras[chave]

	var imagem: Image = textura.get_image()

	if imagem == null or imagem.is_empty():

		return {}

	if imagem.is_compressed() and imagem.decompress() != OK:

		return {}

	var passo: int = maxi(1, int(ceilf(float(maxi(imagem.get_width(), imagem.get_height())) / 180.0)))
	var pontos: PackedVector2Array
	var cores: PackedColorArray

	while true:

		pontos = PackedVector2Array()
		cores = PackedColorArray()

		for y in range(0, imagem.get_height(), passo):

			for x in range(0, imagem.get_width(), passo):

				var cor: Color = imagem.get_pixel(x, y)

				if cor.a > 0.15 and (base_preservada.is_empty() or not Geometry2D.is_point_in_polygon(Vector2(x, y) + Vector2.ONE * 0.5, base_preservada)):

					pontos.append(Vector2(x, y) + Vector2.ONE * 0.5)
					cores.append(cor)

		if pontos.size() <= limite:

			break

		passo = maxi(passo + 1, int(ceilf(passo * sqrt(float(pontos.size()) / limite))))

	var dados: Dictionary = {"pontos": pontos, "cores": cores, "passo": passo}
	_amostras[chave] = dados
	return dados

# Contar o tempo do efeito
# ---------------------
# Segura primeiro a silhueta e depois libera a dispersão até desaparecer.
func _process(delta: float) -> void:

	_tempo += delta

	if _tempo >= _tempo_forma + _duracao:

		queue_free()
		return

	queue_redraw()

# Desenhar a flor se desfazendo
# ---------------------
# As partículas começam nas cores e posições da imagem e depois se espalham e encolhem.
func _draw() -> void:

	var dispersao: float = maxf(0.0, _tempo - _tempo_forma)
	var progresso: float = clampf(dispersao / maxf(_duracao, 0.01), 0.0, 1.0)
	var deslocamento: float = (1.0 - exp(-_resistencia * dispersao)) / _resistencia
	var alfa: float = 1.0 - smoothstep(0.35, 1.0, progresso)

	for i in range(_pontos.size()):

		var posicao: Vector2 = _pontos[i] + _velocidades[i] * deslocamento + Vector2(0, 6.0 * dispersao * dispersao)
		var tamanho: float = _tamanhos[i] * lerpf(1.0, 0.12, progresso)
		var cor: Color = _cores[i]
		cor.a *= alfa
		draw_rect(Rect2(posicao - Vector2.ONE * tamanho * 0.5, Vector2.ONE * tamanho), cor)
