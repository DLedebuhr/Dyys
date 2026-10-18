class_name Portao
extends Node2D
## Portão reutilizável: abre quando o jogador chega perto, e ao entrar troca de cena.
##
## Camadas: em repouso o portão NÃO usa z_index, então ele se ordena com o jogador
## como qualquer objeto (ordem na árvore ou Y-Sort). Só na hora de entrar, o script
## empilha as camadas (o jogador fica em z_index = 0):
##   Fundo -10 | Interior -9 | Adorno -8 | JOGADOR 0 | Penumbra +1 | Portas +2
## (com adorno_na_frente ligado, o Adorno vai para +3 e também cobre o jogador)
##
## Requisitos: o jogador precisa estar no grupo "jogador" OU ser arrastado para o campo
## "Jogador" do Inspector. No modo POSICAO não precisa de colisão nenhuma.

signal abriu
signal fechou
signal entrou(jogador: Node2D)

enum Modo { DESLIZAR, GIRAR }
enum Deteccao { POSICAO, AREA }

@export_group("Detecção")
## POSICAO: funciona com qualquer Node2D (Sprite2D, CharacterBody2D...), usa o tamanho das zonas.
## AREA: usa os sinais das Area2D (só detecta corpos físicos na layer/mask certa).
@export var deteccao: Deteccao = Deteccao.POSICAO
## Opcional: arraste o nó do jogador aqui. Se vazio, usa o 1º nó do grupo abaixo.
@export var jogador: Node2D
@export var grupo_jogador: StringName = &"jogador"

@export_group("Destino")
@export_file("*.tscn") var cena_destino: String = ""
@export var exige_interacao: bool = false          # true = precisa apertar a ação para entrar
@export var acao_interagir: StringName = &"ui_accept"

@export_group("Abertura")
@export var modo: Modo = Modo.DESLIZAR
@export var duracao: float = 0.6
@export var deslize_px: float = 50.0               # modo DESLIZAR: quanto cada porta corre (menor = a folha fica mais sobre o vão)
@export_range(0.0, 1.0) var escala_aberta: float = 0.15  # modo GIRAR: largura final da porta
@export var animacao_abrir: StringName = &"abrir"  # se existir um AnimationPlayer com isso, ele manda
@export var animacao_fechar: StringName = &"fechar"
@export var fechar_ao_sair: bool = true

@export_group("Entrada")
@export var travar_jogador: bool = false           # true = tira o controle do jogador durante a entrada
@export var andar_sozinho: bool = false           # true = o script faz a boneca andar até dentro (senão você anda)
@export var manter_altura: bool = true             # true = anda só no chão (side-scroller); false = vai até o PontoEntrada (top-down)
@export var velocidade_andar: float = 60.0         # px/s da caminhada para dentro
@export var andar_alem_px: float = 70.0            # quanto ela segue andando depois do centro, passando por trás da porta
@export var arte_olha_para_direita: bool = true    # para virar o sprite na direção da caminhada
@export var duracao_entrada: float = 1.2           # tempo mínimo da entrada (a luz se guia por ele)
@export var animacao_andar: StringName = &"andar"  # animação do AnimatedSprite2D do jogador (se existir)
@export var escala_ao_entrar: float = 1.0          # ex: 0.85 para "afastar" o jogador (visão top-down)
@export var z_jogador: int = 0
@export var adorno_na_frente: bool = false         # false = moldura fica atrás do jogador (só as portas o cobrem); true = moldura também o cobre
@export var duracao_fade: float = 0.5              # luz clareando na cena nova
@export var cor_fade: Color = Color(1.0, 0.97, 0.88)  # mesma cor da luz

