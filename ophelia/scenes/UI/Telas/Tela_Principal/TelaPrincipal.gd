extends Control
const CENA_SAVE: String = "res://Scenes/UI/Telas/Tela_Save/TelaSelecaoSave.tscn"
const CENA_AJUSTES: String = "res://Scenes/UI/Telas/Tela_Ajustes/TelaAjustes.tscn"
@onready var botao_iniciar: BaseButton = $HBoxContainer/Iniciar
@onready var botao_ajustes: BaseButton = $HBoxContainer/Ajustes
@onready var botao_sair: BaseButton = $HBoxContainer/Sair
var _mudando: bool = false

func _ready() -> void:
	get_tree().paused = false
	FundoParticulas.ativar()
	modulate.a = 0.0
	var entrada: Tween = create_tween()
	entrada.tween_property(self, "modulate:a", 1.0, 0.45)
	botao_iniciar.pressed.connect(_iniciar)
	botao_ajustes.pressed.connect(func(): _trocar_cena(CENA_AJUSTES))
	botao_sair.pressed.connect(func(): get_tree().quit())

func _iniciar() -> void:
	_trocar_cena(CENA_SAVE)

func _trocar_cena(caminho: String) -> void:
	if _mudando:
		return
	_mudando = true
	var t: Tween = create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.30)
	t.finished.connect(func(): get_tree().change_scene_to_file(caminho))
