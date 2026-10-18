extends Control

const CHEAT_CODE: String = "ophelia"
const TEMPO_LIMITE_DIGITACAO: float = 5.0

@export var slots: Array[SlotSave] = []

# Referência aos enfeites que agora são TextureButtons
@onready var enfeite_revelar: TextureButton = $HBoxContainer2/EnfeiteEsquerda
@onready var enfeite_god_mode: TextureButton = $HBoxContainer2/EnfeiteDireita

var modo_deus_ativo: bool = false
var aguardando_cheat: bool = false
var texto_digitado: String = ""
var tempo_restante: float = 0.0

func _ready() -> void:
	# Configura o Enfeite da Esquerda (Preview da Animação)
	if enfeite_revelar:
		enfeite_revelar.mouse_entered.connect(_on_enfeite_revelar_mouse_entered)
		enfeite_revelar.mouse_exited.connect(_on_enfeite_revelar_mouse_exited)

	# Configura o Enfeite da Direita (Gatilho do Cheat "ophelia")
	if enfeite_god_mode:
		enfeite_god_mode.pressed.connect(_on_enfeite_god_mode_pressed)

func _process(delta: float) -> void:
	if aguardando_cheat:
		tempo_restante -= delta
		if tempo_restante <= 0.0:
			_cancelar_espera_cheat()

# --- REVELAÇÃO DA ARTE (ENFEITE ESQUERDO) ---

func _on_enfeite_revelar_mouse_entered() -> void:
	# Ao passar o mouse no enfeite, todos os vasos animam do 0 ao 6
	for slot in slots:
		if slot:
			slot.animar_preview_progressivo()

func _on_enfeite_revelar_mouse_exited() -> void:
	# Ao tirar o mouse, restaura a arte real guardada no save
	for slot in slots:
		if slot:
			slot.restaurar_exibicao_real()

# --- MODO DEUS / CHEAT (ENFEITE DIREITO) ---

func _on_enfeite_god_mode_pressed() -> void:
	if modo_deus_ativo:
		desativar_modo_deus()
		return

	aguardando_cheat = true
	texto_digitado = ""
	tempo_restante = TEMPO_LIMITE_DIGITACAO

func _unhandled_input(event: InputEvent) -> void:
	if not aguardando_cheat:
		return

	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		var caractere: String = OS.get_keycode_string(event.keycode).to_lower()
		
		if caractere.length() == 1 and caractere.is_subsequence_of("abcdefghijklmnopqrstuvwxyz"):
			texto_digitado += caractere
			
			if texto_digitado.length() > CHEAT_CODE.length():
				texto_digitado = texto_digitado.substr(texto_digitado.length() - CHEAT_CODE.length())

			if texto_digitado == CHEAT_CODE:
				ativar_modo_deus()

func ativar_modo_deus() -> void:
	modo_deus_ativo = true
	aguardando_cheat = false
	texto_digitado = ""
	print("Modo Deus ativado pelo Enfeite Direito!")
	
	# Destaca suavemente o enfeite direito para indicar que o modo está ativo
	if enfeite_god_mode:
		enfeite_god_mode.modulate = Color(1.8, 1.6, 0.4)

func desativar_modo_deus() -> void:
	modo_deus_ativo = false
	_cancelar_espera_cheat()
	print("Modo Deus desativado.")
	
	if enfeite_god_mode:
		enfeite_god_mode.modulate = Color.WHITE

func _cancelar_espera_cheat() -> void:
	aguardando_cheat = false
	texto_digitado = ""
