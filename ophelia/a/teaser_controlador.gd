# ===== SCRIPT DO NÓ RAIZ "Teaser" — controla a sequência inteira do teaser =====
# Câmera em travelling + voo da luz -> zona de transformação -> a cena Player aparece
# -> zona do portão -> portão abre -> luz cobre a tela de branco -> cena de Demonstração.
extends Node2D

enum Fase { VOO, TRANSFORMANDO, CAMINHANDO, PORTAO_ABRINDO, ENTRANDO, FINAL }

@export_group("Personagem")
@export var cena_boneca: PackedScene                  # arraste aqui a sua cena Player
@export var duracao_brilhos: float = 7.0              # por quanto tempo a boneca solta brilhos
@export var cor_brilhos: Color = Color(1.0, 0.92, 0.65)

@export_group("Final")
@export_file("*.tscn") var cena_demonstracao: String = ""   # para onde ela vai ao entrar no portão
@export var duracao_fade_demonstracao: float = 1.4          # o branco some aos poucos na Demonstração
@export var esconder_cursor: bool = true                    # some com o cursor (a luz é o cursor)

@export_group("Câmera (travelling inicial)")
@export var camera_atraso_inicio: float = 1.0         # espera antes de começar a andar
@export var camera_duracao: float = 20.0              # tempo total até chegar no fim
@export var camera_tempo_aceleracao: float = 2.5      # começa devagar
@export var camera_tempo_freio: float = 3.5           # chega devagar e fica parada
@export var camera_distancia_padrao: Vector2 = Vector2(1500.0, 0.0) # usada se não houver o nó CameraFim
@export var limitar_fada_na_tela: bool = true         # a luz não sai da tela (útil com teclado)
@export var margem_tela: float = 48.0
@export var camera_segue_boneca: bool = false         # false = a câmera fica parada no fim
@export var camera_suavidade: float = 3.0
@export var camera_deslocamento_boneca: Vector2 = Vector2(0.0, -30.0)

@export_group("Transformação")
@export var raio_aviso: float = 320.0                 # distância em que o marcador começa a brilhar
@export var atraso_transformacao: float = 0.3
@export var duracao_transformacao: float = 1.0
@export var deslocamento_pouso: Vector2 = Vector2.ZERO

@export_group("Portão e luz final")
@export var duracao_entrada: float = 3.5              # boneca entrando + luz crescendo
@export var atraso_branco: float = 1.2                # quando a tela começa a branquear
@export var duracao_branco: float = 2.0
@export var tempo_branco_parado: float = 0.8

var fase: Fase = Fase.VOO

var camera: Camera2D = null
var fada: TeaserFada = null
var boneca: CharacterBody2D = null
var brilhos_boneca: TeaserBrilhos = null
var portao: TeaserPortao = null
var zona_transformacao: Area2D = null
var zona_portao: Area2D = null
var ponto_entrada: Node2D = null

var camera_inicio: Vector2 = Vector2.ZERO
var camera_fim: Vector2 = Vector2.ZERO
var tempo_camera: float = 0.0
var camera_terminou: bool = false

var andando_auto: bool = false

var marcador: Node2D = null
var escala_marcador: Vector2 = Vector2.ONE
var camada_branco: CanvasLayer = null
var branco: ColorRect = null
var tempo: float = 0.0

