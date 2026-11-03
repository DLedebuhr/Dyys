extends Marker2D

# Reproduzir a explosão do teaser
# ---------------------
# O marcador define apenas a posição; aparência e cor vêm da raiz da planta.
func emitir(cor: Color = Color(1.0, 0.95, 0.6), quantidade: int = 18, alcance: float = 70.0, duracao: float = 0.7, tamanho: float = 1.0) -> void:

	var efeito: CPUParticles2D = CPUParticles2D.new()
	efeito.texture = _textura_brilho()
	efeito.one_shot = true
	efeito.emitting = false
	efeito.amount = quantidade
	efeito.lifetime = duracao
	efeito.explosiveness = 1.0
	efeito.direction = Vector2.UP
	efeito.spread = 180.0
	efeito.gravity = Vector2(0, 30)
	efeito.initial_velocity_min = alcance * 0.4
	efeito.initial_velocity_max = alcance
	efeito.damping_min = 40.0
	efeito.damping_max = 80.0
	efeito.scale_amount_min = 0.4 * tamanho
	efeito.scale_amount_max = tamanho
	efeito.color = cor

	var curva: Curve = Curve.new()
	curva.add_point(Vector2(0.0, 1.0))
	curva.add_point(Vector2(1.0, 0.0))
	efeito.scale_amount_curve = curva

	var material_luz: CanvasItemMaterial = CanvasItemMaterial.new()
	material_luz.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	efeito.material = material_luz
	efeito.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	efeito.z_as_relative = false
	efeito.z_index = 100

	get_tree().current_scene.add_child(efeito)
	efeito.global_position = global_position
	efeito.finished.connect(efeito.queue_free)
	efeito.emitting = true


# Criar a textura original do brilho
# ---------------------
# Usa o mesmo gradiente radial de 16 pixels do interativo do teaser.
func _textura_brilho() -> Texture2D:

	var gradiente: Gradient = Gradient.new()
	gradiente.set_color(0, Color.WHITE)
	gradiente.set_color(1, Color(1, 1, 1, 0))

	var textura: GradientTexture2D = GradientTexture2D.new()
	textura.gradient = gradiente
	textura.fill = GradientTexture2D.FILL_RADIAL
	textura.fill_from = Vector2(0.5, 0.5)
	textura.fill_to = Vector2(1.0, 0.5)
	textura.width = 16
	textura.height = 16

	return textura
