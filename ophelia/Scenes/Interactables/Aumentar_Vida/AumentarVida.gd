extends Area2D

signal vida_maxima_aumentada(novo_maximo: int)

@export_group("Símbolo e brilho")
@export var textura_simbolo: Texture2D
@export_range(16.0, 128.0, 1.0) var tamanho_simbolo: float = 100.0
@export var cor_luz: Color = Color(0.7, 1.0, 0.85, 1.0)
@export_range(50.0, 1500.0, 10.0) var distancia_brilho: float = 400.0
@export_range(0.0, 3.0, 0.05) var brilho_distante: float = 0.3
@export_range(0.5, 6.0, 0.1) var brilho_proximo: float = 2.4
@export_range(0.0, 30.0, 0.5) var altura_flutuacao: float = 6.0
@export_range(0.1, 6.0, 0.1) var velocidade_flutuacao: float = 2.0

@export_group("Explosão do coração")
@export_range(0.1, 2.0, 0.05) var duracao_animacao: float = 0.9
@export_range(20, 300, 1) var quantidade_particulas: int = 140
@export_range(0.5, 3.0, 0.1) var tamanho_particulas: float = 1.2
@export_range(5.0, 100.0, 1.0) var velocidade_explosao: float = 35.0

@export_group("Interação e som")
@export var acao_interagir: StringName = &"ControleInteragir"
@export var som_coleta: AudioStream
@export var volume_sfx_db: float = -6.0
@export var barramento_sfx: StringName = &"SFX"

@onready var visual: Node2D = $Visual
@onready var simbolo: Sprite2D = $Visual/Simbolo

var _jogador: CharacterBody2D
var _beneficiario: CharacterBody2D
var _vitalidade: Node
var _tempo: float = 0.0
var _brilho_atual: float = 0.3
var _executando: bool = false
var _consumido: bool = false
var _material_luz: ShaderMaterial
var _observador: Node2D
var _particulas: Array[Dictionary] = []

# Preparar o interativo
# ---------------------
# Aplica o mesmo halo do símbolo de habilidade e configura a interação.
func _ready() -> void:

	add_to_group("coletaveis_ophelia")
	collision_layer = CamadasFisica.INTERAGIVEIS
	collision_mask = CamadasFisica.JOGADOR
	z_index = 3
	body_entered.connect(_ao_aproximar)
	body_exited.connect(_ao_afastar)

	if textura_simbolo != null:

		simbolo.texture = textura_simbolo

	if simbolo.texture != null:

		simbolo.scale = Vector2.ONE * tamanho_simbolo / maxf(maxf(simbolo.texture.get_width(), simbolo.texture.get_height()), 1.0) * 1.5

	_material_luz = ShaderMaterial.new()
	_material_luz.shader = preload("res://Scenes/Interactables/BrilhoInterativo.gdshader")
	_material_luz.set_shader_parameter("cor", cor_luz)
	simbolo.material = _material_luz

# Reconhecer o jogador
# ---------------------
# Permite a coleta ao entrar na área do coração.
func _ao_aproximar(corpo: Node2D) -> void:

	if corpo is CharacterBody2D and corpo.is_in_group("jogador"):

		_jogador = corpo

# Encerrar a proximidade
# ---------------------
# Oculta o aviso sem interromper uma coleta que já começou.
func _ao_afastar(corpo: Node2D) -> void:

	if corpo == _jogador:

		_jogador = null

# Verificar se pode coletar
# ---------------------
# Exige jogador vivo e impede reutilizar o coração ou superar seis vidas.
func pode_interagir(jogador: CharacterBody2D) -> bool:

	if _consumido or _executando or not is_instance_valid(jogador) or jogador != _jogador:

		return false

	var vida: Node = jogador.get_node_or_null("Vitalidade")
	return vida != null and bool(vida.call("esta_viva")) and int(vida.get("vida_maxima")) < 6


# Iniciar a explosão
# ---------------------
# Desfaz o próprio coração no lugar, sem levá-lo até a personagem.
func interagir(jogador: CharacterBody2D) -> bool:

	if not pode_interagir(jogador):

		return false

	_beneficiario = jogador
	_vitalidade = jogador.get_node_or_null("Vitalidade")
	_executando = true
	_emitir_explosao()
	visual.hide()
	_tocar_coleta()
	queue_redraw()
	return true