func _ready() -> void:
	fada = find_child("Fada", true, false) as TeaserFada
	portao = find_child("Portao", true, false) as TeaserPortao
	zona_transformacao = find_child("ZonaTransformacao", true, false) as Area2D
	zona_portao = find_child("ZonaPortao", true, false) as Area2D
	ponto_entrada = find_child("PontoEntrada", true, false) as Node2D

	var cameras := find_children("*", "Camera2D", true, false)
	if cameras.size() > 0:
		camera = cameras[0] as Camera2D

	if fada == null:
		push_error("Teaser: não achei o nó 'Fada' (Area2D com teaser_fada.gd).")
		set_physics_process(false)
		return

	_criar_camada_branco()

	# Câmera: começa onde está no editor e anda até o nó "CameraFim"
	if camera:
		camera.position_smoothing_enabled = false # o movimento é calculado aqui
		camera.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
		camera.make_current()
		camera_inicio = camera.global_position
		var marcador_fim := find_child("CameraFim", true, false) as Node2D
		if marcador_fim:
			camera_fim = marcador_fim.global_position
		else:
			camera_fim = camera_inicio + camera_distancia_padrao
	else:
		push_warning("Teaser: não achei nenhum Camera2D na cena.")

	if cena_boneca == null:
		push_warning("Teaser: 'cena_boneca' vazia. Arraste a sua cena Player para esse campo no nó Teaser. Usando uma boneca simples de reserva.")

	if zona_transformacao:
		_preparar_marcador()
		zona_transformacao.area_entered.connect(_ao_entrar_zona_transformacao)
	else:
		push_warning("Teaser: não achei 'ZonaTransformacao' (Area2D).")

	if zona_portao:
		zona_portao.body_entered.connect(_ao_entrar_zona_portao)
	else:
		push_warning("Teaser: não achei 'ZonaPortao' (Area2D).")

	# Carrega a Demonstração em segundo plano para a troca não travar
	if cena_demonstracao != "" and ResourceLoader.exists(cena_demonstracao):
		ResourceLoader.load_threaded_request(cena_demonstracao)

	if esconder_cursor:
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_soltar_teclas()

func _unhandled_input(event: InputEvent) -> void:
	# R reinicia o teaser (útil para gravar outra tomada)
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		get_tree().reload_current_scene()

func _physics_process(delta: float) -> void:
	tempo += delta
	_atualizar_camera(delta)
	_limitar_fada()
	_atualizar_marcador()
	_andar_automatico()

# --- CÂMERA ---
# Anda sozinha até o fim (com partida e chegada suaves) e fica parada lá.
# Quem se move para acompanhar é a luz, guiada pelo mouse (ou pelas setas).
func _atualizar_camera(delta: float) -> void:
	if camera == null:
		return

	# Opcional: depois da transformação a câmera pode seguir a boneca
	if camera_segue_boneca and boneca != null and fase >= Fase.CAMINHANDO:
		var alvo: Vector2 = boneca.global_position + camera_deslocamento_boneca
		camera.global_position = camera.global_position.lerp(alvo, 1.0 - exp(-camera_suavidade * delta))
		return

	if camera_terminou:
		return

	tempo_camera += delta
	var t: float = tempo_camera - camera_atraso_inicio
	camera.global_position = camera_inicio.lerp(camera_fim, _perfil_camera(t))
	if t >= camera_duracao:
		camera_terminou = true
		camera.global_position = camera_fim

# Progresso de 0 a 1 com aceleração no começo e freio no fim (velocidade constante no meio)
func _perfil_camera(t: float) -> float:
	var total: float = maxf(camera_duracao, 0.1)
	if t <= 0.0:
		return 0.0
	if t >= total:
		return 1.0
	var t_in: float = maxf(minf(camera_tempo_aceleracao, total * 0.5), 0.001)
	var t_out: float = maxf(minf(camera_tempo_freio, total * 0.5), 0.001)
	var v_max: float = 1.0 / (total - 0.5 * (t_in + t_out))
	if t < t_in:
		return 0.5 * v_max * t * t / t_in
	if t <= total - t_out:
		return 0.5 * v_max * t_in + v_max * (t - t_in)
	var resta: float = total - t
	return 1.0 - 0.5 * v_max * resta * resta / t_out

# Mantém a luz dentro da tela enquanto a câmera anda
func _limitar_fada() -> void:
	if not limitar_fada_na_tela or camera == null or fase != Fase.VOO:
		return
	var metade: Vector2 = get_viewport_rect().size / camera.zoom * 0.5
	var centro: Vector2 = camera.get_screen_center_position()
	var margem: float = minf(margem_tela, minf(metade.x, metade.y) * 0.5) # nunca maior que a tela
	var minimo: Vector2 = centro - metade + Vector2(margem, margem)
	var maximo: Vector2 = centro + metade - Vector2(margem, margem)
	fada.global_position = fada.global_position.clamp(minimo, maximo)

