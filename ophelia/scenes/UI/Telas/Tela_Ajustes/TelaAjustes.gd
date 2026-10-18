extends Control

# Altere para o caminho exato da sua cena de Menu Principal
const CENA_MENU_PRINCIPAL := "res://scenes/ui/menus/menu_principal/MenuPrincipal.tscn"

# Substitua pelo caminho do seu botão de voltar na árvore de nós
@onready var botao_voltar: TextureButton = $Voltar

func _ready() -> void:
	# Efeito de Entrada (Fade In) dos novos elementos ao carregar a tela
	modulate.a = 0.0
	var fade_in = create_tween()
	fade_in.tween_property(self, "modulate:a", 1.0, 0.5)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)

	if botao_voltar:
		botao_voltar.pressed.connect(_on_botao_voltar_pressed)

func _on_botao_voltar_pressed() -> void:
	# Efeito de Saída (Fade Out) ao clicar em Voltar
	var fade_out = create_tween()
	fade_out.tween_property(self, "modulate:a", 0.0, 0.5)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN)
	
	fade_out.finished.connect(func():
		get_tree().change_scene_to_file(CENA_MENU_PRINCIPAL)
	)
