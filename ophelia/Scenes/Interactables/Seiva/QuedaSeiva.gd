@tool
extends Node2D
@export var inicio: Vector2 = Vector2.ZERO
@export var fim: Vector2 = Vector2(150, 250)
@export_range(1.0, 250.0) var espessura_inicio: float = 24.0
@export_range(1.0, 250.0) var espessura_final: float = 48.0
@export_range(0.1, 1.0) var curva: float = 0.75
@export_range(0.0, 1.0) var opacidade: float = 0.32
@export_range(0.05, 3.0) var velocidade: float = 0.65
@export var tom: Color = Color("83dfe9")
@export_range(0.0, 500.0) var suavidade_inicio: float = 220.0
@export_range(0, 500) var atraso_detalhes: float = 150.0
@export_range(0.02, 1.0) var velocidade_bacia: float = 0.12
@export_range(0.1, 3.0) var velocidade_queda: float = 1.0
@export_range(0, 1) var clareza_final: float = 0.65
@export_range(1, 300) var extensao_clara: float = 120
@export_range(0, 1) var inicio_opacidade_final: float = 0.78
@export_range(0, 1) var opacidade_final: float = 0.65
@export var integrar_bacia: bool = true
var bacia_pos: Vector2 = Vector2.ZERO
var bacia_tamanho: Vector2 = Vector2(125, 20)
var bacia_desnivel: float = 0.0
var tempo: float = 0.0
var malha: MeshInstance2D
var material_fluxo: ShaderMaterial
var assinatura: Array = []



# Preparar a queda
# ---------------------
# Cria a malha e o material sem alterar o desenho configurado.
func _ready() -> void:

	malha = MeshInstance2D.new()
	material_fluxo = ShaderMaterial.new()
	material_fluxo.shader = preload("Agua.gdshader")
	malha.material = material_fluxo
	add_child(malha)



# Calcular o caminho da água
# ---------------------
# Avalia a curva original entre os pontos de início e chegada.
func ponto(t: float) -> Vector2:

	var d: Vector2 = fim - inicio
	var c1: Vector2 = inicio + Vector2(d.x * curva, 0)
	var c2: Vector2 = fim - Vector2(0, d.y * 0.64)
	return inicio.bezier_interpolate(c1, c2, fim, t)



# Atualizar o fluxo
# ---------------------
# Reconstrói a malha somente ao mudar a geometria e avança os detalhes da água.
func _process(delta: float) -> void:

	if not is_instance_valid(malha):

		return
	tempo += delta
	var nova: Array = [
		inicio,
		fim,
		espessura_inicio,
		espessura_final,
		curva,
		integrar_bacia,
		bacia_pos,
		bacia_tamanho,
		bacia_desnivel,
		velocidade_bacia,
		velocidade_queda
	]
	if nova != assinatura:

		assinatura = nova
		_montar()
	material_fluxo.set_shader_parameter("relogio", tempo)
	material_fluxo.set_shader_parameter("inicio_opacidade_final", inicio_opacidade_final)
	material_fluxo.set_shader_parameter("opacidade_final", opacidade_final)
	material_fluxo.set_shader_parameter("clareza_final", clareza_final)
	material_fluxo.set_shader_parameter("extensao_clara", extensao_clara)
	material_fluxo.set_shader_parameter("suavidade_inicio", suavidade_inicio)
	material_fluxo.set_shader_parameter("atraso_detalhes", atraso_detalhes)
	material_fluxo.set_shader_parameter("opacidade", opacidade)
	material_fluxo.set_shader_parameter("velocidade", velocidade)
	material_fluxo.set_shader_parameter("tom", tom)