# Amostrar a silhueta do coração
# ---------------------
# Converte os pixels visíveis da textura em partículas brancas, como na HUD.
func _emitir_explosao() -> void:

	_particulas.clear()
	var amostras := PackedVector3Array()
	var textura: Texture2D = simbolo.texture

	if textura != null:

		var imagem: Image = textura.get_image()

		if imagem != null and (not imagem.is_compressed() or imagem.decompress() == OK):

			var passo: int = maxi(1, int(ceilf(float(maxi(imagem.get_width(), imagem.get_height())) / 256.0)))

			for y in range(0, imagem.get_height(), passo):

				for x in range(0, imagem.get_width(), passo):

					var alpha: float = imagem.get_pixel(x, y).a

					if alpha > 0.12:

						amostras.append(Vector3((float(x) + 0.5) / float(imagem.get_width()), (float(y) + 0.5) / float(imagem.get_height()), alpha))

	var centro: Vector2 = simbolo.global_position

	for i in range(quantidade_particulas):

		var posicao: Vector2 = centro
		var alpha: float = 1.0

		if not amostras.is_empty() and textura != null:

			var indice: int = mini(int((float(i) + 0.5) * float(amostras.size()) / float(quantidade_particulas)), amostras.size() - 1)
			var ponto: Vector3 = amostras[indice]
			var uv := Vector2(ponto.x, ponto.y)
			var origem: Vector2 = simbolo.offset - (textura.get_size() * 0.5 if simbolo.centered else Vector2.ZERO)
			# Compensa a margem do shader de brilho, preservando o tamanho do coração.
			posicao = simbolo.to_global(origem + (uv + Vector2.ONE * 0.25) / 1.5 * textura.get_size())
			alpha = ponto.z

		var direcao: Vector2 = (posicao - centro).normalized()

		if direcao.is_zero_approx():

			direcao = Vector2.RIGHT.rotated(randf() * TAU)

		var duracao: float = duracao_animacao * randf_range(0.75, 1.0)
		_particulas.append({"p": posicao, "v": direcao * velocidade_explosao * randf_range(0.65, 1.15), "t": 0.0, "duracao": duracao, "alpha": alpha, "raio": tamanho_particulas * randf_range(0.85, 1.15)})

# Atualizar o brilho e a explosão
# ---------------------
# Espera as partículas se desfazerem antes de conceder o novo coração na barra.
func _process(delta: float) -> void:

	_tempo += delta

	if _consumido:

		return

	if not _executando:

		visual.position.y = sin(_tempo * velocidade_flutuacao) * altura_flutuacao
		var menor: float = distancia_brilho

		if not is_instance_valid(_observador):

			_observador = get_tree().get_first_node_in_group("jogador") as Node2D

		if is_instance_valid(_observador):

			menor = minf(menor, global_position.distance_to(_observador.global_position))

		var fator: float = 1.0 - smoothstep(0.0, maxf(distancia_brilho, 1.0), menor)
		_brilho_atual = lerpf(_brilho_atual, lerpf(brilho_distante, brilho_proximo, fator), 1.0 - exp(-6.0 * delta))
		_material_luz.set_shader_parameter("intensidade", _brilho_atual)
		queue_redraw()
		return

	if not is_instance_valid(_beneficiario) or not is_instance_valid(_vitalidade) or not bool(_vitalidade.call("esta_viva")):

		_cancelar()
		return

	for i in range(_particulas.size() - 1, -1, -1):

		var particula: Dictionary = _particulas[i]
		var antes: float = float(particula["t"])
		particula["t"] += delta
		var movimento: float = maxf(0, float(particula["t"]) - 0.08) - maxf(0, antes - 0.08)
		particula["p"] += particula["v"] * movimento
		particula["v"] *= exp(-1.2 * movimento)

		if float(particula["t"]) >= float(particula["duracao"]):

			_particulas.remove_at(i)

	queue_redraw()

	if _particulas.is_empty():

		_conceder_vida()

# Conceder a vida máxima
# ---------------------
# Atualiza a HUD pelo sinal existente depois de finalizar a explosão.
func _conceder_vida() -> void:

	if not bool(_vitalidade.call("aumentar_vida_maxima")):

		_cancelar()
		return

	_consumido = true
	_executando = false
	set_deferred("monitoring", false)
	remove_from_group("coletaveis_ophelia")
	vida_maxima_aumentada.emit(int(_vitalidade.get("vida_maxima")))
	queue_redraw()
	set_process(false)

# Reproduzir o som de coleta
# ---------------------
# Toca no ponto onde o coração se desfaz.
func _tocar_coleta() -> void:

	var audio: AudioStreamPlayer2D = get_node_or_null("SomColeta") as AudioStreamPlayer2D

	if audio != null and som_coleta != null:

		audio.global_position = visual.global_position
		audio.stream = som_coleta
		audio.bus = barramento_sfx if AudioServer.get_bus_index(barramento_sfx) >= 0 else &"Master"
		audio.volume_db = volume_sfx_db
		audio.play()

# Cancelar uma coleta interrompida
# ---------------------
# Restaura o coração se a personagem morrer antes do término da explosão.
func _cancelar() -> void:

	_executando = false
	_particulas.clear()
	visual.show()
	queue_redraw()

# Desenhar o halo e as partículas
# ---------------------
# Replica a luz de espera da habilidade e o desmanche branco da barra de vida.
func _draw() -> void:

	if _consumido:

		return

	if not _executando:

		var raio: float = tamanho_simbolo * 0.5 * (1.0 + _brilho_atual * 0.25)

		for i in range(5, 0, -1):

			draw_circle(visual.position, raio * float(i) / 2.0, Color(cor_luz, _brilho_atual * 0.015))

		return

	for particula in _particulas:

		var progresso: float = clampf(float(particula["t"]) / float(particula["duracao"]), 0, 1)
		var alpha: float = (1.0 - smoothstep(0.2, 1.0, progresso)) * 0.7 * float(particula["alpha"])
		var raio: float = float(particula["raio"]) * (1.0 - progresso * 0.35)
		var posicao: Vector2 = to_local(particula["p"])
		draw_circle(posicao, raio * 2.2, Color(1, 1, 1, alpha * 0.07), true, -1.0, true)
		draw_circle(posicao, raio, Color(1, 1, 1, alpha), true, -1.0, true)
