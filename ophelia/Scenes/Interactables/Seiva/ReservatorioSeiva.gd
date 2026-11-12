@tool
extends Node2D
## Origem na esquerda da superfície. A largura/altura são independentes da queda.
@export var tamanho: Vector2 = Vector2(180, 35)
@export var desnivel: float = 0.0
@export_range(0.0, 1.0) var opacidade: float = 0.46
@export var tom: Color = Color("83dfe9")
@export_range(0.0, 3.0) var ondas: float = 0.7
@export var area_calma: Vector2 = Vector2(-1, 20)
@export var integrada: bool = false
var volume: Polygon2D
var material_volume: ShaderMaterial
var tempo: float = 0.0



# Preparar o reservatório
# ---------------------
# Cria o preenchimento e o material da superfície.
func _ready() -> void:

	volume = Polygon2D.new()
	var branco := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	branco.fill(Color.WHITE)
	volume.texture = ImageTexture.create_from_image(branco)
	material_volume = ShaderMaterial.new()
	material_volume.shader = preload("Bacia.gdshader")
	volume.material = material_volume
	add_child(volume)



# Calcular a superfície
# ---------------------
# Mantém o desnível e a área calma com as ondas configuradas.
func altura(x: float) -> float:

	var u: float = clampf(x / maxf(tamanho.x, 1), 0, 1)
	var peso: float = sin(PI * u)
	if area_calma.x >= 0:

		peso *= smoothstep(area_calma.y, area_calma.y + 20, absf(x - area_calma.x))
	return (
		desnivel * u + peso * ondas * (sin(x * 0.035 - tempo * 1.5) + 0.2 * sin(x * 0.08 + tempo))
	)



# Atualizar a bacia
# ---------------------
# Move a superfície e atualiza os parâmetros do material.
func _process(delta: float) -> void:

	tempo += delta
	if not is_instance_valid(volume):

		return
	volume.visible = not integrada
	var w: float = maxf(tamanho.x, 4)
	var h: float = maxf(tamanho.y, 3)
	var pontos := PackedVector2Array()
	var uvs := PackedVector2Array()
	for k in range(97):

		var u: float = float(k) / 96.0
		pontos.append(Vector2(u * w, altura(u * w)))
		uvs.append(Vector2(u, 0))
	pontos.append(Vector2(w, h + desnivel))
	pontos.append(Vector2(0, h))
	uvs.append(Vector2(1, 1))
	uvs.append(Vector2(0, 1))
	volume.polygon = pontos
	volume.uv = uvs
	material_volume.set_shader_parameter("relogio", tempo)
	material_volume.set_shader_parameter("opacidade", opacidade)
	material_volume.set_shader_parameter("tom", tom)
	queue_redraw()



# Desenhar a linha da superfície
# ---------------------
# Aplica o contorno original nas bacias que não estão integradas à queda.
func _draw() -> void:

	if integrada:

		return
	var linha := PackedVector2Array()
	for k in range(97):

		var x: float = maxf(tamanho.x, 4) * float(k) / 96.0
		linha.append(Vector2(x, altura(x)))
	draw_polyline(linha, Color(0.83, 0.96, 0.97, 0.55), 1.4, true)
