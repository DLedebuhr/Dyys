# ===== SCRIPT DO NÓ "Portao" (Node2D) — abre o portão e solta a luz de dentro =====
class_name TeaserPortao
extends Node2D

signal aberto

@export_group("Abertura")
@export var animacao_abrir: String = "abrir"     # nome da animação (AnimationPlayer ou AnimatedSprite2D)
@export var duracao_padrao: float = 1.6          # usada quando não há animação
@export var abertura_px: float = 44.0            # modo sem animação: quanto as portas deslizam

@export_group("Luz de dentro")
@export var posicao_luz: Vector2 = Vector2(0.0, -70.0)  # centro da luz, relativo ao portão
@export var diametro_luz: float = 150.0                 # tamanho da luz quando o portão abre
@export var diametro_luz_final: float = 9000.0          # tamanho final (cobre a tela)
@export var cor_luz: Color = Color(1.0, 0.97, 0.88)

var luz: Node2D = null

func _ready() -> void:
	# Luz: usa o seu nó "Luz" se existir, senão cria um brilho padrão
	luz = get_node_or_null("Luz") as Node2D
	if luz == null:
		var nova := TeaserUtil.criar_brilho("Luz", diametro_luz, cor_luz)
		nova.position = posicao_luz
		add_child(nova)
		luz = nova
	luz.z_index = 20 # fica por cima da boneca e do portão
	luz.modulate.a = 0.0

func _largura_textura_luz() -> float:
	if "texture" in luz and luz.texture != null:
		return float(luz.texture.get_width())
	return float(TeaserUtil.TAM_TEXTURA)

# Abre o portão. Use com "await portao.abrir()".
func abrir() -> void:
	var tempo: float = duracao_padrao
	var player := get_node_or_null("AnimationPlayer") as AnimationPlayer
	var anim_sprite := find_child("AnimatedSprite2D", true, false) as AnimatedSprite2D

	if player != null and player.has_animation(animacao_abrir):
		tempo = player.get_animation(animacao_abrir).length
		player.play(animacao_abrir)
	elif anim_sprite != null and anim_sprite.sprite_frames != null \
			and anim_sprite.sprite_frames.has_animation(animacao_abrir):
		var frames: SpriteFrames = anim_sprite.sprite_frames
		var soma: float = 0.0
		for i in range(frames.get_frame_count(animacao_abrir)):
			soma += frames.get_frame_duration(animacao_abrir, i)
		tempo = soma / maxf(frames.get_animation_speed(animacao_abrir), 0.01)
		anim_sprite.play(animacao_abrir)
	else:
		# Sem animação: as portas "PortaEsquerda" e "PortaDireita" deslizam para os lados
		var pe := get_node_or_null("PortaEsquerda") as Node2D
		var pd := get_node_or_null("PortaDireita") as Node2D
		var tp := create_tween().set_parallel(true)
		if pe:
			tp.tween_property(pe, "position:x", pe.position.x - abertura_px, tempo) \
					.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		if pd:
			tp.tween_property(pd, "position:x", pd.position.x + abertura_px, tempo) \
					.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

	# A luz de dentro começa a vazar enquanto o portão abre
	var tl := create_tween().set_parallel(true)
	tl.tween_property(luz, "modulate:a", 0.85, tempo)
	var esc_aberto: float = diametro_luz / _largura_textura_luz()
	tl.tween_property(luz, "scale", Vector2(esc_aberto, esc_aberto), tempo)

	await get_tree().create_timer(tempo).timeout
	aberto.emit()

# A luz cresce até cobrir a tela inteira
func inundar(duracao: float) -> void:
	var esc_final: float = diametro_luz_final / _largura_textura_luz()
	var tw := create_tween().set_parallel(true)
	tw.tween_property(luz, "scale", Vector2(esc_final, esc_final), duracao) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(luz, "modulate:a", 1.0, duracao * 0.5)