# Montar a malha contínua
# ---------------------
# Une a superfície da bacia à queda com a largura e o tempo de viagem originais.
func _montar() -> void:

	var centros := PackedVector2Array()
	var grossuras := PackedFloat32Array()
	var sentido: float = 1.0 if fim.x >= inicio.x else -1.0
	var profundidade: float = maxf(bacia_tamanho.y, 3)
	# A bacia e a queda partilham literalmente os mesmos vértices de junção.
	if integrar_bacia:

		var longe: Vector2 = bacia_pos
		if sentido < 0:

			longe += Vector2(bacia_tamanho.x, bacia_desnivel)
		var uniao: Vector2 = inicio
		for k in range(49):

			var u: float = float(k) / 48.0
			centros.append(longe.lerp(uniao, u))
			grossuras.append(lerpf(profundidade, espessura_inicio, smoothstep(0.68, 1.0, u)))
	for k in range(1 if integrar_bacia else 0, 129):

		var u: float = float(k) / 128.0
		var q: Vector2 = ponto(u)
		centros.append(q)
		var largura_original: float = lerpf(
			espessura_inicio, espessura_final, smoothstep(0.0, 1.0, u)
		)
		var largura: float = largura_original
		grossuras.append(largura)
	var distancias := PackedFloat32Array([0.0])
	for k in range(1, centros.size()):

		distancias.append(distancias[k - 1] + centros[k].distance_to(centros[k - 1]))
	var total: float = maxf(distancias[-1], 1.0)
	var viagem := PackedFloat32Array([0.0])
	var indice_borda: int = 48 if integrar_bacia else 0
	for k in range(1, centros.size()):

		var razao: float = velocidade_queda
		if integrar_bacia and k <= indice_borda:

			razao = lerpf(
				velocidade_bacia, velocidade_queda * 0.36, smoothstep(0.60, 1.0, float(k) / 48.0)
			)
		else:

			razao = lerpf(
				velocidade_queda * 0.36,
				velocidade_queda,
				smoothstep(0.0, 0.55, float(k - indice_borda) / 128.0)
			)
		viagem.append(viagem[k - 1] + (distancias[k] - distancias[k - 1]) / maxf(razao, 0.02))
	material_fluxo.set_shader_parameter("distancia_borda", distancias[indice_borda])
	var total_viagem: float = maxf(viagem[-1], 1.0)
	var cores := PackedColorArray()
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for k in range(centros.size()):

		var tang: Vector2 = (
			(centros[mini(k + 1, centros.size() - 1)] - centros[maxi(k - 1, 0)]).normalized()
		)
		var normal := Vector2(-tang.y, tang.x) * sentido
		for lado in range(2):

			# Na bacia o guia é a superfície. Na curva só a contribuição
			# da espessura inicial é deslocada para baixo; o fim segue centrado.
			var ancora: float = grossuras[k] * 0.5
			if k >= (48 if integrar_bacia else 0):

				var u: float = float(k - (48 if integrar_bacia else 0)) / 128.0
				ancora = espessura_inicio * 0.5 * (1.0 - smoothstep(0.0, 1.0, u))
			var q: Vector2 = centros[k] + normal * (grossuras[k] * (float(lado) - 0.5) + ancora)
			vertices.append(Vector3(q.x, q.y, 0))
			uvs.append(Vector2(float(lado), viagem[k] / total_viagem))
			cores.append(Color(distancias[k] / total, 1, 1, 1))
		if k < centros.size() - 1:

			var j: int = k * 2
			indices.append_array(PackedInt32Array([j, j + 1, j + 2, j + 1, j + 3, j + 2]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	arrays[Mesh.ARRAY_COLOR] = cores
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	malha.mesh = mesh
	material_fluxo.set_shader_parameter("comprimento", total)
	material_fluxo.set_shader_parameter("tempo_caminho", total_viagem)
	queue_redraw()



# Mostrar os guias de edição
# ---------------------
# Desenha as marcações de largura apenas no editor.
func _draw() -> void:

	if not Engine.is_editor_hint():

		return
	# Início: marcador na borda superior. Fim: marcador no centro, como antes.
	var sentido: float = 1.0 if fim.x >= inicio.x else -1.0
	var tang_inicio: Vector2 = (ponto(0.001) - ponto(0)).normalized()
	var normal_inicio := Vector2(-tang_inicio.y, tang_inicio.x) * sentido
	draw_line(inicio, inicio + normal_inicio * espessura_inicio, Color(0.3, 1, 0.75, 0.85), 1, true)
	var tang_fim: Vector2 = (ponto(1) - ponto(0.999)).normalized()
	var normal_fim := Vector2(-tang_fim.y, tang_fim.x) * sentido
	draw_line(
		fim - normal_fim * espessura_final * 0.5,
		fim + normal_fim * espessura_final * 0.5,
		Color(0.3, 1, 0.75, 0.85),
		1,
		true
	)
