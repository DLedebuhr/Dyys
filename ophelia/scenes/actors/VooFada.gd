# ===== COMPONENTE "VooFada" — nó filho do Player =====
# Tecla V liga/desliga o voo livre como luz. Não altera jogador.gd nem ponto_origem.gd:
# enquanto voa, só pausa esses scripts e depois devolve tudo como estava.
# Para o jogo final: desmarque "habilitado" (ou apague este nó).
extends Node

signal voo_iniciado
signal voo_encerrado

enum Forma { NORMAL, ENTRANDO, VOANDO, SAINDO }

const ACAO_VOO: String = "voar_fada"
const TAM_TEXTURA: int = 128

@export var habilitado: bool = true:
	set(valor):
		habilitado = valor
		if not habilitado and forma == Forma.VOANDO and is_inside_tree():
			_encerrar_voo(true)

@export_group("Voo")
@export var velocidade_maxima: float = 500.0
@export var seguir_forca: float = 5.0         # quanto maior, mais "colada" no mouse
@export var aceleracao: float = 6.0           # suavidade ao acelerar e frear
@export var raio_parada: float = 8.0          # perto do mouse ela para (evita tremer)
@export var usar_teclado: bool = true         # A/D, setas e pular (sobe) assumem o controle
@export var colidir_no_voo: bool = false      # false = atravessa tudo (voo livre)
@export var esconder_cursor_no_voo: bool = true

@export_group("Troca de forma")
@export var duracao_troca: float = 0.7
@export var altura_busca_pouso: float = 240.0 # pousando dentro de algo, procura espaço livre até essa altura
@export var anim_para_luz: String = "transformar_luz"       # opcional: animação do sprite (boneca -> luz)
@export var anim_para_boneca: String = "transformar_boneca" # opcional: animação do sprite (luz -> boneca)

@export_group("Brilhos")
@export var cor_brilho: Color = Color(1.0, 0.92, 0.65)
@export var tamanho_brilho: float = 70.0
@export var pulso_brilho: float = 0.16
@export var duracao_resquicios: float = 5.0   # por quanto tempo sobram brilhos depois de virar boneca

var forma: Forma = Forma.NORMAL

var jogador: CharacterBody2D = null
var lenco: Node = null
var sprite: AnimatedSprite2D = null
var fita_tras: Line2D = null
var fita_frente: Line2D = null

var visuais: Array[CanvasItem] = []
var modulate_original: Dictionary = {}
var escala_sprite: Vector2 = Vector2.ONE

var brilho: Sprite2D = null
var particulas_voo: CPUParticles2D = null
var explosao: CPUParticles2D = null
var rastro: CPUParticles2D = null
var escala_brilho: Vector2 = Vector2.ONE
var rastro_min: float = 1.0
var rastro_max: float = 1.0

var centro_corpo: Vector2 = Vector2.ZERO
var pes_corpo: Vector2 = Vector2.ZERO

var velocidade: Vector2 = Vector2.ZERO
var controle_mouse: bool = true
var intensidade_resquicios: float = 0.0
var tempo: float = 0.0

func _ready() -> void:
	jogador = get_parent() as CharacterBody2D
	if jogador == null:
		push_warning("VooFada: este nó precisa ser filho direto do Player (CharacterBody2D).")
		set_physics_process(false)
		return

	_garantir_acao()
	lenco = jogador.find_child("PontoOrigem", true, false)
	sprite = jogador.find_child("AnimatedSprite2D", true, false) as AnimatedSprite2D
	fita_tras = jogador.find_child("FitaTras", true, false) as Line2D
	fita_frente = jogador.find_child("FitaFrente", true, false) as Line2D

	for no in [sprite, fita_tras, fita_frente, lenco]:
		var ci := no as CanvasItem
		if ci != null:
			visuais.append(ci)
			modulate_original[ci] = ci.modulate
	if sprite != null:
		escala_sprite = sprite.scale

	_medir_corpo()
	_criar_efeitos()

func _exit_tree() -> void:
	if esconder_cursor_no_voo:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

# Se a ação "voar_fada" não existir no Mapa de Entrada, cria uma com a tecla V
func _garantir_acao() -> void:
	if InputMap.has_action(ACAO_VOO):
		return
	InputMap.add_action(ACAO_VOO)
	var evento := InputEventKey.new()
	evento.physical_keycode = KEY_V
	InputMap.action_add_event(ACAO_VOO, evento)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		controle_mouse = true

# --- LOOP ---
func _physics_process(delta: float) -> void:
	if not habilitado and forma == Forma.NORMAL:
		return
	tempo += delta

	if habilitado and Input.is_action_just_pressed(ACAO_VOO):
		if forma == Forma.NORMAL:
			_iniciar_voo()
		elif forma == Forma.VOANDO:
			_encerrar_voo(false)

	if forma == Forma.VOANDO:
		_voar(delta)

	_atualizar_efeitos(delta)

