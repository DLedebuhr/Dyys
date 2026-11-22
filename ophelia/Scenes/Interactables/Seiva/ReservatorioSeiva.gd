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

@export_group("Ondulacao ao tocar a agua")
@export_range(0.0, 25.0, 0.5) var amplitude_impacto: float = 11.0
@export_range(20.0, 250.0, 1.0) var velocidade_ondas: float = 110.0
@export_range(10.0, 70.0, 1.0) var largura_onda: float = 29.0
@export_range(0.4, 5.0, 0.1) var amortecimento_ondas: float = 1.9
@export_range(0.4, 5.0, 0.1) var duracao_impacto: float = 2.1

var _impactos: Array[Dictionary] = []


# Criar uma onda bidirecional no ponto onde os pes tocaram a agua.
func gerar_onda(x: float, forca: float = 1.0) -> void:
	if Engine.is_editor_hint():
		return
	var w: float = maxf(tamanho.x, 4.0)
	var valor: float = clampf(forca, 0.0, 1.5)
	if valor <= 0.0:
		return
	_impactos.append({"x": clampf(x, 0.0, w), "t": 0.0, "f": valor})
	if _impactos.size() > 12:
		_impactos.pop_front()


func ondas_ativas() -> bool:
	return not _impactos.is_empty()



# Preparar o reservatório
# ---------------------
# Cria o preenchimento e o material da superfície.
func _ready() -> void:

	volume = Polygon2D.new()
	volume.antialiased = true
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
	var y: float = desnivel * u + peso * ondas * (sin(x * 0.035 - tempo * 1.5) + 0.2 * sin(x * 0.08 + tempo))
	# Impulso que viaja para as duas laterais, diminui com o tempo
	# e deixa as bordas estaveis (sem gotas nem particulas).
	for impacto in _impactos:
		var t: float = float(impacto["t"])
		var origem: float = float(impacto["x"])
		var caminho: float = velocidade_ondas * t
		var a: float = (x - origem - caminho) / maxf(largura_onda, 1.0)
		var b: float = (x - origem + caminho) / maxf(largura_onda, 1.0)
		var perfil: float = 0.5 * (exp(-a * a * 0.5) * cos(a * 2.0) + exp(-b * b * 0.5) * cos(b * 2.0))
		y -= perfil * amplitude_impacto * float(impacto["f"]) * exp(-t * amortecimento_ondas) * peso
	return y



# Atualizar a bacia
# ---------------------
# Move a superfície e atualiza os parâmetros do material.
func _process(delta: float) -> void:

	tempo += delta
	for i in range(_impactos.size() - 1, -1, -1):
		_impactos[i]["t"] = float(_impactos[i]["t"]) + delta
		if float(_impactos[i]["t"]) >= duracao_impacto:
			_impactos.remove_at(i)
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
