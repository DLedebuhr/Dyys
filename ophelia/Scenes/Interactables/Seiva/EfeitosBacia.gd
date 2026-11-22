@tool
extends Node2D
## Efeito fisico/visual: ondas no reservatorio, sem gotas, spray ou particulas.
## Nao cria nem altera qualquer colisao.

@export var reservatorio: NodePath
@export var plataforma: NodePath
@export var chegada_queda: NodePath
@export var ativo: bool = true
@export_range(0.0, 2.0) var intensidade: float = 0.65
@export_range(1.0, 100.0) var altura_minima: float = 8.0
@export_range(50.0, 1200.0) var altura_maxima: float = 450.0
@export_range(0.05, 1.0) var intervalo_passos: float = 0.28
@export_range(0.5, 5.0) var intervalo_queda: float = 2.3
@export_range(0.0, 1.0) var intensidade_queda: float = 0.13

var _jogador: CharacterBody2D
var _antes: Vector2
var _topo: float
var _iniciou: bool = false
var _apoiada_antes: bool = false
var _passo: float = 0.0
var _queda: float = 0.0


# Obter a coordenada real dos pes pela forma de colisao do jogador.
func _pes() -> Vector2:
	var ponto: Vector2 = _jogador.global_position
	for filho in _jogador.get_children():
		if filho is CollisionShape2D and not filho.disabled and filho.shape != null:
			var limites: Rect2 = filho.shape.get_rect()
			for canto in [limites.position, Vector2(limites.end.x, limites.position.y), limites.end, Vector2(limites.position.x, limites.end.y)]:
				ponto.y = maxf(ponto.y, filho.to_global(canto).y)
			break
	return ponto


# Ondas diretamente na geometria da agua, nunca desenha gotas.
func _ondular(bacia: Node2D, x: float, forca: float) -> void:
	if bacia.has_method("gerar_onda"):
		bacia.call("gerar_onda", x, clampf(forca * intensidade, 0.0, 1.5))


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or not ativo:
		return
	if not is_instance_valid(_jogador):
		_jogador = get_tree().get_first_node_in_group("jogador") as CharacterBody2D
		_iniciou = false
		_apoiada_antes = false
		if _jogador == null:
			return
	var bacia: Node2D = get_node_or_null(reservatorio) as Node2D
	if bacia == null:
		return
	var pes: Vector2 = _pes()
	if not _iniciou:
		_antes = pes
		_topo = pes.y
		_iniciou = true
	_topo = minf(_topo, pes.y)
	var anterior: Vector2 = bacia.to_local(_antes)
	var local: Vector2 = bacia.to_local(pes)
	var tamanho: Vector2 = bacia.get("tamanho")
	var dentro: bool = local.x >= -8.0 and local.x <= tamanho.x + 8.0
	var x: float = clampf(local.x, 0.0, tamanho.x)
	var superficie: float = float(bacia.call("altura", x))
	var apoiada: bool = false
	var corpo: Node = get_node_or_null(plataforma)
	if _jogador.is_on_floor() and corpo != null:
		for i in range(_jogador.get_slide_collision_count()):
			var contato: KinematicCollision2D = _jogador.get_slide_collision(i)
			if contato.get_collider() == corpo and contato.get_normal().y < -0.65:
				apoiada = true
				break
	var cruzou: bool = dentro and anterior.y < superficie and local.y >= superficie and pes.y > _antes.y
	var pousou: bool = dentro and apoiada and not _apoiada_antes
	if cruzou or pousou:
		var altura: float = maxf(0.0, pes.y - _topo)
		if altura >= altura_minima:
			var forca: float = clampf(sqrt(altura / maxf(altura_maxima, 1.0)), 0.12, 1.0)
			_ondular(bacia, x, forca)
	_passo -= delta
	if apoiada and dentro and absf(_jogador.velocity.x) > 12.0 and _passo <= 0.0:
		_ondular(bacia, x, 0.15)
		_passo = intervalo_passos
	if _jogador.is_on_floor():
		_topo = pes.y
	_apoiada_antes = apoiada
	_antes = pes


# Movimento discreto da superficie sob as duas quedas de agua.
func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not ativo:
		return
	_queda -= delta
	if _queda > 0.0 or chegada_queda.is_empty():
		return
	var bacia: Node2D = get_node_or_null(reservatorio) as Node2D
	var chegada: Node2D = get_node_or_null(chegada_queda) as Node2D
	if bacia != null and chegada != null:
		_ondular(bacia, bacia.to_local(chegada.global_position).x, intensidade_queda)
	_queda = maxf(intervalo_queda, 0.5)