# --- VOO LIVRE ---
func _voar(delta: float) -> void:
	var desejada := Vector2.ZERO
	var teclado := Vector2.ZERO
	if usar_teclado:
		teclado = _eixo_teclado()

	if teclado != Vector2.ZERO:
		controle_mouse = false
		desejada = teclado * velocidade_maxima
	elif controle_mouse:
		var para_mouse: Vector2 = jogador.get_global_mouse_position() - jogador.to_global(centro_corpo)
		if para_mouse.length() > raio_parada:
			desejada = (para_mouse * seguir_forca).limit_length(velocidade_maxima)

	velocidade = velocidade.lerp(desejada, 1.0 - exp(-aceleracao * delta))
	_mover_corpo(velocidade * delta)

func _mover_corpo(mov: Vector2) -> void:
	jogador.velocity = Vector2.ZERO
	if colidir_no_voo:
		var col := jogador.move_and_collide(mov)
		if col != null:
			jogador.move_and_collide(col.get_remainder().slide(col.get_normal()))
	else:
		jogador.global_position += mov

func _eixo_teclado() -> Vector2:
	var esq: String = "mover_esquerda" if InputMap.has_action("mover_esquerda") else "ui_left"
	var dir: String = "mover_direita" if InputMap.has_action("mover_direita") else "ui_right"
	var h: float = Input.get_axis(esq, dir) + Input.get_axis("ui_left", "ui_right")
	var v: float = Input.get_axis("ui_up", "ui_down")
	if InputMap.has_action("pular") and Input.is_action_pressed("pular"):
		v -= 1.0
	return Vector2(clampf(h, -1.0, 1.0), clampf(v, -1.0, 1.0))

# --- BONECA -> LUZ ---
func _iniciar_voo() -> void:
	forma = Forma.ENTRANDO
	velocidade = Vector2.ZERO
	controle_mouse = false # fica flutuando no lugar até você mexer o mouse (ou apertar uma tecla)
	_desligar_boneca()
	if esconder_cursor_no_voo:
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	voo_iniciado.emit()

	# Animação própria do sprite (opcional): toca primeiro, depois ela vira luz
	var dur_anim: float = _duracao_anim(anim_para_luz)
	if dur_anim > 0.0:
		sprite.play(anim_para_luz)
		await get_tree().create_timer(dur_anim).timeout

	var t: float = maxf(duracao_troca, 0.1)
	_explodir()
	particulas_voo.emitting = true
	rastro.emitting = false

	brilho.visible = true
	brilho.scale = escala_brilho * 0.2
	brilho.modulate = Color(1.0, 1.0, 1.0, 0.0)

	# A boneca "derrete" em luz (clareia, encolhe e some) enquanto o brilho cresce
	var tw := create_tween().set_parallel(true)
	for v in visuais:
		tw.tween_property(v, "modulate", Color(2.2, 2.0, 1.6, 0.0), t * 0.8).set_ease(Tween.EASE_IN)
	if sprite != null:
		tw.tween_property(sprite, "scale", escala_sprite * 0.35, t * 0.8) \
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(brilho, "scale", escala_brilho, t).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(brilho, "modulate:a", 1.0, t * 0.5)
	await tw.finished

	for v in visuais:
		v.visible = false
		v.modulate = modulate_original[v]
	if sprite != null:
		sprite.scale = escala_sprite
	forma = Forma.VOANDO

# Pausa o Player e o lenço sem alterar os scripts deles
func _desligar_boneca() -> void:
	jogador.set_physics_process(false)
	jogador.velocity = Vector2.ZERO
	for nome in ["planando", "planar_ativando", "esta_aterrissando", "esta_levantando", "esta_agachado"]:
		if nome in jogador:
			jogador.set(nome, false)

	if lenco != null:
		if lenco.has_method("_desativar_colisores"):
			lenco._desativar_colisores()
		if "estado_atual" in lenco and "EstadoLenco" in lenco:
			lenco.estado_atual = lenco.EstadoLenco.REPOUSO
			if "acao_pendente" in lenco:
				lenco.acao_pendente = lenco.EstadoLenco.REPOUSO
		if "corda_esticada" in lenco:
			lenco.corda_esticada = false
		lenco.process_mode = Node.PROCESS_MODE_DISABLED

