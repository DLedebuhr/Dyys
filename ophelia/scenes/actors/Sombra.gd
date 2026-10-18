extends Node2D

@export var largura: float = 28.0
@export var altura: float = 8.0
@export var cor: Color = Color(0.0, 0.0, 0.0, 0.45)
@export var altura_max_visivel: float = 160.0
@export var distancia_raio: float = 400.0
@export var escala_minima: float = 0.4
@export var recuo_raio: float = 10.0   # Quanto acima da origem o raio começa

var jogador: CharacterBody2D
var forca: float = 1.0

func _ready() -> void:
	jogador = get_parent() as CharacterBody2D
	if jogador == null:
		push_warning("Sombra: precisa ser filha direta do Player (CharacterBody2D).")
	# Sem top_level e sem z_index próprio: usa a mesma camada do Player
	top_level = false
	z_as_relative = true
	z_index = 0
	show_behind_parent = true   # Desenha atrás do Player, na mesma camada dele

func _physics_process(_delta: float) -> void:
	if jogador == null:
		return

	var origem := jogador.global_position
	var inicio := origem - Vector2(0, recuo_raio)
	var consulta := PhysicsRayQueryParameters2D.create(inicio, inicio + Vector2(0, distancia_raio))
	consulta.exclude = [jogador.get_rid()]
	var resultado := get_world_2d().direct_space_state.intersect_ray(consulta)

	if resultado.is_empty():
		visible = false
		return

	visible = true
	var y_chao: float = resultado.position.y
	global_position = Vector2(origem.x, y_chao)   # Funciona mesmo sem top_level
	global_rotation = 0.0                         # Sombra sempre reta no chão

	var dist := y_chao - origem.y
	forca = clampf(1.0 - (dist / altura_max_visivel), 0.0, 1.0)
	scale = Vector2.ONE * lerpf(escala_minima, 1.0, forca)
	queue_redraw()

func _draw() -> void:
	var c := Color(cor, cor.a * forca)
	var pontos := PackedVector2Array()
	for i in range(24):
		var a := TAU * float(i) / 24.0
		pontos.append(Vector2(cos(a) * largura * 0.5, sin(a) * altura * 0.5))
	draw_colored_polygon(pontos, c)