@export_group("Luz")
@export var luz_intensidade: float = 0.85          # luz que vaza de dentro ao abrir (nó Interior/Luz)
@export var diametro_luz_final: float = 9000.0     # tamanho final da luz (cobre a tela)
@export var duracao_luz: float = 1.0               # quanto tempo a luz leva para tomar a tela
@export_range(0.0, 1.0) var inicio_luz: float = 0.6  # em que ponto da caminhada a luz começa a crescer
@export var z_luz_inundar: int = 100               # a luz fica por cima de tudo ao inundar

@onready var porta_esq := $PortaEsquerda as Node2D
@onready var porta_dir := $PortaDireita as Node2D
@onready var ponto_entrada := $PontoEntrada as Marker2D
@onready var zona_abrir := $ZonaAbrir as Area2D
@onready var zona_entrada := $ZonaEntrada as Area2D
@onready var _cs_abrir := $ZonaAbrir/CollisionShape2D as CollisionShape2D
@onready var _cs_entrada := $ZonaEntrada/CollisionShape2D as CollisionShape2D
@onready var luz := get_node_or_null("Interior/Luz") as Node2D
@onready var anim := get_node_or_null("AnimationPlayer") as AnimationPlayer

var aberto := false
var _completo := false     # true quando a animação de abrir/fechar terminou
var _entrando := false
var _na_entrada: Node2D = null
var _esq_x0 := 0.0
var _dir_x0 := 0.0
var _tween_portas: Tween
var _tween_luz: Tween
var _avisou := false
var _dir_mov := 0.0       # última direção horizontal em que o jogador andou
var _x_anterior := 0.0


func _ready() -> void:
	_esq_x0 = porta_esq.position.x
	_dir_x0 = porta_dir.position.x
	if luz:
		luz.modulate.a = 0.0
	if deteccao == Deteccao.AREA:
		zona_abrir.body_entered.connect(_ao_entrar_zona_abrir)
		zona_abrir.body_exited.connect(_ao_sair_zona_abrir)
		zona_entrada.body_entered.connect(_ao_entrar_zona_entrada)
		zona_entrada.body_exited.connect(_ao_sair_zona_entrada)
	set_process(deteccao == Deteccao.POSICAO)
	if anim:
		anim.animation_finished.connect(_ao_terminar_anim)
	set_process_unhandled_input(exige_interacao)


# ---------- Gatilhos ----------

func _process(_delta: float) -> void:
	if _entrando:
		return
	var j := _achar_jogador()
	if j == null:
		return
	var p := j.global_position
	if absf(p.x - _x_anterior) > 0.01:
		_dir_mov = signf(p.x - _x_anterior)
	_x_anterior = p.x
	if _dentro(_cs_abrir, p):
		abrir()
	elif fechar_ao_sair:
		fechar()
	var na_entrada := _dentro(_cs_entrada, p)
	_na_entrada = j if na_entrada else null
	if na_entrada and not exige_interacao:
		entrar(j)

func _achar_jogador() -> Node2D:
	if jogador and is_instance_valid(jogador):
		return jogador
	var j := get_tree().get_first_node_in_group(grupo_jogador) as Node2D
	if j == null and not _avisou:
		_avisou = true
		push_warning("Portao: nenhum jogador encontrado. Arraste o jogador para o campo 'Jogador' ou coloque-o no grupo '%s'." % grupo_jogador)
	return j

func _dentro(cs: CollisionShape2D, ponto_global: Vector2) -> bool:
	var forma := cs.shape as RectangleShape2D
	if forma == null:
		return false
	return Rect2(-forma.size / 2.0, forma.size).has_point(cs.to_local(ponto_global))

func _ao_entrar_zona_abrir(corpo: Node2D) -> void:
	if corpo.is_in_group(grupo_jogador):
		abrir()

func _ao_sair_zona_abrir(corpo: Node2D) -> void:
	if corpo.is_in_group(grupo_jogador) and fechar_ao_sair:
		fechar()

func _ao_entrar_zona_entrada(corpo: Node2D) -> void:
	if not corpo.is_in_group(grupo_jogador):
		return
	_na_entrada = corpo
	if not exige_interacao:
		entrar(corpo)

