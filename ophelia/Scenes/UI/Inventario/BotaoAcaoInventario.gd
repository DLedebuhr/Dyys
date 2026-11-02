@tool
extends TextureButton

@export var imagem_normal: Texture2D:
	set(valor):

		imagem_normal = valor
		texture_normal = valor
		_ajustar_tamanho()

@export var imagem_hover: Texture2D:
	set(valor):

		imagem_hover = valor
		texture_hover = valor

@export var imagem_pressed: Texture2D:
	set(valor):

		imagem_pressed = valor
		texture_pressed = valor

@export var imagem_inativa: Texture2D:
	set(valor):

		imagem_inativa = valor
		texture_disabled = valor

@export_group("Tamanho livre")
@export var usar_tamanho_textura: bool = false:
	set(valor):

		usar_tamanho_textura = valor
		_ajustar_tamanho()

@export_group("Áudio")
@export var som_hover: AudioStream
@export var som_click: AudioStream
@export var barramento_sfx: StringName = &"SFX"
var _tween: Tween
var _escala_base: Vector2 = Vector2.ONE

# Preparar o botão redimensionável
# ---------------------
# Não impõe tamanho mínimo; preserva a proporção da arte dentro do retângulo escolhido no editor.
func _ready() -> void:

	ignore_texture_size = true
	stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	_ajustar_tamanho()
	pivot_offset = size * 0.5

	if Engine.is_editor_hint():

		return

	_escala_base = scale
	resized.connect(_centralizar)
	mouse_entered.connect(_ao_entrar)
	mouse_exited.connect(_ao_sair)
	pressed.connect(_ao_clicar)

# Usar a dimensão nativa opcional
# ---------------------
# Só altera o tamanho automaticamente quando a opção está ligada e uma textura é atribuída.
func _ajustar_tamanho() -> void:

	ignore_texture_size = true

	if usar_tamanho_textura and imagem_normal != null:

		size = imagem_normal.get_size()

# Centralizar a animação
# ---------------------
# Recalcula o pivô ao redimensionar, sem alterar o tamanho escolhido.
func _centralizar() -> void:

	pivot_offset = size * 0.5

# Responder ao hover
# ---------------------
# Amplia em relação à escala configurada pelo jogador, sem restaurá-la para um valor fixo.
func _ao_entrar() -> void:

	if not disabled:

		_tocar($SoundHover, som_hover)
		_animar(_escala_base * 1.1)

# Encerrar o hover
# ---------------------
# Volta à escala original da instância.
func _ao_sair() -> void:

	_animar(_escala_base)

# Confirmar o clique
# ---------------------
# Mantém o som e o pequeno impacto usados pelos botões do jogo.
func _ao_clicar() -> void:

	$SoundHover.stop()
	_tocar($SoundClick, som_click)

	if _tween != null and _tween.is_valid():

		_tween.kill()

	_tween = create_tween()
	_tween.tween_property(self, "scale", _escala_base * 0.9, 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_property(self, "scale", _escala_base * 1.1, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# Substituir a animação anterior
# ---------------------
# Evita acumular ampliações quando o mouse entra e sai rapidamente.
func _animar(destino: Vector2) -> void:

	if _tween != null and _tween.is_valid():

		_tween.kill()

	_tween = create_tween()
	_tween.tween_property(self, "scale", destino, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

# Tocar o áudio configurado
# ---------------------
# Usa SFX quando o barramento existir e permite botões sem arquivo de áudio.
func _tocar(audio: AudioStreamPlayer, som: AudioStream) -> void:

	if som != null:

		audio.stream = som
		audio.bus = barramento_sfx if AudioServer.get_bus_index(barramento_sfx) >= 0 else &"Master"
		audio.play()

# Alternar a disponibilidade
# ---------------------
# Usa a quarta textura sem criar texto e só reinicia a escala quando o estado muda.
func definir_disponivel(disponivel: bool) -> void:

	if disabled == not disponivel:

		return

	disabled = not disponivel

	if not disponivel:

		_animar(_escala_base)
