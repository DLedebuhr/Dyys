class_name Interagivel
extends Node2D
## Objeto interativo: ao chegar perto mostra um botão; ao apertar a tecla,
## o botão e a imagem trocam de textura.

signal ativado(estado: bool)

@export_group("Detecção")
@export var jogador: Node2D                            # opcional: arraste o jogador
@export var grupo_jogador: StringName = &"jogador"
@export var acao: StringName = &"interagir"            # tecla R no Mapa de Entrada

@export_group("Texturas da imagem")
@export var textura_imagem_normal: Texture2D
@export var textura_imagem_ativa: Texture2D
@export var alternar: bool = true                      # true = cada R alterna; false = troca uma vez só

@export_group("Texturas do botão")
@export var textura_botao_normal: Texture2D
@export var textura_botao_pressionado: Texture2D

@export_group("Animação do botão")
@export var duracao_aparecer: float = 0.2

@onready var imagem := get_node("Imagem") as CanvasItem
@onready var botao := get_node("Botao") as CanvasItem
@onready var _cs := $ZonaProximidade/CollisionShape2D as CollisionShape2D

@export_group("Brilhos")
@export var brilhos_ativos: bool = true
@export var cor_brilho: Color = Color(1.0, 0.95, 0.6)
@export var quantidade_brilho: int = 18
@export var alcance_brilho: float = 70.0           # velocidade com que as faíscas se espalham
@export var duracao_brilho: float = 0.7
@export var tamanho_brilho: float = 1.0
@export var brilho_offset: Vector2 = Vector2.ZERO  # mover o ponto de onde saem (ex: até a flor)
@export var brilhar_ao_desativar: bool = false     # true = também brilha quando a imagem volta ao normal
@onready var ponto_brilho := find_child("PontoBrilho", true, false) as Marker2D
var ativo := false          # estado da imagem (normal / ativa)
var _perto := false
var _tween: Tween
var _avisou := false


func _ready() -> void:
	botao.modulate.a = 0.0
	botao.visible = false
	_aplicar_textura(botao, textura_botao_normal)
	_aplicar_textura(imagem, textura_imagem_normal)


func _process(_delta: float) -> void:
	var j := _achar_jogador()
	if j == null:
		return
	var perto := _dentro(_cs, j.global_position)
	if perto != _perto:
		_perto = perto
		_mostrar_botao(perto)


func _unhandled_input(event: InputEvent) -> void:
	if not _perto:
		return
	if event.is_action_pressed(acao):
		_aplicar_textura(botao, textura_botao_pressionado)
		_alternar_imagem()
		get_viewport().set_input_as_handled()
	elif event.is_action_released(acao):
		_aplicar_textura(botao, textura_botao_normal)


func _alternar_imagem() -> void:
	if alternar:
		ativo = not ativo
	else:
		if ativo:
			return
		ativo = true
	_aplicar_textura(imagem, textura_imagem_ativa if ativo else textura_imagem_normal)
	if brilhos_ativos and (ativo or brilhar_ao_desativar):
		_brilhar()
	ativado.emit(ativo)


func _mostrar_botao(mostrar: bool) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	if mostrar:
		botao.visible = true
		_tween.tween_property(botao, "modulate:a", 1.0, duracao_aparecer)
	else:
		_aplicar_textura(botao, textura_botao_normal)   # reseta se saiu com R apertado
		_tween.tween_property(botao, "modulate:a", 0.0, duracao_aparecer)
		_tween.tween_callback(func(): botao.visible = false)


func _aplicar_textura(no: CanvasItem, tex: Texture2D) -> void:
	if tex:
		no.set("texture", tex)


func _achar_jogador() -> Node2D:
	if jogador and is_instance_valid(jogador):
		return jogador
	var j := get_tree().get_first_node_in_group(grupo_jogador) as Node2D
	if j == null and not _avisou:
		_avisou = true
		push_warning("Interagivel: nenhum jogador encontrado. Coloque o jogador no grupo '%s' ou arraste no campo 'Jogador'." % grupo_jogador)
	return j


func _dentro(cs: CollisionShape2D, ponto_global: Vector2) -> bool:
	var forma := cs.shape as RectangleShape2D
	if forma == null:
		return false
	return Rect2(-forma.size / 2.0, forma.size).has_point(cs.to_local(ponto_global))

func _brilhar() -> void:
	var p := CPUParticles2D.new()
	p.texture = _textura_brilho()
	p.one_shot = true
	p.emitting = false
	p.amount = quantidade_brilho
	p.lifetime = duracao_brilho
	p.explosiveness = 1.0                 # todas saem de uma vez: efeito de explosão
	p.direction = Vector2.UP
	p.spread = 180.0                      # espalha para todos os lados
	p.gravity = Vector2(0, 30)            # cai bem de leve no final
	p.initial_velocity_min = alcance_brilho * 0.4
	p.initial_velocity_max = alcance_brilho
	p.damping_min = 40.0                  # freia no ar, como faísca
	p.damping_max = 80.0
	p.scale_amount_min = 0.4 * tamanho_brilho
	p.scale_amount_max = 1.0 * tamanho_brilho
	p.color = cor_brilho

	# Encolhe até sumir
	var curva := Curve.new()
	curva.add_point(Vector2(0.0, 1.0))
	curva.add_point(Vector2(1.0, 0.0))
	p.scale_amount_curve = curva

	# Soma luz em vez de cobrir (fica brilhante de verdade)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	p.material = mat

	p.z_index = 10
	add_child(p)
	if ponto_brilho:
		p.global_position = ponto_brilho.global_position
	else:
		p.position = _centro_imagem() + brilho_offset   # sem Marker2D, usa o centro da imagem
	p.emitting = true
	get_tree().create_timer(duracao_brilho + 0.3).timeout.connect(p.queue_free)


func _centro_imagem() -> Vector2:
	if imagem is Control:
		return imagem.position + imagem.size / 2.0
	return imagem.position   # Sprite2D já é centralizado por padrão


func _textura_brilho() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 16
	t.height = 16
	return t
