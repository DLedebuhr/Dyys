extends TextureButton


# Texturas do botão
@export var imagem_normal: Texture2D:

	set(val):

		imagem_normal = val
		texture_normal = val


@export var imagem_hover: Texture2D:

	set(val):

		imagem_hover = val
		texture_hover = val
		texture_pressed = val


# Nós de áudio
@onready var sound_hover: AudioStreamPlayer = $SoundHover
@onready var sound_click: AudioStreamPlayer = $SoundClick


# Tween de escala do botão
var scale_tween: Tween


# Preparar o nó
# ---------------------
# Aplica as texturas, centraliza o pivô e conecta os sinais.
func _ready() -> void:

	texture_normal = imagem_normal
	texture_hover = imagem_hover
	texture_pressed = imagem_hover

	pivot_offset = size / 2.0

	item_rect_changed.connect(_atualizar_pivo)

	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	pressed.connect(_on_pressed)


# Atualizar o pivô
# ---------------------
# Mantém a animação de escala centralizada no botão.
func _atualizar_pivo() -> void:

	pivot_offset = size / 2.0


# Entrar com o mouse
# ---------------------
# Reproduz o som e aumenta o botão suavemente.
func _on_mouse_entered() -> void:

	if sound_hover and sound_hover.stream:

		sound_hover.stop()
		sound_hover.play()

	_animate_button_scale(
		Vector2(1.1, 1.1),
		0.18,
		Tween.TRANS_BACK,
		Tween.EASE_OUT
	)


# Sair com o mouse
# ---------------------
# Retorna o botão ao tamanho normal.
func _on_mouse_exited() -> void:

	_animate_button_scale(
		Vector2.ONE,
		0.15,
		Tween.TRANS_SINE,
		Tween.EASE_OUT
	)


# Pressionar o botão
# ---------------------
# Reproduz o som e o movimento de impacto do clique.
func _on_pressed() -> void:

	if sound_hover:

		sound_hover.stop()

	if sound_click and sound_click.stream:

		sound_click.stop()
		sound_click.play()

	_animate_button_scale(
		Vector2(0.9, 0.9),
		0.05,
		Tween.TRANS_QUAD,
		Tween.EASE_IN
	)

	get_tree().create_timer(0.05).timeout.connect(
		_finalizar_animacao_clique
	)


# Finalizar o clique
# ---------------------
# Retorna ao tamanho correspondente à posição do mouse.
func _finalizar_animacao_clique() -> void:

	var escala_destino: Vector2 = Vector2.ONE

	if get_global_rect().has_point(get_global_mouse_position()):

		escala_destino = Vector2(1.1, 1.1)

	_animate_button_scale(
		escala_destino,
		0.1,
		Tween.TRANS_BACK,
		Tween.EASE_OUT
	)


# Animar a escala do botão
# ---------------------
# Substitui o tween anterior por uma nova animação.
func _animate_button_scale(
	target_scale: Vector2,
	duration: float,
	trans: Tween.TransitionType,
	ease_type: Tween.EaseType
) -> void:

	if scale_tween and scale_tween.is_running():

		scale_tween.kill()

	scale_tween = create_tween()

	scale_tween.tween_property(
		self,
		"scale",
		target_scale,
		duration
	).set_trans(trans).set_ease(ease_type)
