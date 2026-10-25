class_name OpheliaEfeitosComuns
extends RefCounted
## Ajustes compartilhados de brilho, material e partículas: uma fonte para todo o pacote.
static var _texturas: Dictionary = {}
static var _material: CanvasItemMaterial
static var _encolher: Curve

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

static func material_aditivo() -> CanvasItemMaterial:
	if _material == null:
		_material = CanvasItemMaterial.new()
		_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return _material

static func curva_encolher() -> Curve:
	if _encolher == null:
		_encolher = Curve.new()
		_encolher.add_point(Vector2(0.0, 1.0))
		_encolher.add_point(Vector2(1.0, 0.0))
	return _encolher

static func configurar_emissor(emissor: CPUParticles2D, tamanho_textura: int = 16) -> void:
	emissor.texture = textura_radial(tamanho_textura)
	emissor.material = material_aditivo()
	emissor.local_coords = false
	emissor.emitting = false
	emissor.scale_amount_curve = curva_encolher()