func _ao_sair_zona_entrada(corpo: Node2D) -> void:
	if corpo == _na_entrada:
		_na_entrada = null

func _unhandled_input(event: InputEvent) -> void:
	if _na_entrada and event.is_action_pressed(acao_interagir):
		get_viewport().set_input_as_handled()
		entrar(_na_entrada)


# ---------- Abrir / fechar ----------

func abrir() -> void:
	if aberto:
		return
	aberto = true
	_animar(true)

func fechar() -> void:
	if not aberto or _entrando:
		return
	aberto = false
	_animar(false)

func _animar(abrindo: bool) -> void:
	_completo = false
	_animar_luz(abrindo)
	if anim and _tocar_animacao(abrindo):
		return
	_animar_portas_por_codigo(abrindo)

func _tocar_animacao(abrindo: bool) -> bool:
	if abrindo:
		if anim.has_animation(animacao_abrir):
			anim.play(animacao_abrir)
			return true
	else:
		if anim.has_animation(animacao_fechar):
			anim.play(animacao_fechar)
			return true
		if anim.has_animation(animacao_abrir):
			anim.play_backwards(animacao_abrir)
			return true
	return false

func _animar_portas_por_codigo(abrindo: bool) -> void:
	if _tween_portas:
		_tween_portas.kill()
	var k := 1.0 if abrindo else 0.0
	var t := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_tween_portas = t
	match modo:
		Modo.DESLIZAR:
			t.tween_property(porta_esq, "position:x", _esq_x0 - deslize_px * k, duracao)
			t.tween_property(porta_dir, "position:x", _dir_x0 + deslize_px * k, duracao)
		Modo.GIRAR:
			var e := lerpf(1.0, escala_aberta, k)
			t.tween_property(porta_esq, "scale:x", e, duracao)
			t.tween_property(porta_dir, "scale:x", e, duracao)
	t.chain().tween_callback(_terminou)

func _animar_luz(abrindo: bool) -> void:
	if luz == null:
		return
	if _tween_luz:
		_tween_luz.kill()
	_tween_luz = create_tween()
	_tween_luz.tween_property(luz, "modulate:a", luz_intensidade if abrindo else 0.0, duracao)

func _ao_terminar_anim(_nome: StringName) -> void:
	_terminou()

func _terminou() -> void:
	_completo = true
	if aberto:
		abriu.emit()
	else:
		fechou.emit()


# ---------- Entrar ----------

func entrar(jogador: Node2D) -> void:
	if _entrando:
		return
	_entrando = true
	if travar_jogador or andar_sozinho:   # andar sozinho exige travar, senão o seu script briga com o movimento
		_travar(jogador, true)
	abrir()
	if not _completo:
		await abriu

	_empilhar_camadas()
	jogador.z_index = z_jogador   # fica entre o Interior e as portas/Adorno
	var tempo := duracao_entrada
	var tw: Tween = null

	# A Penumbra (escuro do vão) sai de cena para a luz poder tomar conta.
	var penumbra := get_node_or_null("Penumbra") as CanvasItem
	if penumbra:
		create_tween().tween_property(penumbra, "modulate:a", 0.0, tempo * 0.3)

	if andar_sozinho:
		# O script caminha com a boneca em linha reta, sem sair do chão.
		var destino := ponto_entrada.global_position
		if manter_altura:
			destino.y = jogador.global_position.y
			var dir := _dir_mov
			if dir == 0.0:
				dir = signf(destino.x - jogador.global_position.x)
			if dir == 0.0:
				dir = 1.0
			destino.x += dir * andar_alem_px
			_virar(jogador, dir)
		var dist := jogador.global_position.distance_to(destino)
		tempo = maxf(duracao_entrada, dist / maxf(velocidade_andar, 1.0))
		_andar(jogador, true)
		tw = create_tween().set_parallel(true)
		tw.tween_property(jogador, "global_position", destino, tempo)
		if not is_equal_approx(escala_ao_entrar, 1.0):
			tw.tween_property(jogador, "scale", jogador.scale * escala_ao_entrar, tempo)

	# A luz de dentro cresce até cobrir a tela (você continua andando enquanto isso, se não travou).
	var tw_luz := _inundar(tempo * inicio_luz)

	if tw:
		await tw.finished
	if tw_luz:
		if tw_luz.is_running():
			await tw_luz.finished
	else:
		await get_tree().create_timer(tempo).timeout

	entrou.emit(jogador)
	if cena_destino != "":
		_trocar_cena()

