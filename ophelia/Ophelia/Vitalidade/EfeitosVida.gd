extends Node2D
## Usa o estilo compartilhado em Efeitos/EstiloParticulas.tres.
@export var vitalidade: Node
@export var sprite: AnimatedSprite2D
## Correção opcional, somada ao centro real da imagem atual.
@export var centro_efeitos: Vector2 = Vector2.ZERO
@export var tamanho_personagem: Vector2 = Vector2(50, 95)
@export_range(0, 80, 1) var quantidade_particulas_cura: int = 20
@export_range(0.1, 1.0, 0.05) var opacidade_cura: float = 1.0
@export_range(5.0, 80.0, 1.0) var velocidade_cura: float = 25.0
@export_range(0.0, 10.0, 0.1) var forca_tremida: float = 2.5
@export_range(0, 200, 1) var quantidade_particulas_morte: int = 90
var _particulas: Array[Dictionary] = []
var _amostras: Dictionary = {}
var _tempo: float = 0.0
var _tremida: float = 0.0
var _posicao_sprite: Vector2
var _cor_sprite: Color
var _asas: Node2D
var _posicao_asas: Vector2
var _lenco: Node2D

# Preparar o nó
# ---------------------
# Configura referências, sinais e estado inicial.
func _ready() -> void:

	process_mode = Node.PROCESS_MODE_PAUSABLE
	var jogador: Node = get_parent().get_parent()

	if vitalidade == null:

		vitalidade = jogador.get_node_or_null("Vitalidade")

	if sprite == null:

		sprite = jogador.find_child("SpritePersonagem", true, false) as AnimatedSprite2D

	_lenco = jogador.get_node_or_null("Lenco") as Node2D
	_asas = jogador.get_node_or_null("Visual/Asas") as Node2D

	if sprite != null:

		_posicao_sprite = sprite.position
		_cor_sprite = sprite.self_modulate

	if _asas != null:

		_posicao_asas = _asas.position

	z_index = 3

	if vitalidade == null:

		return

	vitalidade.connect("dano_recebido", _dano)

	if vitalidade.has_signal("fruta_consumida"):

		vitalidade.connect("fruta_consumida", _ao_consumir_fruta)

	vitalidade.connect("morreu", _morte)
	vitalidade.connect("restaurada", _restaurar_sprite)

# Dano
# ---------------------
# Processa dano.
func _dano(_quantidade: float, _origem: Vector2) -> void:

	_tremida = 0.22
	_emitir(18, false, false)

# Ao consumir fruta
# ---------------------
# Trata o evento: consumir fruta.
func _ao_consumir_fruta(_estacao: StringName, _quantidade_curada: float) -> void:

	_emitir(quantidade_particulas_cura, true, false)

# Emitir a morte
# ---------------------
# Distribui os cintilos pelo corpo e pelas fitas do lenço.
func _morte() -> void:

	_tremida = 0.0
	# O sinal pode chegar antes ou depois de CicloVida ocultar o sprite.
	# A imagem e os pontos das fitas continuam disponíveis nos dois casos.
	_emitir(quantidade_particulas_morte, false, true)

	if is_instance_valid(_lenco):

		for nome in ["pontos_tras", "pontos_frente"]:

			var pontos: Array = _lenco.get(nome)

			for i in range(1, pontos.size()):

				for passo in range(3):

					var posicao: Vector2 = Vector2(pontos[i - 1]).lerp(pontos[i], float(passo) / 3.0)
					_adicionar(posicao, Vector2.RIGHT.rotated(randf() * TAU) * randf_range(20, 65), false)

# Pontos sprite
# ---------------------
# Processa pontos sprite.
func _pontos_sprite() -> PackedVector2Array:

	var saida := PackedVector2Array()

	if not is_instance_valid(sprite) or sprite.sprite_frames == null:

		return saida

	var textura: Texture2D = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)

	if textura == null:

		return saida

	var chave: int = textura.get_instance_id()

	if not _amostras.has(chave):

		var uv := PackedVector2Array()
		var imagem: Image = textura.get_image()

		if imagem != null and not imagem.is_empty():

			if imagem.is_compressed():

				if imagem.decompress() != OK:

					return saida

			var passo: int = maxi(1, int(ceilf(float(maxi(imagem.get_width(), imagem.get_height())) / 180.0)))

			for y in range(0, imagem.get_height(), passo):

				for x in range(0, imagem.get_width(), passo):

					if imagem.get_pixel(x, y).a > 0.2:

						uv.append((Vector2(x, y) + Vector2.ONE * 0.5) / Vector2(imagem.get_size()))

		_amostras[chave] = uv

	var rect := Rect2(sprite.offset - (textura.get_size() * 0.5 if sprite.centered else Vector2.ZERO), textura.get_size())

	for uv: Vector2 in _amostras[chave]:

		var ponto := uv

		if sprite.flip_h:

			ponto.x = 1.0 - ponto.x

		if sprite.flip_v:

			ponto.y = 1.0 - ponto.y

		saida.append(sprite.to_global(rect.position + ponto * rect.size) + global_transform.basis_xform(centro_efeitos))

	return saida

