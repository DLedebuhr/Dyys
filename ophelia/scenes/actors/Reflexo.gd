extends AnimatedSprite2D

@export var principal: AnimatedSprite2D            # Arraste o AnimatedSprite2D do Player aqui
@export var cor_reflexo: Color = Color(0.0, 0.0, 0.05, 0.35)  # Escuro e transparente
@export var altura_max_visivel: float = 200.0      # Acima disso o reflexo some
@export var distancia_raio: float = 400.0          # Até onde procura o chão

const SHADER := """
shader_type canvas_item;
uniform vec4 cor : source_color;
uniform float forca : hint_range(0.0, 1.0) = 1.0;
void fragment() {
	vec4 t = texture(TEXTURE, UV);
	// Fade: forte perto dos pés (UV.y = 1), some para longe do chão
	float fade = smoothstep(0.0, 1.0, UV.y);
	COLOR = vec4(cor.rgb, t.a * cor.a * fade * forca);
}
"""

var jogador: CharacterBody2D

func _ready() -> void:
	jogador = get_parent() as CharacterBody2D
	show_behind_parent = true              # Fica atrás do personagem
	scale.y = -1.0                         # Espelha na vertical

	var mat := ShaderMaterial.new()
	mat.shader = Shader.new()
	mat.shader.code = SHADER
	mat.set_shader_parameter("cor", cor_reflexo)
	material = mat

	if principal:
		sprite_frames = principal.sprite_frames

func _process(_delta: float) -> void:
	if principal == null or jogador == null:
		return

	# Copia animação, frame e direção do sprite principal
	if animation != principal.animation:
		animation = principal.animation
	frame = principal.frame
	flip_h = principal.flip_h
	offset = principal.offset
	scale.x = principal.scale.x

	# Procura o chão abaixo do personagem
	var espaco := get_world_2d().direct_space_state
	var origem := principal.global_position
	var consulta := PhysicsRayQueryParameters2D.create(origem, origem + Vector2(0, distancia_raio))
	consulta.exclude = [jogador.get_rid()]
	var resultado := espaco.intersect_ray(consulta)

	if resultado.is_empty():
		visible = false
		return

	visible = true
	var y_chao: float = resultado.position.y

	# Espelha a posição em relação ao chão
	global_position = Vector2(origem.x, 2.0 * y_chao - origem.y)

	# Quanto mais alto o personagem, mais fraco o reflexo
	var altura := y_chao - origem.y
	var forca := clampf(1.0 - (altura / altura_max_visivel), 0.0, 1.0)
	(material as ShaderMaterial).set_shader_parameter("forca", forca)
