extends Control

const CENA_AJUSTES := "res://scenes/ui/menus/menu_ajustes/MenuAjustes.tscn" # Confirme o seu caminho

@onready var botao_ajustes: TextureButton = $VBoxContainer/HBoxContainer/Ajustes # Confirme a hierarquia

func _ready() -> void:
	# Efeito de Entrada (Fade In): começa invisível e surge suavemente
	modulate.a = 0.0
	var fade_in = create_tween()
	fade_in.tween_property(self, "modulate:a", 1.0, 0.5)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)

	if botao_ajustes:
		botao_ajustes.pressed.connect(_on_botao_ajustes_pressed)

func _on_botao_ajustes_pressed() -> void:
	# Efeito de Saída (Fade Out): os elementos somem antes de trocar a tela
	var fade_out = create_tween()
	fade_out.tween_property(self, "modulate:a", 0.0, 0.5)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN)
	
	# Aguarda a animação de desaparecimento terminar para carregar a próxima cena
	fade_out.finished.connect(func():
		get_tree().change_scene_to_file(CENA_AJUSTES)
	)
