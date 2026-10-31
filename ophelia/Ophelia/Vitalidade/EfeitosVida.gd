extends Node2D
## Partículas desenhadas por código. Sem círculo no chão e sem coluna de luz.
@export var vitalidade: Node
@export var sprite: AnimatedSprite2D
@export var centro_efeitos: Vector2 = Vector2(0, -30)
@export var tamanho_personagem: Vector2 = Vector2(50, 95)
@export var cor_cura: Color = Color(0.35, 1.0, 0.5)
@export_range(0, 80, 1) var quantidade_particulas_cura: int = 20
@export_range(0.1, 1.0, 0.05) var opacidade_cura: float = 0.6
@export_range(5.0, 80.0, 1.0) var velocidade_cura: float = 25.0
@export var cor_dano: Color = Color(1.0, 0.8, 0.5)
@export_range(0.0, 10.0, 0.1) var forca_tremida: float = 2.5
var _particulas: Array[Dictionary] = []
var _tempo: float = 0.0
var _tremida: float = 0.0
var _posicao_sprite: Vector2
var _cor_sprite: Color

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	if vitalidade == null:
		vitalidade = get_parent().get_node_or_null("Vitalidade")
	if sprite == null:
		sprite = get_parent().find_child("SpritePersonagem", true, false) as AnimatedSprite2D
	if sprite != null:
		_posicao_sprite = sprite.position
		_cor_sprite = sprite.self_modulate
	if vitalidade == null:
		return
	vitalidade.dano_recebido.connect(_dano)
	if vitalidade.has_signal("fruta_consumida"):
		vitalidade.connect("fruta_consumida", _ao_consumir_fruta)
	vitalidade.morreu.connect(_morte)
	vitalidade.restaurada.connect(_restaurar_sprite)

func _dano(_quantidade: float, _origem: Vector2) -> void:
	_tremida = 0.22
	_emitir(25, cor_dano, false, false)

func _ao_consumir_fruta(_estacao: StringName, _quantidade_curada: float) -> void:
	_emitir(quantidade_particulas_cura, cor_cura, true, false)

func _morte() -> void:
	_emitir(120, cor_dano, false, true)

func _emitir(quantidade: int, cor: Color, cura: bool, morte: bool) -> void:
	for i in range(quantidade):
		var pos: Vector2 = centro_efeitos + Vector2(randf_range(-0.5, 0.5), randf_range(-0.5, 0.5)) * tamanho_personagem
		var velocidade: Vector2 = Vector2(randf_range(-6.0, 6.0), -velocidade_cura * randf_range(0.6, 1.1)) if cura else Vector2.RIGHT.rotated(randf() * TAU) * randf_range(40.0, 210.0 if morte else 90.0)
		var duracao: float = randf_range(1.1, 1.7) if cura else randf_range(0.65, 1.25)
		_particulas.append({"p": to_global(pos), "v": velocidade, "t": duracao, "total": duracao, "cor": cor, "cruz": cura and i % 3 == 0, "r": randf_range(1.5, 3.0) if cura else randf_range(2.0, 5.0), "cura": cura, "atraso": randf_range(0.0, 0.25) if cura else 0.0})

func _process(delta: float) -> void:
	_tempo += delta
	_tremida = maxf(0.0, _tremida - delta)
	if is_instance_valid(sprite):
		sprite.position = _posicao_sprite + (Vector2(randf_range(-1, 1), randf_range(-1, 1)) * forca_tremida if _tremida > 0.0 else Vector2.ZERO)
		var piscando: bool = is_instance_valid(vitalidade) and bool(vitalidade.call("esta_invulneravel")) and bool(vitalidade.call("esta_viva"))
		sprite.self_modulate = Color(_cor_sprite, _cor_sprite.a * (0.25 if piscando and sin(_tempo * 40.0) > 0 else 1.0))
	for i in range(_particulas.size() - 1, -1, -1):
		if float(_particulas[i]["atraso"]) > 0.0:
			_particulas[i]["atraso"] -= delta
			continue
		_particulas[i]["t"] -= delta
		_particulas[i]["p"] += _particulas[i]["v"] * delta
		if _particulas[i]["t"] <= 0.0:
			_particulas.remove_at(i)
	queue_redraw()

func _draw() -> void:
	for p in _particulas:
		if float(p["atraso"]) > 0.0:
			continue
		var pos: Vector2 = to_local(p["p"])
		var cor: Color = Color(p["cor"], clampf(float(p["t"]) / minf(0.35, float(p["total"])), 0, 1))
		if bool(p["cura"]):
			var idade: float = 1.0 - float(p["t"]) / float(p["total"])
			cor.a = opacidade_cura * smoothstep(0.0, 0.2, idade) * (1.0 - smoothstep(0.45, 1.0, idade))
		var r: float = p["r"]
		draw_circle(pos, r * 2.0, Color(cor, cor.a * 0.08))
		if p["cruz"]:
			draw_line(pos - Vector2(r, 0), pos + Vector2(r, 0), cor, r * 0.65, true)
			draw_line(pos - Vector2(0, r), pos + Vector2(0, r), cor, r * 0.65, true)
		else:
			draw_circle(pos, r * 0.5, cor)

func _restaurar_sprite() -> void:
	_tremida = 0.0
	if is_instance_valid(sprite):
		sprite.position = _posicao_sprite
		sprite.self_modulate = _cor_sprite
