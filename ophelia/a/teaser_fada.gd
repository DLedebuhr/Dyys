# ===== SCRIPT DO NÓ "Fada" (Area2D) — a luz que segue o mouse =====
class_name TeaserFada
extends Area2D

@export_group("Movimento")
@export var velocidade_maxima: float = 520.0
@export var seguir_forca: float = 5.0     # quanto maior, mais "colada" no mouse
@export var aceleracao: float = 6.0       # suavidade ao acelerar e frear
@export var raio_parada: float = 8.0      # perto do mouse ela para (evita tremer)
@export var usar_teclado: bool = true     # setas / ui_* assumem o controle quando apertadas

@export_group("Brilho")
@export var cor_brilho: Color = Color(1.0, 0.92, 0.65)
@export var tamanho_brilho: float = 56.0
@export var pulso_brilho: float = 0.12
@export var flutuacao_altura: float = 5.0
@export var flutuacao_velocidade: float = 3.0

var pode_mover: bool = true
var velocidade: Vector2 = Vector2.ZERO

var brilho: Node2D = null
var particulas: Node = null

var controle_mouse: bool = true
var desaparecendo: bool = false
var tempo: float = 0.0
var escala_brilho_base: Vector2 = Vector2.ONE

func _ready() -> void:
	# Brilho: usa o seu nó "Brilho" se existir, senão cria um padrão
	brilho = get_node_or_null("Brilho") as Node2D
	if brilho == null:
		var novo := TeaserUtil.criar_brilho("Brilho", tamanho_brilho, cor_brilho)
		add_child(novo)
		brilho = novo
	escala_brilho_base = brilho.scale

	# Partículas: usa o seu nó "Particulas" (GPUParticles2D ou CPUParticles2D) se existir
	particulas = get_node_or_null("Particulas")
	if particulas == null:
		var novas := TeaserUtil.criar_particulas_brilho("Particulas", cor_brilho, 36, 1.0,
				8.0, 40.0, 0.18, 0.5, 6.0, Vector2(0.0, -18.0))
		add_child(novas)
		particulas = novas

	# Garante uma forma de colisão para a zona conseguir detectar a fada
	var tem_forma: bool = false
	for filho in get_children():
		if filho is CollisionShape2D:
			tem_forma = true
	if not tem_forma:
		var forma := CollisionShape2D.new()
		var circulo := CircleShape2D.new()
		circulo.radius = 10.0
		forma.shape = circulo
		add_child(forma)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		controle_mouse = true

func _physics_process(delta: float) -> void:
	tempo += delta
	var desejada := Vector2.ZERO

	if pode_mover:
		var teclado := Vector2.ZERO
		if usar_teclado:
			teclado = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		if teclado != Vector2.ZERO:
			controle_mouse = false
			desejada = teclado * velocidade_maxima
		elif controle_mouse:
			var para_mouse: Vector2 = get_global_mouse_position() - global_position
			if para_mouse.length() > raio_parada:
				desejada = (para_mouse * seguir_forca).limit_length(velocidade_maxima)

	velocidade = velocidade.lerp(desejada, 1.0 - exp(-aceleracao * delta))
	global_position += velocidade * delta
	_animar()

func _animar() -> void:
	if brilho == null:
		return
	brilho.position.y = sin(tempo * flutuacao_velocidade) * flutuacao_altura
	if not desaparecendo:
		var pulso: float = 1.0 + sin(tempo * 7.0) * pulso_brilho + sin(tempo * 11.3) * pulso_brilho * 0.5
		brilho.scale = escala_brilho_base * pulso

# Chamado na transformação: o brilho cresce e some, as faíscas param de sair
func desaparecer(duracao: float) -> void:
	pode_mover = false
	desaparecendo = true
	if particulas:
		particulas.emitting = false
	var tw := create_tween().set_parallel(true)
	tw.tween_property(brilho, "scale", escala_brilho_base * 3.2, duracao) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(brilho, "modulate:a", 0.0, duracao)