# --- MARCADOR DA ZONA DE TRANSFORMAÇÃO ---
func _preparar_marcador() -> void:
	var raio: float = _raio_da_zona(zona_transformacao)
	marcador = zona_transformacao.get_node_or_null("Marcador") as Node2D
	if marcador == null:
		var novo := TeaserUtil.criar_brilho("Marcador", raio * 2.4, Color(0.7, 0.9, 1.0))
		zona_transformacao.add_child(novo)
		marcador = novo
	escala_marcador = marcador.scale

func _raio_da_zona(area: Area2D) -> float:
	for filho in area.get_children():
		var cs := filho as CollisionShape2D
		if cs != null and cs.shape != null:
			var circulo := cs.shape as CircleShape2D
			if circulo != null:
				return circulo.radius
			var retangulo := cs.shape as RectangleShape2D
			if retangulo != null:
				return maxf(retangulo.size.x, retangulo.size.y) * 0.5
	return 80.0

# Pulsa devagar e fica mais forte conforme a luz se aproxima: é o "identificador" do lugar
func _atualizar_marcador() -> void:
	if marcador == null or fase != Fase.VOO:
		return
	var dist: float = fada.global_position.distance_to(zona_transformacao.global_position)
	var perto: float = clampf(1.0 - dist / raio_aviso, 0.0, 1.0)
	marcador.modulate.a = lerpf(0.3, 1.0, perto)
	marcador.scale = escala_marcador * (1.0 + sin(tempo * 2.4) * 0.08 + perto * 0.15)

# --- A BONECA: usa a cena Player que você já tem ---
func _criar_boneca() -> CharacterBody2D:
	if cena_boneca != null:
		var instancia := cena_boneca.instantiate() as CharacterBody2D
		if instancia != null:
			# A câmera do Player é desligada (aqui só no teaser; a cena original não muda)
			for cam in instancia.find_children("*", "Camera2D", true, false):
				var c := cam as Camera2D
				if c != null:
					c.enabled = false
			instancia.name = "Boneca"
			return instancia
		push_warning("Teaser: a raiz da cena em 'cena_boneca' precisa ser um CharacterBody2D.")

	# Reserva: boneca simples (retângulo)
	var simples := TeaserBoneca.new()
	simples.name = "Boneca"
	var forma := CollisionShape2D.new()
	var capsula := CapsuleShape2D.new()
	capsula.radius = 8.0
	capsula.height = 36.0
	forma.shape = capsula
	forma.position = Vector2(0.0, -18.0)
	simples.add_child(forma)
	var corpo := ColorRect.new()
	corpo.color = Color(0.9, 0.75, 0.85)
	corpo.position = Vector2(-8.0, -36.0)
	corpo.size = Vector2(16.0, 36.0)
	simples.add_child(corpo)
	return simples

# --- TRANSFORMAÇÃO: luz vira boneca ---
func _ao_entrar_zona_transformacao(area: Area2D) -> void:
	if fase != Fase.VOO or area != fada:
		return
	fase = Fase.TRANSFORMANDO
	_sequencia_transformacao()

func _sequencia_transformacao() -> void:
	await get_tree().create_timer(atraso_transformacao).timeout

	if marcador:
		var tm := create_tween()
		tm.tween_property(marcador, "modulate:a", 0.0, duracao_transformacao)

	fada.desaparecer(duracao_transformacao)

	# A cena Player entra no lugar da luz e cai até o chão
	boneca = _criar_boneca()
	boneca.modulate = Color(1.0, 1.0, 1.0, 0.0)
	add_child(boneca)
	boneca.global_position = fada.global_position + deslocamento_pouso
	if zona_portao:
		zona_portao.collision_mask |= boneca.collision_layer # garante que a zona enxerga a boneca

	# Brilhos temporários: explosão na transformação + rastro que vai sumindo
	brilhos_boneca = TeaserBrilhos.new()
	brilhos_boneca.name = "TeaserBrilhos"
	boneca.add_child(brilhos_boneca)
	brilhos_boneca.iniciar(cor_brilhos, duracao_brilhos)
	brilhos_boneca.explodir()

	var ta := create_tween()
	ta.tween_property(boneca, "modulate:a", 1.0, duracao_transformacao)

	await get_tree().create_timer(duracao_transformacao).timeout
	fase = Fase.CAMINHANDO

