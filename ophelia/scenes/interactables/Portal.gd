class_name Portal
extends Node2D
## Portão reutilizável: abre quando o jogador chega perto, e ao entrar troca de cena
## com um clarão que nasce na porta.
##
## Camadas: em repouso o portão NÃO usa z_index, então ele se ordena com o jogador
## como qualquer objeto (ordem na árvore ou Y-Sort). Só na hora de entrar, o script
## empilha as camadas (o jogador fica em z_index = 0):
##   Fundo -10 | Interior -9 | JOGADOR 0 | Portas (ou MascaraPortas) +2 | Adorno +3 | Gambiarra +4
## (com adorno_na_frente desligado, o Adorno vai para -8, atrás do jogador)
##
## Requisitos: o jogador precisa estar no grupo "jogador" OU ser arrastado para o campo
## "Jogador" do Inspector. No modo POSICAO não precisa de colisão nenhuma.

signal abriu
signal fechou
signal entrou(jogador: Node2D)

enum Modo { DESLIZAR, GIRAR }
enum Deteccao { POSICAO, AREA }

# ---------- Configuração (Inspector) ----------

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
@export var deslize_px: float = 50.0               # modo DESLIZAR: quanto cada porta corre
@export_range(0.0, 1.0) var escala_aberta: float = 0.15  # modo GIRAR: largura final da porta
@export var animacao_abrir: StringName = &"abrir"  # se existir um AnimationPlayer com isso, ele manda
@export var animacao_fechar: StringName = &"fechar"
@export var fechar_ao_sair: bool = true

@export_group("Entrada")
@export var travar_jogador: bool = false           # true = tira o controle do jogador durante a entrada
@export var andar_sozinho: bool = false            # true = o script faz a boneca andar até dentro
@export var manter_altura: bool = true             # true = anda só no chão (side-scroller); false = vai até o PontoEntrada (top-down)
@export var velocidade_andar: float = 60.0         # px/s da caminhada para dentro
@export var andar_alem_px: float = 70.0            # quanto segue andando depois do centro
@export var arte_olha_para_direita: bool = true    # para virar o sprite na direção da caminhada
@export var duracao_entrada: float = 1.2           # tempo da entrada antes de trocar de cena
@export var animacao_andar: StringName = &"andar"  # animação do AnimatedSprite2D do jogador (se existir)
@export var escala_ao_entrar: float = 1.0          # ex: 0.85 para "afastar" o jogador (top-down)

@export_group("Camadas (z_index)")
@export var z_jogador: int = 0
@export var adorno_na_frente: bool = true          # true = moldura na frente do jogador; false = atrás
@export var z_gambiarra: int = 1                   # camada extra "Gambiarra" na hora de entrar

@export_group("Clarão")
@export var cor_clarao: Color = Color(1.0, 0.95, 0.8)
@export var origem_clarao_offset: Vector2 = Vector2.ZERO  # ajuste fino: ex. (0, -40) para subir o centro da luz
@export var duracao_clarao_subida: float = 0.4     # a luz nasce e cresce
@export var duracao_encher: float = 0.25           # o branco cobre 100% da tela
@export var segurar_branco: float = 0.2            # pausa com a tela toda branca ANTES de trocar a cena
@export var duracao_clarao_descida: float = 0.8    # a cena nova aparece de dentro da luz

# ---------- Nós ----------

@onready var porta_esq := find_child("PortaEsquerda", true, false) as Node2D
@onready var porta_dir := find_child("PortaDireita", true, false) as Node2D
@onready var ponto_entrada := find_child("PontoEntrada", true, false) as Marker2D   # opcional (só em andar_sozinho)
@onready var zona_abrir := $ZonaAbrir as Area2D
@onready var zona_entrada := $ZonaEntrada as Area2D
@onready var _cs_abrir := $ZonaAbrir/CollisionShape2D as CollisionShape2D
@onready var _cs_entrada := $ZonaEntrada/CollisionShape2D as CollisionShape2D
@onready var anim := get_node_or_null("AnimationPlayer") as AnimationPlayer

