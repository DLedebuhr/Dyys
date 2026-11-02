extends Sprite2D
# Sombra da personagem. Nó "Visual/Sombra" (Sprite2D), com camada de desenho configurada na cena
# (assim é desenhado atrás do sprite). Não precisa de textura: se o campo Texture ficar vazio,
# o script gera uma mancha suave sozinho. Se você tiver uma arte de sombra, coloque em Texture.
@export var jogador: CharacterBody2D   # Se vazio, usa o pai
@export_group("Aparência")
@export var cor: Color = Color(0.04, 0.04, 0.10)    # Cor da sombra (o alfa vem de 'opacidade')
@export_range(0.0, 1.0) var opacidade: float = 0.35  # Força da sombra com a personagem no chão
@export var largura: float = 56.0                    # Largura (px) com a personagem no chão
@export_range(0.1, 1.0) var proporcao_altura: float = 0.28  # Altura = largura x isto (achata a elipse)
@export var deslocamento: Vector2 = Vector2.ZERO     # Ajuste fino da posição em relação ao ponto do chão
@export_group("Chão")
@export_flags_2d_physics var mascara_chao: int = 1   # Camadas de física que contam como chão
@export var alcance_busca: float = 800.0             # Até onde (px) procura chão abaixo dos pés
@export var alinhar_ao_chao: bool = false            # true: inclina a sombra conforme a rampa
@export_group("Altura (pulo)")
@export var altura_maxima: float = 300.0             # Distância do chão em que a sombra chega ao mínimo
@export_range(0.1, 1.0) var escala_minima: float = 0.5      # Tamanho na altura máxima (fração)
@export_range(0.0, 1.0) var opacidade_minima: float = 0.3   # Força na altura máxima (fração)
@export var velocidade_fade: float = 6.0             # Rapidez de aparecer/sumir (maior = mais rápido)
var _pes_local: Vector2 = Vector2.ZERO   # Ponto dos pés, em coordenadas do OPHELIA
var _tam_textura: Vector2 = Vector2(128.0, 128.0)
var _fade: float = 0.0                   # 0 = invisível | 1 = visível
var voo: Node = null                     # VooDebug (a sombra some enquanto ela é luz)

# Preparar o nó
# ---------------------
# Configura referências, sinais e estado inicial.
func _ready() -> void:

	if jogador == null:

		jogador = owner as CharacterBody2D

	if jogador == null:

		push_warning("Sombra: precisa pertencer à cena OPHELIA (CharacterBody2D).")
		set_physics_process(false)
		visible = false
		return

	if texture == null:

		texture = _criar_textura()
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

	_tam_textura = Vector2(texture.get_width(), texture.get_height())
	centered = true
	offset = Vector2.ZERO
	voo = %VooDebug
	_medir_pes()
	modulate = Color(cor.r, cor.g, cor.b, 0.0)
	visible = false
# Os pés ficam na base da cápsula de colisão do OPHELIA

# Medir pés
# ---------------------
# Mede pés.
func _medir_pes() -> void:

	_pes_local = Vector2.ZERO
	var cs := %ColisaoCorpo as CollisionShape2D

	if cs == null or cs.shape == null:

		push_warning("Sombra: não achei o CollisionShape2D do OPHELIA; usando a origem dele como pés.")
		return

	var meia_altura := 0.0
	var capsula := cs.shape as CapsuleShape2D
	var circulo := cs.shape as CircleShape2D
	var retangulo := cs.shape as RectangleShape2D

	if capsula != null:

		meia_altura = capsula.height * 0.5

	elif circulo != null:

		meia_altura = circulo.radius

	elif retangulo != null:

		meia_altura = retangulo.size.y * 0.5

	_pes_local = cs.position + Vector2(0.0, meia_altura * cs.scale.y)
# Roda DEPOIS do OPHELIA (filhos processam depois do pai), então vê a posição já atualizada

# Atualizar a física
# ---------------------
# Avança o movimento e as verificações físicas deste nó.
func _physics_process(delta: float) -> void:

	var quer_visivel := not _voo_escondendo()
	var altura_f := 0.0

	if quer_visivel:

		var pes := jogador.to_global(_pes_local)
		# O raio começa um pouco acima dos pés (dentro do corpo, que é ignorado) e desce
		var de := pes + Vector2(0.0, -8.0)
		var ate := pes + Vector2(0.0, alcance_busca)
		var consulta := PhysicsRayQueryParameters2D.create(de, ate, mascara_chao, [jogador.get_rid()])
		var resultado := get_world_2d().direct_space_state.intersect_ray(consulta)

		if resultado.is_empty():

			quer_visivel = false   # Sem chão embaixo: a sombra some

		else:

			var ponto: Vector2 = resultado["position"]
			global_position = ponto + deslocamento

			if alinhar_ao_chao:

				var normal: Vector2 = resultado["normal"]
				global_rotation = normal.angle() + PI * 0.5

			else:

				global_rotation = 0.0

			var altura := maxf(ponto.y - pes.y, 0.0)
			altura_f = clampf(altura / maxf(altura_maxima, 1.0), 0.0, 1.0)

	_fade = move_toward(_fade, 1.0 if quer_visivel else 0.0, delta * velocidade_fade)
	visible = _fade > 0.01
	# Quanto mais alto, menor e mais fraca
	var k := lerpf(1.0, escala_minima, altura_f)
	scale = Vector2(largura / _tam_textura.x, largura * proporcao_altura / _tam_textura.y) * k
	var alfa := opacidade * _fade * lerpf(1.0, opacidade_minima, altura_f)
	modulate = Color(cor.r, cor.g, cor.b, alfa)
# A sombra some durante o voo de teste (V), enquanto a boneca vira luz

# Voo escondendo
# ---------------------
# Processa voo escondendo.
func _voo_escondendo() -> bool:

	if voo == null or not ("forma" in voo):

		return false

	var forma_atual = voo.forma
	return forma_atual == voo.Forma.ENTRANDO or forma_atual == voo.Forma.VOANDO
# Mancha redonda e macia: centro forte, borda transparente

# Criar textura
# ---------------------
# Cria textura.
func _criar_textura() -> GradientTexture2D:

	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	grad.colors = PackedColorArray([
		Color(1.0, 1.0, 1.0, 1.0),
		Color(1.0, 1.0, 1.0, 0.55),
		Color(1.0, 1.0, 1.0, 0.0),
	])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 128
	tex.height = 128
	return tex
