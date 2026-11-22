extends Node2D
## Pilha perdida ao morrer: flutua no mundo, pode ser recuperada, expira após o prazo.
## Não altera nenhuma colisão física do cenário.

var id: StringName = &""
var quantidade: int = 0
var tempo_recuperacao: float = 600.0
var raio_coleta: float = 56.0
var dono: CharacterBody2D
var inventario: Node
var icone: Texture2D
var _tempo: float = 0.0
var _quantidade_label: Label

func configurar(dados: Dictionary, jogador: CharacterBody2D, bolsa: Node, prazo: float, distancia: float) -> void:
	id = StringName(dados.get("id", &""))
	quantidade = int(dados.get("quantidade", 0))
	dono = jogador
	inventario = bolsa
	tempo_recuperacao = maxf(prazo, 0.1)
	raio_coleta = maxf(distancia, 10.0)
	var catalogo = inventario.get("catalogo") if is_instance_valid(inventario) else null
	if catalogo != null:
		var item = catalogo.obter(id)
		if item != null:
			icone = item.icone

func _ready() -> void:
	z_index = 5
	add_to_group("item_perdido_ophelia")
	if quantidade > 1:
		_quantidade_label = Label.new()
		_quantidade_label.text = "×%d" % quantidade
		_quantidade_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_quantidade_label.position = Vector2(12, -42)
		_quantidade_label.add_theme_font_size_override("font_size", 12)
		_quantidade_label.add_theme_color_override("font_color", Color(0.9, 1.0, 0.96))
		add_child(_quantidade_label)

func _process(delta: float) -> void:
	_tempo += delta
	if _tempo >= tempo_recuperacao:
		queue_free()
		return
	if is_instance_valid(_quantidade_label):
		_quantidade_label.position.y = -42.0 + sin(_tempo * 3.2) * 4.0
	queue_redraw()
	if _tempo < 0.28 or not is_instance_valid(dono) or not is_instance_valid(inventario):
		return
	var vida: Node = dono.get_node_or_null("Vitalidade")
	if vida != null and vida.has_method("esta_viva") and not bool(vida.call("esta_viva")):
		return
	if dono.process_mode == Node.PROCESS_MODE_DISABLED:
		return
	if dono.global_position.distance_to(global_position + Vector2(0, -24)) > raio_coleta:
		return
	# Recuperação parcial, mesmo que não caiba a pilha inteira.
	var minimo := 0
	var maximo := quantidade
	while minimo < maximo:
		var meio: int = floori(float(minimo + maximo + 1) / 2.0)
		if inventario.pode_adicionar(id, meio):
			minimo = meio
		else:
			maximo = meio - 1
	if minimo > 0 and inventario.adicionar(id, minimo):
		quantidade -= minimo
		if quantidade == 0:
			queue_free()
		elif is_instance_valid(_quantidade_label):
			_quantidade_label.text = "×%d" % quantidade

func _draw() -> void:
	var flutuar: float = sin(_tempo * 3.2) * 4.0
	var pos := Vector2(0, -26 + flutuar)
	var sumir: float = clampf((tempo_recuperacao - _tempo) / 0.55, 0.0, 1.0)
	draw_circle(pos, 21.0, Color(0.40, 0.85, 0.72, 0.10 * sumir))
	if icone != null:
		draw_texture_rect(icone, Rect2(pos - Vector2(17, 17), Vector2(34, 34)), false, Color(1, 1, 1, sumir))
	else:
		draw_circle(pos, 10.0, Color(0.62, 0.92, 0.83, sumir))
	draw_arc(pos, 20.0, 0.0, TAU, 28, Color(0.68, 1.0, 0.9, 0.28 * sumir), 1.4)


func exportar_estado_save() -> Dictionary:
	return {"id": String(id), "quantidade": quantidade,
			"restante": maxf(0.0, tempo_recuperacao - _tempo),
			"posicao": [global_position.x, global_position.y]}