# ---------- Estado ----------

var aberto := false
var _completo := false     # true quando a animação de abrir/fechar terminou
var _entrando := false
var _na_entrada: Node2D = null
var _esq_x0 := 0.0
var _dir_x0 := 0.0
var _tween_portas: Tween
var _avisou := false
var _dir_mov := 0.0        # última direção horizontal em que o jogador andou
var _x_anterior := 0.0


func _ready() -> void:
	_esq_x0 = porta_esq.position.x
	_dir_x0 = porta_dir.position.x
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
		push_warning("Portal: nenhum jogador encontrado. Arraste o jogador para o campo 'Jogador' ou coloque-o no grupo '%s'." % grupo_jogador)
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

func _ao_terminar_anim(_nome: StringName) -> void:
	_terminou()

func _terminou() -> void:
	_completo = true
	if aberto:
		abriu.emit()
	else:
		fechou.emit()


# ---------- Entrar ----------

func entrar(quem: Node2D) -> void:
	if _entrando:
		return
	_entrando = true
	if travar_jogador or andar_sozinho:   # andar sozinho exige travar, senão o seu script briga com o movimento
		_travar(quem, true)
	abrir()
	if not _completo:
		await abriu

	_empilhar_camadas()
	quem.z_index = z_jogador   # fica entre o Interior e as portas/Adorno
	var tempo := duracao_entrada
	var tw: Tween = null

	if andar_sozinho:
		# O script caminha com a boneca em linha reta, sem sair do chão.
		var destino := ponto_entrada.global_position if ponto_entrada else global_position
		if manter_altura:
			destino.y = quem.global_position.y
			var dir := _dir_mov
			if dir == 0.0:
				dir = signf(destino.x - quem.global_position.x)
			if dir == 0.0:
				dir = 1.0
			destino.x += dir * andar_alem_px
			_virar(quem, dir)
		var dist := quem.global_position.distance_to(destino)
		tempo = maxf(duracao_entrada, dist / maxf(velocidade_andar, 1.0))
		_andar(quem, true)
		tw = create_tween().set_parallel(true)
		tw.tween_property(quem, "global_position", destino, tempo)
		if not is_equal_approx(escala_ao_entrar, 1.0):
			tw.tween_property(quem, "scale", quem.scale * escala_ao_entrar, tempo)

	# Espera a entrada acontecer (você continua com o controle, se não travou).
	if tw:
		await tw.finished
	else:
		await get_tree().create_timer(tempo).timeout

	entrou.emit(quem)
	if cena_destino != "":
		_trocar_cena()

func _virar(quem: Node, dir_x: float) -> void:
	var olhando_direita := dir_x > 0.0
	var flip := (not olhando_direita) if arte_olha_para_direita else olhando_direita
	var sprite := quem.find_child("AnimatedSprite2D", true, false) as AnimatedSprite2D
	if sprite:
		sprite.flip_h = flip
		return
	var sprite2 := quem.find_child("Sprite2D", true, false) as Sprite2D
	if sprite2:
		sprite2.flip_h = flip

func _andar(quem: Node, andando: bool) -> void:
	if animacao_andar == &"":
		return
	var sprite := quem.find_child("AnimatedSprite2D", true, false) as AnimatedSprite2D
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation(animacao_andar):
		if andando:
			sprite.play(animacao_andar)
		else:
			sprite.stop()

func _empilhar_camadas() -> void:
	_definir_z("Fundo", -10)
	_definir_z("Interior", -9)
	# Se existir o nó "MascaraPortas" (com Clip Children ligado e as portas dentro), é ele que
	# sobe para a frente do jogador. As portas ficam recortadas pelo vão.
	var mascara := find_child("MascaraPortas", true, false) as CanvasItem
	if mascara:
		mascara.z_index = 2
		porta_esq.z_index = 0
		porta_dir.z_index = 0
	else:
		porta_esq.z_index = 2
		porta_dir.z_index = 2
	_definir_z("Adorno", 3 if adorno_na_frente else -8)   # -8: acima do Interior, atrás do jogador
	# Camada extra (opcional): pode estar em qualquer lugar da cena
	var gambiarra := find_child("Gambiarra", true, false) as CanvasItem
	if gambiarra:
		gambiarra.z_index = z_gambiarra