# --- PORTÃO: abre enquanto ela entra, a luz cobre a tela ---
func _ao_entrar_zona_portao(body: Node2D) -> void:
	if fase != Fase.CAMINHANDO or body != boneca:
		return
	fase = Fase.PORTAO_ABRINDO
	_sequencia_portao()

func _sequencia_portao() -> void:
	# A boneca passa a andar sozinha até o PontoEntrada enquanto o portão abre
	andando_auto = true
	if portao:
		await portao.abrir()
	fase = Fase.ENTRANDO

	# A luz cresce, a boneca é engolida por ela e a tela vai ficando branca
	if portao:
		portao.inundar(duracao_entrada)
	var tb := create_tween()
	tb.tween_property(boneca, "modulate", Color(1.8, 1.8, 1.8, 0.0), duracao_entrada)
	var tw := create_tween()
	tw.tween_interval(atraso_branco)
	tw.tween_property(branco, "modulate:a", 1.0, duracao_branco)
	await tw.finished

	await get_tree().create_timer(tempo_branco_parado).timeout
	_ir_para_demonstracao()

# Anda segurando a "tecla" de direção, assim funciona com o Player sem alterar o script dele
func _andar_automatico() -> void:
	if not andando_auto or boneca == null or ponto_entrada == null:
		return
	var dx: float = ponto_entrada.global_position.x - boneca.global_position.x
	if absf(dx) < 6.0:
		andando_auto = false
		_soltar_teclas()
		return
	Input.action_press(_acao_horizontal(dx > 0.0), 1.0)
	Input.action_release(_acao_horizontal(dx <= 0.0))

func _acao_horizontal(direita: bool) -> String:
	if direita:
		return "mover_direita" if InputMap.has_action("mover_direita") else "ui_right"
	return "mover_esquerda" if InputMap.has_action("mover_esquerda") else "ui_left"

func _soltar_teclas() -> void:
	Input.action_release(_acao_horizontal(true))
	Input.action_release(_acao_horizontal(false))

# --- TRANSIÇÃO PARA A CENA DE DEMONSTRAÇÃO ---
func _criar_camada_branco() -> void:
	camada_branco = CanvasLayer.new()
	camada_branco.layer = 100
	branco = ColorRect.new()
	branco.color = Color.WHITE
	branco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	branco.set_anchors_preset(Control.PRESET_FULL_RECT)
	branco.modulate.a = 0.0
	camada_branco.add_child(branco)
	add_child(camada_branco)

func _ir_para_demonstracao() -> void:
	fase = Fase.FINAL
	_soltar_teclas()
	if cena_demonstracao == "" or not ResourceLoader.exists(cena_demonstracao):
		push_warning("Teaser: defina 'cena_demonstracao' no inspector do nó Teaser para ir à cena de Demonstração (a tela fica branca até lá).")
		return

	# O branco sobrevive à troca de cena e some aos poucos já na Demonstração
	camada_branco.reparent(get_tree().root)

	var packed: PackedScene = null
	var estado := ResourceLoader.load_threaded_get_status(cena_demonstracao)
	if estado == ResourceLoader.THREAD_LOAD_LOADED or estado == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		packed = ResourceLoader.load_threaded_get(cena_demonstracao) as PackedScene
	if packed != null:
		get_tree().change_scene_to_packed(packed)
	else:
		get_tree().change_scene_to_file(cena_demonstracao)

	var tf := camada_branco.create_tween()
	tf.tween_interval(0.3)
	tf.tween_property(branco, "modulate:a", 0.0, duracao_fade_demonstracao)
	tf.tween_callback(camada_branco.queue_free)