func _virar(jogador: Node, dir_x: float) -> void:
	var sprite := jogador.find_child("AnimatedSprite2D", true, false) as AnimatedSprite2D
	var olhando_direita := dir_x > 0.0
	if sprite:
		sprite.flip_h = (not olhando_direita) if arte_olha_para_direita else olhando_direita
		return
	var sprite2 := jogador.find_child("Sprite2D", true, false) as Sprite2D
	if sprite2:
		sprite2.flip_h = (not olhando_direita) if arte_olha_para_direita else olhando_direita

func _andar(jogador: Node, andando: bool) -> void:
	if animacao_andar == &"":
		return
	var sprite := jogador.find_child("AnimatedSprite2D", true, false) as AnimatedSprite2D
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation(animacao_andar):
		if andando:
			sprite.play(animacao_andar)
		else:
			sprite.stop()

# A luz cresce a partir do vão até cobrir a tela inteira.
func _inundar(atraso: float) -> Tween:
	if luz == null:
		return null
	if _tween_luz:
		_tween_luz.kill()
	var largura := 256.0
	var tex := luz.get("texture") as Texture2D
	if tex:
		largura = float(tex.get_width())
	var esc := diametro_luz_final / largura
	var t := create_tween().set_parallel(true)
	t.tween_callback(func() -> void: luz.z_index = z_luz_inundar).set_delay(atraso)
	t.tween_property(luz, "scale", Vector2(esc, esc), duracao_luz) \
			.set_delay(atraso).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	t.tween_property(luz, "modulate:a", 1.0, duracao_luz * 0.5).set_delay(atraso)
	_tween_luz = t
	return t

func _empilhar_camadas() -> void:
	$Fundo.z_index = -10
	$Interior.z_index = -9
	$Penumbra.z_index = 1
	porta_esq.z_index = 2
	porta_dir.z_index = 2
	$Adorno.z_index = 3 if adorno_na_frente else -8   # -8: acima do Interior, atrás do jogador

func _travar(jogador: Node, travar: bool) -> void:
	# Se o seu jogador tiver um método travar_controle(bool), ele é usado.
	if jogador.has_method("travar_controle"):
		jogador.call("travar_controle", travar)
	else:
		jogador.set_physics_process(not travar)
		jogador.set_process_unhandled_input(not travar)

func _trocar_cena() -> void:
	# O overlay vive na raiz da árvore, então sobrevive à troca de cena.
	# Se a luz já cobriu a tela, ele começa branco e só clareia na cena nova.
	var ja_branco := luz != null
	var arvore := get_tree()
	var camada := CanvasLayer.new()
	camada.layer = 128
	var rect := ColorRect.new()
	rect.color = Color(cor_fade, 1.0 if ja_branco else 0.0)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	camada.add_child(rect)
	arvore.root.add_child(camada)
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)

	var tw := camada.create_tween()
	if not ja_branco:
		tw.tween_property(rect, "color:a", 1.0, duracao_fade)
	tw.tween_callback(arvore.change_scene_to_file.bind(cena_destino))
	tw.tween_interval(0.25)
	tw.tween_property(rect, "color:a", 0.0, duracao_fade)
	tw.tween_callback(camada.queue_free)