func _definir_z(nome: String, valor: int) -> void:
	var no := get_node_or_null(nome) as CanvasItem
	if no:
		no.z_index = valor

func _travar(quem: Node, travar: bool) -> void:
	# Se o seu jogador tiver um método travar_controle(bool), ele é usado.
	if quem.has_method("travar_controle"):
		quem.call("travar_controle", travar)
	else:
		quem.set_physics_process(not travar)
		quem.set_process_unhandled_input(not travar)


# ---------- Troca de cena com clarão ----------

func _trocar_cena() -> void:
	# O overlay vive na raiz da árvore, então sobrevive à troca de cena.
	var arvore := get_tree()
	var camada := CanvasLayer.new()
	camada.layer = 128
	arvore.root.add_child(camada)

	var tela := get_viewport_rect().size
	var origem := get_global_transform_with_canvas().origin + origem_clarao_offset

	# Cor cheia: garante que a tela fica 100% coberta
	var cheio := ColorRect.new()
	cheio.color = Color(cor_clarao, 0.0)
	cheio.mouse_filter = Control.MOUSE_FILTER_IGNORE
	camada.add_child(cheio)
	cheio.set_anchors_preset(Control.PRESET_FULL_RECT)

	# Bola de luz: gradiente radial, opaco no centro e transparente na borda
	# O miolo (até 50% do raio) fica 100% opaco; só a borda externa faz o degradê.
	var grad := Gradient.new()
	grad.set_color(0, Color(cor_clarao, 1.0))
	grad.set_color(1, Color(cor_clarao, 0.0))
	grad.add_point(0.5, Color(cor_clarao, 1.0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 256
	tex.height = 256

	var brilho := TextureRect.new()
	brilho.texture = tex
	brilho.mouse_filter = Control.MOUSE_FILTER_IGNORE
	brilho.size = Vector2(256, 256)
	brilho.pivot_offset = brilho.size / 2.0
	brilho.position = origem - brilho.size / 2.0
	brilho.scale = Vector2.ONE * 0.2
	brilho.modulate.a = 0.0
	camada.add_child(brilho)

	# O miolo opaco tem raio de 64 px (metade do raio de 128 px da textura).
	# A escala precisa fazer ESSE miolo passar do canto mais distante da tela,
	# senão a borda transparente do degradê aparece dentro da tela.
	var cantos := [Vector2.ZERO, Vector2(tela.x, 0), Vector2(0, tela.y), tela]
	var maior := 0.0
	for c in cantos:
		maior = maxf(maior, origem.distance_to(c))
	var escala_final := (maior / 64.0) * 1.3

	var tw := camada.create_tween()

	# 1) A luz nasce e cresce
	tw.tween_property(brilho, "scale", Vector2.ONE * escala_final, duracao_clarao_subida)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(brilho, "modulate:a", 1.0, duracao_clarao_subida * 0.5)

	# 2) Só depois, o branco total cobre a tela inteira
	tw.tween_property(cheio, "color:a", 1.0, duracao_encher)

	# 3) Segura a tela toda branca e SÓ ENTÃO troca a cena
	tw.tween_interval(segurar_branco)
	tw.tween_callback(arvore.change_scene_to_file.bind(cena_destino))
	tw.tween_interval(0.15)

	# 4) A cena nova aparece de dentro da luz
	tw.tween_property(cheio, "color:a", 0.0, duracao_clarao_descida)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(brilho, "modulate:a", 0.0, duracao_clarao_descida)
	tw.tween_callback(camada.queue_free)
