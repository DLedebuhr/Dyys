extends CanvasLayer
## Árvore: Tela/{Fundo, Elementos, Demonstracao/{Textura, Video}, Fechar}.
signal fechada

@export_group("Cadastro das habilidades")
@export var conteudos: Array[OpheliaDadosAjudaHabilidade] = []
@export_group("Comportamento")
@export var acao_fechar: StringName = &"ControleFecharAjuda"
@export_range(0.0, 5.0, 0.1) var tempo_minimo_aberta: float = 0.5
@export_group("Aparecer e desaparecer")
@export_range(0.1, 2.0, 0.05) var duracao_entrada: float = 0.45
@export_range(0.1, 2.0, 0.05) var duracao_saida: float = 0.25
@export_range(0.0, 0.5, 0.01) var atraso_elementos: float = 0.10
@export_range(0.1, 1.0, 0.01) var escala_inicial: float = 0.96

@onready var tela: Control = $Tela
@onready var fundo: ColorRect = $Tela/Fundo
@onready var imagem_elementos: TextureRect = $Tela/Elementos
@onready var area_demo: Control = $Tela/Demonstracao
@onready var imagem_demo: TextureRect = $Tela/Demonstracao/Textura
@onready var player_video: VideoStreamPlayer = $Tela/Demonstracao/Video
@onready var botao_fechar: BaseButton = $Tela/Fechar

var aberta: bool = false
var _entrando: bool = false
var _fechando: bool = false
var _pausa_propria: bool = false
var _tempo_aberta: float = 0.0
var _transicao: Tween
var _conteudos: Array[Control] = []
var _escalas: Array[Vector2] = []
var _alphas: Array[float] = []
var _alpha_fundo: float = 1.0
var _alpha_botao: float = 1.0
var _selecionado: OpheliaDadosAjudaHabilidade
var habilidade_selecionada: StringName = &""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	# O fundo é fixo: nunca recebe escala nem deslocamento da transição.
	tela.scale = Vector2.ONE
	tela.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Corrige a escala e os offsets exagerados do Video da cena enviada.
	player_video.expand = true
	imagem_demo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	imagem_demo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	imagem_demo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_conteudos = [imagem_elementos, area_demo]
	for node in _conteudos:
		_escalas.append(node.scale)
		_alphas.append(node.modulate.a)
	_alpha_fundo = fundo.modulate.a
	_alpha_botao = botao_fechar.modulate.a
	tela.resized.connect(_centralizar_pivos)
	imagem_elementos.resized.connect(_centralizar_pivos)
	area_demo.resized.connect(_centralizar_pivos)
	_centralizar_pivos()
	botao_fechar.pressed.connect(fechar)
	player_video.finished.connect(_repetir_video)
	player_video.stop()
	tela.hide()
	set_process(false)

func abrir(pausar_jogo: bool = true) -> bool:
	if aberta:
		return false
	_cancelar_tween()
	if _selecionado == null:
		push_warning("TelaHelpHabilidade: selecione o conteúdo com configurar_habilidade() antes de abrir.")
		return false
	# Não reutiliza imagens ou vídeos da habilidade anterior nem os placeholders da cena.
	imagem_elementos.texture = _selecionado.elementos
	imagem_demo.texture = _selecionado.demonstracao
	player_video.stream = _selecionado.video
	player_video.visible = _selecionado.video != null
	imagem_demo.visible = _selecionado.video == null and _selecionado.demonstracao != null
	area_demo.visible = player_video.visible or imagem_demo.visible
	player_video.paused = false
	_pausa_propria = pausar_jogo and not get_tree().paused
	if _pausa_propria:
		get_tree().paused = true
	aberta = true
	_entrando = true
	_fechando = false
	_tempo_aberta = 0.0
	botao_fechar.disabled = true
	fundo.modulate.a = 0.0
	botao_fechar.modulate.a = 0.0
	_centralizar_pivos()
	for i in range(_conteudos.size()):
		_conteudos[i].modulate.a = 0.0
		_conteudos[i].scale = _escalas[i] * escala_inicial
	tela.show()
	_transicao = create_tween().set_parallel(true)
	_transicao.tween_property(fundo, "modulate:a", _alpha_fundo, duracao_entrada).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	for i in range(_conteudos.size()):
		_transicao.tween_property(_conteudos[i], "modulate:a", _alphas[i], duracao_entrada).set_delay(atraso_elementos).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_transicao.tween_property(_conteudos[i], "scale", _escalas[i], duracao_entrada).set_delay(atraso_elementos).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_transicao.tween_property(botao_fechar, "modulate:a", _alpha_botao, duracao_entrada).set_delay(atraso_elementos)
	_transicao.chain().tween_callback(_concluir_entrada)
	set_process(true)
	return true

