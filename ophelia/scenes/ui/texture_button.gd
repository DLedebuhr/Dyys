extends TextureButton

# Texturas das imagens do texto do botão
@export var imagem_normal: Texture2D:
	set(val):
		imagem_normal = val
		texture_normal = val

@export var imagem_hover: Texture2D:
	set(val):
		imagem_hover = val
		texture_hover = val

@export var imagem_pressed: Texture2D:
	set(val):
		imagem_pressed = val
		texture_pressed = val

# Nós de áudio
@onready var sound_hover: AudioStreamPlayer = $SoundHover
@onready var sound_click: AudioStreamPlayer = $SoundClick

# Tween de escala do botão
var scale_tween: Tween

func _ready() -> void:
	# Aplica as texturas se forem trocadas no Inspetor
	if imagem_normal: texture_normal = imagem_normal
	if imagem_hover: texture_hover = imagem_hover
	if imagem_pressed: texture_pressed = imagem_pressed

	# Centraliza o pivô do botão para a escala ocorrer a partir do centro
	pivot_offset = size / 2.0
	item_rect_changed.connect(func(): pivot_offset = size / 2.0)

	# Conecta os sinais de mouse
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	pressed.connect(_on_pressed)

func _on_mouse_entered() -> void:
	# 🔊 Toca o som de hover
	if sound_hover and sound_hover.stream:
		sound_hover.stop()
		sound_hover.play()

	# Animação de escala ao passar o mouse (Hover)
	_animate_button_scale(Vector2(1.1, 1.1), 0.18, Tween.TRANS_BACK, Tween.EASE_OUT)

func _on_mouse_exited() -> void:
	# Animação de escala ao tirar o mouse (Retorna ao tamanho normal)
	_animate_button_scale(Vector2(1.0, 1.0), 0.15, Tween.TRANS_SINE, Tween.EASE_OUT)

func _on_pressed() -> void:
	# 🔊 Interrompe o hover e toca o som de clique
	if sound_hover: 
		sound_hover.stop()
		
	if sound_click and sound_click.stream:
		sound_click.stop()
		sound_click.play()

	# Efeito visual de impacto no clique
	_animate_button_scale(Vector2(0.9, 0.9), 0.05, Tween.TRANS_QUAD, Tween.EASE_IN)
	get_tree().create_timer(0.05).timeout.connect(func():
		_animate_button_scale(Vector2(1.1, 1.1), 0.1, Tween.TRANS_BACK, Tween.EASE_OUT)
	)

func _animate_button_scale(target_scale: Vector2, duration: float, trans: Tween.TransitionType, ease_type: Tween.EaseType) -> void:
	if scale_tween and scale_tween.is_running():
		scale_tween.kill()

	scale_tween = create_tween()
	scale_tween.tween_property(self, "scale", target_scale, duration)\
		.set_trans(trans)\
		.set_ease(ease_type)
