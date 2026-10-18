# ===== AUXILIAR DO TEASER: cria brilhos e partículas padrão por código =====
# Você pode substituir qualquer um desses visuais criando um nó com o mesmo nome na cena.
class_name TeaserUtil
extends RefCounted

const TAM_TEXTURA: int = 128

# Textura de brilho radial: centro claro e bordas transparentes
static func textura_brilho(tamanho: int = TAM_TEXTURA, cor: Color = Color(1.0, 0.95, 0.7)) -> GradientTexture2D:
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
	grad.colors = PackedColorArray([
		Color(cor.r, cor.g, cor.b, 1.0),
		Color(cor.r, cor.g, cor.b, 0.55),
		Color(cor.r, cor.g, cor.b, 0.0),
	])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = tamanho
	tex.height = tamanho
	return tex

# Mistura "aditiva": a luz soma com o fundo (efeito de brilho)
static func material_aditivo() -> CanvasItemMaterial:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return m

# Sprite2D de brilho pronto, com o diâmetro em pixels
static func criar_brilho(nome: String, diametro_px: float, cor: Color = Color(1.0, 0.95, 0.7)) -> Sprite2D:
	var sp := Sprite2D.new()
	sp.name = nome
	sp.texture = textura_brilho(TAM_TEXTURA, cor)
	sp.material = material_aditivo()
	var esc: float = diametro_px / float(TAM_TEXTURA)
	sp.scale = Vector2(esc, esc)
	return sp

# Partículas de faíscas: nascem, sobem/espalham e vão diminuindo até sumir
static func criar_particulas_brilho(nome: String, cor: Color, quantidade: int, vida: float,
		vel_min: float, vel_max: float, escala_min: float, escala_max: float,
		raio_emissao: float, gravidade: Vector2) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.name = nome
	p.amount = quantidade
	p.lifetime = vida
	p.local_coords = false # as partículas ficam no mundo e formam o rastro
	p.texture = textura_brilho(32, cor)
	p.material = material_aditivo()
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = raio_emissao
	p.direction = Vector2(0.0, -1.0)
	p.spread = 180.0
	p.gravity = gravidade
	p.initial_velocity_min = vel_min
	p.initial_velocity_max = vel_max
	p.scale_amount_min = escala_min
	p.scale_amount_max = escala_max

	var curva := Curve.new()
	curva.add_point(Vector2(0.0, 1.0))
	curva.add_point(Vector2(1.0, 0.0))
	p.scale_amount_curve = curva

	var rampa := Gradient.new()
	rampa.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
	rampa.colors = PackedColorArray([
		Color(1.0, 1.0, 1.0, 1.0),
		Color(cor.r, cor.g, cor.b, 0.8),
		Color(cor.r, cor.g, cor.b, 0.0),
	])
	p.color_ramp = rampa
	return p

# Caixa de colisão do corpo (no espaço local dele). Serve para achar os pés e o centro
# de qualquer personagem, sem precisar saber como a cena foi montada.
static func caixa_colisao(corpo: Node2D) -> Rect2:
	for filho in corpo.find_children("*", "CollisionShape2D", true, false):
		var cs := filho as CollisionShape2D
		if cs == null or cs.shape == null or cs.disabled:
			continue
		var centro: Vector2 = corpo.to_local(cs.global_position)
		var meia: Vector2 = Vector2(8.0, 16.0)
		var circulo := cs.shape as CircleShape2D
		var retangulo := cs.shape as RectangleShape2D
		var capsula := cs.shape as CapsuleShape2D
		if circulo != null:
			meia = Vector2(circulo.radius, circulo.radius)
		elif retangulo != null:
			meia = retangulo.size * 0.5
		elif capsula != null:
			meia = Vector2(capsula.radius, capsula.height * 0.5)
		meia = meia * cs.global_scale.abs()
		return Rect2(centro - meia, meia * 2.0)
	return Rect2(Vector2(-8.0, -32.0), Vector2(16.0, 32.0))

static func posicao_pes(corpo: Node2D) -> Vector2:
	var r: Rect2 = caixa_colisao(corpo)
	return Vector2(r.position.x + r.size.x * 0.5, r.end.y)

static func posicao_centro(corpo: Node2D) -> Vector2:
	return caixa_colisao(corpo).get_center()
