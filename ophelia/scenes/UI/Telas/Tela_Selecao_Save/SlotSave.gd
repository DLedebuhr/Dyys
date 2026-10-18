extends Control
class_name SlotSave

signal slot_selecionado(slot_index: int, data: SaveData)

@export var slot_index: int = 0
@export var texturas_progresso: Array[Texture2D] = []

@onready var botao_slot: TextureButton = $BotaoSlot
@onready var imagem_progresso: TextureRect = $BotaoSlot/ImagemProgresso
@onready var ponteiro: TextureRect = $BotaoSlot/Ponteiro
@onready var label_numero: Label = find_child("LabelNumero", true, false) as Label

var save_data_atual: SaveData
var tween_animacao: Tween
var tween_ponteiro: Tween

func _ready() -> void:
	# 1. Garante que as imagens filhas ignorem eventos de mouse para não interferir no botão
	if imagem_progresso:
		imagem_progresso.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ponteiro:
		ponteiro.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# 2. Configuração do Label de texto (se existir na cena)
	if label_numero:
		label_numero.text = "SAVE " + str(slot_index + 1)
	
	# 3. Garante estado inicial do ponteiro invisível
	if ponteiro:
		ponteiro.visible = false
		ponteiro.modulate.a = 0.0

	# 4. Conexões do botão principal com o filtro correto
	if botao_slot:
		botao_slot.mouse_filter = Control.MOUSE_FILTER_STOP
		botao_slot.pressed.connect(_on_botao_pressed)
		
		# Eventos de teclado/controle
		botao_slot.focus_entered.connect(_mostrar_ponteiro)
		botao_slot.focus_exited.connect(_esconder_ponteiro)
		
		# Eventos de mouse (hover)
		botao_slot.mouse_entered.connect(_on_mouse_entered)
		botao_slot.mouse_exited.connect(_on_mouse_exited)

	save_data_atual = SaveData.new()
	save_data_atual.slot_index = slot_index
	atualizar_exibicao(save_data_atual)

# --- PROGRESSE E EXIBIÇÃO ---

func atualizar_exibicao(data: SaveData) -> void:
	save_data_atual = data
	var indice: int = clampi(data.progresso_fase, 0, texturas_progresso.size() - 1)
	forcar_preview_textura(indice)

func forcar_preview_textura(indice: int) -> void:
	if texturas_progresso.size() > 0 and imagem_progresso:
		var idx: int = clampi(indice, 0, texturas_progresso.size() - 1)
		imagem_progresso.texture = texturas_progresso[idx]

# --- ANIMAÇÃO SEQUENCIAL (0 até 6) ---

func animar_preview_progressivo(tempo_por_frame: float = 0.08) -> void:
	_parar_animacao_preview()
	var total_texturas := texturas_progresso.size()
	if total_texturas == 0:
		return

	tween_animacao = create_tween()
	for i in range(total_texturas):
		var frame_idx := i
		tween_animacao.tween_callback(func(): forcar_preview_textura(frame_idx))
		tween_animacao.tween_interval(tempo_por_frame)

func restaurar_exibicao_real() -> void:
	_parar_animacao_preview()
	if save_data_atual:
		atualizar_exibicao(save_data_atual)

func _parar_animacao_preview() -> void:
	if tween_animacao and tween_animacao.is_running():
		tween_animacao.kill()

func _on_botao_pressed() -> void:
	_mostrar_ponteiro() # Garante o ponteiro visível ao clicar
	slot_selecionado.emit(slot_index, save_data_atual)

# --- EFEITO DO PONTEIRO (Fix de instabilidade com kill de Tween) ---

func _on_mouse_entered() -> void:
	if botao_slot:
		botao_slot.grab_focus()
	_mostrar_ponteiro()

func _on_mouse_exited() -> void:
	_esconder_ponteiro()

func _mostrar_ponteiro() -> void:
	if not ponteiro:
		return
	
	# Cancela animações passadas para não haver choque
	if tween_ponteiro and tween_ponteiro.is_running():
		tween_ponteiro.kill()

	ponteiro.visible = true
	tween_ponteiro = create_tween()
	tween_ponteiro.tween_property(ponteiro, "modulate:a", 1.0, 0.12)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)

func _esconder_ponteiro() -> void:
	if not ponteiro:
		return

	if tween_ponteiro and tween_ponteiro.is_running():
		tween_ponteiro.kill()

	tween_ponteiro = create_tween()
	tween_ponteiro.tween_property(ponteiro, "modulate:a", 0.0, 0.12)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN)
	tween_ponteiro.finished.connect(func(): if ponteiro: ponteiro.visible = false)