func _concluir_entrada() -> void:
	_entrando = false
	if player_video.stream != null:
		player_video.play()

func _process(delta: float) -> void:
	_tempo_aberta += delta
	if not _entrando and not _fechando and botao_fechar.disabled and _tempo_aberta >= tempo_minimo_aberta:
		botao_fechar.disabled = false
		botao_fechar.grab_focus()

func _input(event: InputEvent) -> void:
	if not aberta:
		return
	if event is InputEventKey and event.echo:
		get_viewport().set_input_as_handled()
		return
	if InputMap.has_action(acao_fechar) and event.is_action_pressed(acao_fechar):
		get_viewport().set_input_as_handled()
		fechar()
	elif event is InputEventKey or event is InputEventJoypadButton:
		get_viewport().set_input_as_handled()

func fechar() -> void:
	if not aberta or _entrando or _fechando or _tempo_aberta < tempo_minimo_aberta:
		return
	_cancelar_tween()
	_fechando = true
	botao_fechar.disabled = true
	_transicao = create_tween().set_parallel(true)
	for i in range(_conteudos.size()):
		_transicao.tween_property(_conteudos[i], "modulate:a", 0.0, duracao_saida).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		_transicao.tween_property(_conteudos[i], "scale", _escalas[i] * escala_inicial, duracao_saida).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_transicao.tween_property(botao_fechar, "modulate:a", 0.0, duracao_saida)
	_transicao.tween_property(fundo, "modulate:a", 0.0, duracao_saida).set_delay(atraso_elementos)
	_transicao.chain().tween_callback(_concluir_fechamento)

func _concluir_fechamento() -> void:
	aberta = false
	_fechando = false
	tela.hide()
	player_video.stop()
	for i in range(_conteudos.size()):
		_conteudos[i].scale = _escalas[i]
		_conteudos[i].modulate.a = _alphas[i]
	fundo.modulate.a = _alpha_fundo
	botao_fechar.modulate.a = _alpha_botao
	set_process(false)
	if _pausa_propria:
		get_tree().paused = false
	_pausa_propria = false
	fechada.emit()

func _centralizar_pivos() -> void:
	# Os irmãos expandem em torno do mesmo centro, mantendo o alinhamento entre si.
	var centro: Vector2 = tela.size * 0.5
	for node in _conteudos:
		node.pivot_offset = centro - node.position

func _repetir_video() -> void:
	if aberta and not _fechando and player_video.stream != null:
		player_video.play()

func _cancelar_tween() -> void:
	if _transicao != null and _transicao.is_valid():
		_transicao.kill()

func _exit_tree() -> void:
	if _pausa_propria:
		get_tree().paused = false

func configurar_habilidade(id: StringName, personalizado: OpheliaDadosAjudaHabilidade = null) -> bool:
	if aberta:
		return false
	_selecionado = null
	habilidade_selecionada = &""
	if personalizado != null:
		if StringName(personalizado.habilidade) != id:
			push_warning("Ajuda personalizada: o campo Habilidade deve ser igual ao do interativo.")
			return false
		_selecionado = personalizado
	else:
		for conteudo in conteudos:
			if conteudo != null and StringName(conteudo.habilidade) == id:
				if _selecionado != null:
					_selecionado = null
					push_warning("TelaHelpHabilidade: há dois conteúdos cadastrados para '%s'." % id)
					return false
				_selecionado = conteudo
	if _selecionado == null:
		push_warning("TelaHelpHabilidade: cadastre o conteúdo de '%s' no array Conteudos da cena base ou em Ajuda Personalizada no interativo." % id)
		return false
	if _selecionado.elementos == null:
		_selecionado = null
		push_warning("TelaHelpHabilidade: falta a imagem Elementos de '%s'." % id)
		return false
	habilidade_selecionada = id
	return true
