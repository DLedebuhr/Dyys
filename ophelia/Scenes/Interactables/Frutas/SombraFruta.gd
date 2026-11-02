extends Sprite2D

@export_group("Aparência")
@export var cor: Color = Color(0.04, 0.04, 0.10)
@export_range(0.0, 1.0) var opacidade: float = 0.35
@export var largura: float = 26.0
@export_range(0.1, 1.0) var proporcao_altura: float = 0.28
@export var deslocamento: Vector2 = Vector2.ZERO
@export_group("Chão")
@export_flags_2d_physics var mascara_chao: int = 1
@export var alcance_busca: float = 48.0
@export var velocidade_fade: float = 6.0

var _fruta: RigidBody2D
var _fade: float = 0.0
static var _textura_compartilhada: GradientTexture2D

# Preparar a sombra
# ---------------------
# Usa a mesma mancha suave da Ophelia, com tamanho menor para a fruta.
func _ready() -> void:

	_fruta = get_parent() as RigidBody2D
	top_level = true
	z_index = -1
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

	if texture == null:

		texture = _obter_textura()

	ocultar()

# Ativar depois do corte
# ---------------------
# Busca o chão somente enquanto a fruta está solta.
func ativar() -> void:

	_fade = 0.0
	set_physics_process(true)

# Ocultar quando indisponível
# ---------------------
# Remove a sombra ao coletar ou devolver a fruta ao galho.
func ocultar() -> void:

	_fade = 0.0
	hide()
	set_physics_process(false)

# Acompanhar o chão
# ---------------------
# Aparece perto do contato e acompanha o relevo sem girar com a fruta.
func _physics_process(delta: float) -> void:

	if not is_instance_valid(_fruta) or int(_fruta.get("estado")) != 1 or not _fruta.visible:

		ocultar()
		return

	var consulta := PhysicsRayQueryParameters2D.create(_fruta.global_position, _fruta.global_position + Vector2.DOWN * alcance_busca, mascara_chao, [_fruta.get_rid()])
	var resultado: Dictionary = get_world_2d().direct_space_state.intersect_ray(consulta)
	var visivel: bool = not resultado.is_empty()
	var altura: float = 0.0

	if visivel:

		var ponto: Vector2 = resultado["position"]
		global_position = ponto + deslocamento
		global_rotation = 0.0
		altura = clampf(maxf(ponto.y - _fruta.global_position.y - 9.0, 0.0) / maxf(alcance_busca - 9.0, 1.0), 0.0, 1.0)

	_fade = move_toward(_fade, 1.0 if visivel else 0.0, delta * velocidade_fade)
	visible = _fade > 0.01
	var fator: float = lerpf(1.0, 0.5, altura)
	global_scale = Vector2(largura / texture.get_width(), largura * proporcao_altura / texture.get_height()) * fator
	self_modulate = Color(cor, opacidade * _fade * lerpf(1.0, 0.3, altura))

# Compartilhar a textura suave
# ---------------------
# Gera a mesma textura radial usada pela sombra da personagem uma única vez.
func _obter_textura() -> GradientTexture2D:

	if _textura_compartilhada == null:

		var gradiente := Gradient.new()
		gradiente.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
		gradiente.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0.55), Color(1, 1, 1, 0)])
		_textura_compartilhada = GradientTexture2D.new()
		_textura_compartilhada.gradient = gradiente
		_textura_compartilhada.fill = GradientTexture2D.FILL_RADIAL
		_textura_compartilhada.fill_from = Vector2(0.5, 0.5)
		_textura_compartilhada.fill_to = Vector2(1.0, 0.5)
		_textura_compartilhada.width = 128
		_textura_compartilhada.height = 128

	return _textura_compartilhada
