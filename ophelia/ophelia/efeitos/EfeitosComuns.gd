class_name OpheliaEfeitosComuns
extends RefCounted
## Ajustes compartilhados de brilho, material e partículas: uma fonte para todo o pacote.
static var estilo: Resource = preload("EstiloParticulas.tres")
static var _cintilo: Texture2D
static var _texturas: Dictionary = {}
static var _material: CanvasItemMaterial
static var _encolher: Curve

# Textura radial
# ---------------------
# Retorna textura radial.
static func textura_radial(tamanho: int = 16, cor: Color = Color.WHITE) -> GradientTexture2D:

	var chave: String = "%d:%s" % [tamanho, cor.to_html()]

	if not _texturas.has(chave):

		var gradiente := Gradient.new()
		gradiente.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
		gradiente.colors = PackedColorArray([Color(cor, 1.0), Color(cor, 0.55), Color(cor, 0.0)])
		var textura := GradientTexture2D.new()
		textura.gradient = gradiente
		textura.fill = GradientTexture2D.FILL_RADIAL
		textura.fill_from = Vector2(0.5, 0.5)
		textura.fill_to = Vector2(1.0, 0.5)
		textura.width = tamanho
		textura.height = tamanho
		_texturas[chave] = textura

	return _texturas[chave]

# Material aditivo
# ---------------------
# Retorna material aditivo.
static func material_aditivo() -> CanvasItemMaterial:

	if _material == null:

		_material = CanvasItemMaterial.new()
		_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

	return _material

# Curva encolher
# ---------------------
# Retorna curva encolher.
static func curva_encolher() -> Curve:

	if _encolher == null:

		_encolher = Curve.new()
		var tamanho: Vector2 = textura_cintilo().get_size()
		_encolher.add_point(Vector2(0.0, 16.0 / maxf(maxf(tamanho.x, tamanho.y), 1.0)))
		_encolher.add_point(Vector2(1.0, 0.0))

	return _encolher

# Padronizar o emissor
# ---------------------
# Aplica a textura, o material e o desaparecimento compartilhados.
static func configurar_emissor(emissor: CPUParticles2D, _tamanho_textura: int = 16) -> void:

	emissor.texture = textura_cintilo()
	emissor.color = cor_particula()
	emissor.color_ramp = gradiente_cintilo()
	emissor.material = material_aditivo()
	emissor.local_coords = false
	emissor.emitting = false
	emissor.scale_amount_curve = curva_encolher()

# Cor particula
# ---------------------
# Retorna cor particula.
static func cor_particula() -> Color:

	return estilo.get("cor")

# Textura cintilo
# ---------------------
# Retorna textura cintilo.
static func textura_cintilo() -> Texture2D:

	var personalizada: Texture2D = estilo.get("textura")

	if personalizada != null:

		return personalizada

	if _cintilo == null:

		var imagem := Image.create(16, 16, false, Image.FORMAT_RGBA8)

		for y in range(16):

			for x in range(16):

				var q := (Vector2(x, y) + Vector2.ONE * 0.5 - Vector2(8, 8)) / 8.0
				var horizontal: float = exp(-q.y * q.y * 170.0) * pow(maxf(0.0, 1.0 - absf(q.x)), 2.0)
				var vertical: float = exp(-q.x * q.x * 170.0) * pow(maxf(0.0, 1.0 - absf(q.y)), 2.0)
				var halo: float = exp(-q.length_squared() * 16.0) * 0.14
				imagem.set_pixel(x, y, Color(1, 1, 1, clampf(maxf(horizontal, vertical) + halo, 0, 1)))

		_cintilo = ImageTexture.create_from_image(imagem)

	return _cintilo

# Gradiente cintilo
# ---------------------
# Retorna gradiente cintilo.
static func gradiente_cintilo() -> Gradient:

	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0, 0.12, 0.32, 0.5, 0.68, 1])
	g.colors = PackedColorArray([Color(1,1,1,0.15), Color.WHITE, Color(1,1,1,0.45), Color(1,1,1,0.85), Color(1,1,1,0.4), Color(1,1,1,0)])
	return g

# Desenhar cintilo
# ---------------------
# Desenha cintilo.
static func desenhar_cintilo(alvo: CanvasItem, posicao: Vector2, tamanho: float, cor: Color) -> void:

	alvo.draw_texture_rect(textura_cintilo(), Rect2(posicao - Vector2.ONE * tamanho * 0.5, Vector2.ONE * tamanho), false, cor)