# Emitir
# ---------------------
# Emite a rotina deste componente.
func _emitir(quantidade: int, cura: bool, morte: bool) -> void:

	var pontos: PackedVector2Array = _pontos_sprite()
	var centro: Vector2 = sprite.global_position if is_instance_valid(sprite) else global_position

	if not pontos.is_empty():

		var limites := Rect2(pontos[0], Vector2.ZERO)

		for ponto in pontos:

			limites = limites.expand(ponto)

		centro = limites.get_center()

	for i in range(quantidade):

		var posicao: Vector2 = pontos[randi() % pontos.size()] if not pontos.is_empty() else centro + Vector2(randf_range(-0.5, 0.5), randf_range(-0.5, 0.5)) * tamanho_personagem
		var velocidade: Vector2

		if cura:

			velocidade = Vector2(randf_range(-6, 6), -velocidade_cura * randf_range(0.6, 1.1))

		else:

			velocidade = (posicao - centro).normalized().rotated(randf_range(-0.35, 0.35)) * randf_range(25, 100 if morte else 55)

		_adicionar(posicao, velocidade, cura)

# Adicionar
# ---------------------
# Adiciona a rotina deste componente.
func _adicionar(posicao: Vector2, velocidade: Vector2, cura: bool) -> void:

	var duracao: float = randf_range(0.85, 1.3)
	_particulas.append({"p": posicao, "v": velocidade, "t": duracao, "total": duracao, "r": randf_range(8, 14), "cura": cura, "fase": randf() * TAU, "atraso": randf_range(0, 0.2) if cura else 0.0})

# Atualizar a cada quadro
# ---------------------
# Atualiza os temporizadores, a interface ou os efeitos deste nó.
func _process(delta: float) -> void:

	_tempo += delta
	_tremida = maxf(0.0, _tremida - delta)
	var deslocamento := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * forca_tremida * clampf(_tremida / 0.22, 0, 1)

	if is_instance_valid(sprite):

		sprite.position = _posicao_sprite + deslocamento
		var piscando: bool = is_instance_valid(vitalidade) and bool(vitalidade.call("esta_invulneravel")) and bool(vitalidade.call("esta_viva"))
		var alfa: float = 0.25 if piscando and sin(_tempo * 40.0) > 0 else 1.0
		sprite.self_modulate = Color(_cor_sprite, _cor_sprite.a * alfa)

	if is_instance_valid(_asas):

		_asas.position = _posicao_asas + deslocamento

	if is_instance_valid(_lenco):

		_lenco.set("tremor_visual", get_parent().global_transform.basis_xform(deslocamento))
		_lenco.call("_redesenhar_line2d")
		_lenco.queue_redraw()

	for i in range(_particulas.size() - 1, -1, -1):

		var p: Dictionary = _particulas[i]

		if float(p["atraso"]) > 0:

			p["atraso"] -= delta
			continue

		p["t"] -= delta
		p["p"] += p["v"] * delta
		p["v"] *= exp(-1.4 * delta)

		if float(p["t"]) <= 0:

			_particulas.remove_at(i)

	queue_redraw()

# Desenhar o efeito
# ---------------------
# Desenha os elementos visuais com o estado atual.
func _draw() -> void:

	for p in _particulas:

		if float(p["atraso"]) > 0:

			continue

		var idade: float = 1.0 - float(p["t"]) / float(p["total"])
		var alfa: float = (1.0 - smoothstep(0.35, 1.0, idade)) * (0.65 + 0.35 * sin(_tempo * 18 + float(p["fase"])))

		if bool(p["cura"]):

			alfa *= opacidade_cura * smoothstep(0, 0.15, idade)

		var cor_base: Color = Color("7c7fbdff") if bool(p["cura"]) else OpheliaEfeitosComuns.cor_particula()
		var cor: Color = Color(cor_base, alfa)
		OpheliaEfeitosComuns.desenhar_cintilo(self, to_local(p["p"]), float(p["r"]) * (1.0 - idade * 0.4), cor)

# Restaurar sprite
# ---------------------
# Restaura sprite.
func _restaurar_sprite() -> void:

	_tremida = 0.0

	if is_instance_valid(sprite):

		sprite.position = _posicao_sprite
		sprite.self_modulate = _cor_sprite

	if is_instance_valid(_asas):

		_asas.position = _posicao_asas

	if is_instance_valid(_lenco):

		_lenco.set("tremor_visual", Vector2.ZERO)