# --- LUZ -> BONECA ---
func _encerrar_voo(forcar: bool) -> void:
	if forma != Forma.VOANDO:
		return

	var destino: Vector2 = _achar_ponto_livre()
	if destino == Vector2.INF:
		if not forcar:
			_recusar_pouso()
			return
		destino = jogador.global_position
	jogador.global_position = destino

	forma = Forma.SAINDO
	velocidade = Vector2.ZERO
	particulas_voo.emitting = false
	if esconder_cursor_no_voo:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_mostrar_boneca()
	intensidade_resquicios = 1.0 # os brilhos vão sobrar por um tempo e diminuir
	_explodir()

	var t: float = maxf(duracao_troca, 0.1)
	var dur_anim: float = _duracao_anim(anim_para_boneca)
	if dur_anim > 0.0:
		sprite.play(anim_para_boneca)

	# A boneca surge da luz (começa clara e volta ao normal) e o brilho dá um clarão e some
	var tw := create_tween().set_parallel(true)
	for v in visuais:
		tw.tween_property(v, "modulate", modulate_original[v], t * 0.9).set_ease(Tween.EASE_OUT)
	if sprite != null:
		tw.tween_property(sprite, "scale", escala_sprite, t * 0.9) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	var tg := create_tween()
	tg.tween_property(brilho, "scale", escala_brilho * 2.6, t * 0.25).set_ease(Tween.EASE_OUT)
	tg.tween_property(brilho, "scale", Vector2.ZERO, t * 0.6).set_ease(Tween.EASE_IN)
	tg.parallel().tween_property(brilho, "modulate:a", 0.0, t * 0.6)

	# Se há animação própria, o Player só volta a agir depois que ela termina
	if dur_anim > 0.0:
		await get_tree().create_timer(dur_anim).timeout
	jogador.velocity = Vector2.ZERO
	jogador.set_physics_process(true)

	await tw.finished
	brilho.visible = false
	forma = Forma.NORMAL
	voo_encerrado.emit()

# Deixa a boneca visível de novo (transparente e clara) e retoma o lenço do zero
func _mostrar_boneca() -> void:
	for v in visuais:
		v.visible = true
		v.modulate = Color(2.2, 2.0, 1.6, 0.0)
	if sprite != null:
		sprite.scale = escala_sprite * 0.5
	if lenco != null:
		if "origem_inicializada" in lenco:
			lenco.origem_inicializada = false # o lenço reinicia junto da boneca, sem rabo esticado
		lenco.process_mode = Node.PROCESS_MODE_INHERIT

# Pouso seguro: se a boneca ficaria dentro de algo, procura um espaço livre acima
func _achar_ponto_livre() -> Vector2:
	var base: Transform2D = jogador.global_transform
	var passos: int = int(altura_busca_pouso / 8.0)
	for i in range(passos + 1):
		var teste: Transform2D = base
		teste.origin += Vector2(0.0, -8.0 * float(i))
		if not jogador.test_move(teste, Vector2.ZERO, null, 0.08, true):
			return teste.origin
	return Vector2.INF

func _recusar_pouso() -> void:
	brilho.modulate = Color(1.0, 0.4, 0.4, 1.0)
	var tw := create_tween()
	tw.tween_property(brilho, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.35)

func _duracao_anim(nome: String) -> float:
	if sprite == null or sprite.sprite_frames == null or not sprite.sprite_frames.has_animation(nome):
		return 0.0
	var frames: SpriteFrames = sprite.sprite_frames
	var soma: float = 0.0
	for i in range(frames.get_frame_count(nome)):
		soma += frames.get_frame_duration(nome, i)
	return soma / maxf(frames.get_animation_speed(nome), 0.01)

# --- EFEITOS (brilho, faíscas e resquícios) ---
func _medir_corpo() -> void:
	var caixa := Rect2(Vector2(-8.0, -32.0), Vector2(16.0, 32.0))
	for filho in jogador.find_children("*", "CollisionShape2D", true, false):
		var cs := filho as CollisionShape2D
		if cs == null or cs.shape == null or cs.disabled:
			continue
		var centro: Vector2 = jogador.to_local(cs.global_position)
		var meia: Vector2 = Vector2(8.0, 16.0)
		var circulo := cs.shape as CircleShape2D
		var retangulo := cs.shape as RectangleShape2D
		var capsula := cs.shape as CapsuleShape2D
		if circulo != null:
			meia = Vector2(circulo.radius, circulo.radius)
		elif retangulo != null:
			meia = retangulo.size * 0.5
		elif capsula != null:
			meia = Vector2(capsula.radius, capsula.height * 0.5)
		meia = meia * cs.global_scale.abs()
		caixa = Rect2(centro - meia, meia * 2.0)
		break
	centro_corpo = caixa.get_center()
	pes_corpo = Vector2(caixa.position.x + caixa.size.x * 0.5, caixa.end.y)

# Os efeitos são filhos deste nó (e não do Player), então não herdam o fade/escala da boneca.
# Por isso a posição deles é atualizada manualmente em _atualizar_efeitos.
func _criar_efeitos() -> void:
	brilho = Sprite2D.new()
	brilho.name = "Brilho"
	brilho.texture = _textura_brilho(TAM_TEXTURA, cor_brilho)
	brilho.material = _material_aditivo()
	var esc: float = tamanho_brilho / float(TAM_TEXTURA)
	escala_brilho = Vector2(esc, esc)
	brilho.scale = escala_brilho
	brilho.z_as_relative = false
	brilho.z_index = 50
	brilho.visible = false
	add_child(brilho)

	particulas_voo = _criar_particulas("ParticulasVoo", 36, 1.0, 8.0, 40.0, 0.18, 0.5, 6.0, Vector2(0.0, -18.0))
	add_child(particulas_voo)

	explosao = _criar_particulas("Explosao", 48, 1.2, 40.0, 140.0, 0.15, 0.5, 6.0, Vector2(0.0, -30.0))
	explosao.one_shot = true
	explosao.explosiveness = 1.0
	add_child(explosao)

	rastro = _criar_particulas("Resquicios", 22, 1.1, 4.0, 22.0, 0.12, 0.35, 5.0, Vector2(0.0, -14.0))
	rastro_min = rastro.scale_amount_min
	rastro_max = rastro.scale_amount_max
	add_child(rastro)

	particulas_voo.emitting = false
	explosao.emitting = false
	rastro.emitting = false

func _explodir() -> void:
	explosao.global_position = jogador.to_global(centro_corpo)
	explosao.restart()
	explosao.emitting = true

func _atualizar_efeitos(delta: float) -> void:
	if jogador == null:
		return
	var centro_global: Vector2 = jogador.to_global(centro_corpo)
	var em_voo: bool = forma == Forma.VOANDO

	brilho.global_position = centro_global + Vector2(0.0, sin(tempo * 3.0) * 5.0)
	particulas_voo.global_position = centro_global
	rastro.global_position = jogador.to_global(pes_corpo)
	if em_voo:
		var pulso: float = 1.0 + sin(tempo * 7.0) * pulso_brilho + sin(tempo * 11.3) * pulso_brilho * 0.5
		brilho.scale = escala_brilho * pulso

	# Resquícios depois de virar boneca: sobem dos pés enquanto ela anda ou está no ar e vão diminuindo
	if forma == Forma.VOANDO or forma == Forma.ENTRANDO:
		rastro.emitting = false
		return
	intensidade_resquicios = maxf(intensidade_resquicios - delta / maxf(duracao_resquicios, 0.1), 0.0)
	var movendo: bool = absf(jogador.velocity.x) > 12.0
	var no_ar: bool = not jogador.is_on_floor()
	rastro.emitting = (movendo or no_ar) and intensidade_resquicios > 0.02
	rastro.scale_amount_min = rastro_min * intensidade_resquicios
	rastro.scale_amount_max = rastro_max * intensidade_resquicios

func _textura_brilho(tamanho: int, cor: Color) -> GradientTexture2D:
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
	grad.colors = PackedColorArray([
		Color(cor.r, cor.g, cor.b, 1.0),
		Color(cor.r, cor.g, cor.b, 0.55),
		Color(cor.r, cor.g, cor.b, 0.0),
	])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = tamanho
	tex.height = tamanho
	return tex

func _material_aditivo() -> CanvasItemMaterial:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return m

func _criar_particulas(nome: String, quantidade: int, vida: float, vel_min: float, vel_max: float,
		escala_min: float, escala_max: float, raio_emissao: float, gravidade: Vector2) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.name = nome
	p.amount = quantidade
	p.lifetime = vida
	p.local_coords = false # as faíscas ficam no mundo e formam o rastro
	p.texture = _textura_brilho(32, cor_brilho)
	p.material = _material_aditivo()
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = raio_emissao
	p.direction = Vector2(0.0, -1.0)
	p.spread = 180.0
	p.gravity = gravidade
	p.initial_velocity_min = vel_min
	p.initial_velocity_max = vel_max
	p.scale_amount_min = escala_min
	p.scale_amount_max = escala_max
	p.z_as_relative = false
	p.z_index = 49

	var curva := Curve.new()
	curva.add_point(Vector2(0.0, 1.0))
	curva.add_point(Vector2(1.0, 0.0))
	p.scale_amount_curve = curva

	var rampa := Gradient.new()
	rampa.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
	rampa.colors = PackedColorArray([
		Color(1.0, 1.0, 1.0, 1.0),
		Color(cor_brilho.r, cor_brilho.g, cor_brilho.b, 0.8),
		Color(cor_brilho.r, cor_brilho.g, cor_brilho.b, 0.0),
	])
	p.color_ramp = rampa
	return p
