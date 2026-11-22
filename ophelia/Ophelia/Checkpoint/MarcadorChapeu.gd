extends Node2D
## Marcador sem colisão: forma-se a partir de pontos na forma do chapéu, flutua,
## e, ao ser chamado, desliza até a personagem deixando um rastro de cintilos.
signal recolhido()
const TEXTURA_CHAPEU = preload("res://Ophelia/Checkpoint/ChapeuIcone.svg")
const ESTILO = preload("res://Ophelia/Efeitos/EstiloParticulas.tres")
const SHADER_BRILHO = preload("res://Scenes/Interactables/BrilhoInterativo.gdshader")
@export_range(0.1, 2.0, 0.05) var tempo_reunir: float = 0.48
@export_range(0.1, 2.0, 0.05) var tempo_descer: float = 0.56
@export_range(20, 200, 1) var quantidade_particulas: int = 90
@export_range(0.01, 0.5, 0.01) var escala_icone: float = 0.250
@export var amplitude_flutuar: float = 4.0
@export_group("Luz por proximidade")
@export_range(50.0, 1500.0, 10.0) var distancia_brilho: float = 400.0
@export_range(0.0, 2.0, 0.05) var brilho_distante: float = 0.3
@export_range(0.5, 6.0, 0.1) var brilho_proximo: float = 2.4
@export var velocidade_flutuar: float = 2.2
@export_group("Halo idêntico ao habilitar habilidade")
@export var cor_luz: Color = Color(0.408, 0.690, 0.612, 1.0)
@export_range(8.0, 256.0, 1.0) var tamanho_simbolo_halo: float = 100.0
@export_range(80, 850, 10) var velocidade_retorno: float = 330.0
@export_range(0.5, 5.0, 0.1) var fator_aceleracao: float = 1.45
@export_range(0.0, 0.5, 0.05) var escala_inicial_marcacao: float = 0.65
const MONTANDO := 0
const FLUTUANDO := 1
const RETORNANDO := 2
var _estado: int = MONTANDO
var _tempo: float = 0.0
var _inicio: Vector2 = Vector2.ZERO
var _reuniao: Vector2 = Vector2.ZERO
var _particulas: Array[Dictionary] = []
var _alvo: Node2D
var _particulas_rastro: Array[Dictionary] = []
var _velocidade_atual: float = 0.0
var _tempo_emissao: float = 0.0
var _brilho_atual: float = 0.3
var _espelhado: bool = false
var _simbolo: Sprite2D
var _material_luz: ShaderMaterial

func _ready() -> void:
	_simbolo = Sprite2D.new()
	_simbolo.texture = TEXTURA_CHAPEU
	_simbolo.scale = Vector2.ONE * escala_icone
	_simbolo.z_index = 1
	add_child(_simbolo)
	_material_luz = ShaderMaterial.new()
	_material_luz.shader = SHADER_BRILHO
	_material_luz.set_shader_parameter("cor", cor_luz)
	_simbolo.material = _material_luz


func configurar(inicio_global: Vector2, espelhado: bool = false) -> void:
	_espelhado = espelhado
	if is_instance_valid(_simbolo):
		_simbolo.flip_h = _espelhado
	_estado = MONTANDO
	_tempo = 0.0
	_inicio = to_local(inicio_global)
	_reuniao = _inicio + Vector2(0, -8)
	_particulas.clear()
	var img: Image = TEXTURA_CHAPEU.get_image()
	if img != null and img.is_compressed():
		if img.decompress() != OK:
			img = null
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in range(quantidade_particulas):
		var pos := Vector2(rng.randf_range(-30, 30), rng.randf_range(-16, 16))
		if img != null and not img.is_empty():
			for tentativa in range(80):
				var x := rng.randi_range(0, img.get_width() - 1)
				var y := rng.randi_range(0, img.get_height() - 1)
				if img.get_pixel(x, y).a > 0.3:
					pos = (Vector2(x, y) - Vector2(img.get_size()) * 0.5) * escala_icone
					if _espelhado:
						pos.x = -pos.x
					break
		_particulas.append({"origem": _inicio + pos * escala_inicial_marcacao,
							"destino": Vector2(0, -29) + pos,
							"fase": rng.randf() * TAU,
							"tam": rng.randf_range(1.0, 2.8)})
	queue_redraw()

func ativar_instantaneo(espelhado: bool = false) -> void:
	_espelhado = espelhado
	if is_instance_valid(_simbolo):
		_simbolo.flip_h = _espelhado
	_estado = FLUTUANDO
	_tempo = tempo_reunir + tempo_descer + 1.0
	queue_redraw()

# A miniatura acompanha a direção atual, inclusive durante o voo de retorno.
# Não modificamos a orientação de Ophelia nem usamos teclas extras.
func _sincronizar_direcao() -> void:
	var observador: Node2D = _alvo if _estado == RETORNANDO and is_instance_valid(_alvo) else get_tree().get_first_node_in_group("jogador") as Node2D
	if not is_instance_valid(observador):
		return
	var novo_espelhamento: bool = bool(observador.get("olhando_esquerda"))
	if novo_espelhamento == _espelhado:
		return
	_espelhado = novo_espelhamento
	if is_instance_valid(_simbolo):
		_simbolo.flip_h = _espelhado

func iniciar_retorno(alvo: Node2D) -> void:
	if _estado == RETORNANDO or not is_instance_valid(alvo):
		return
	_alvo = alvo
	_estado = RETORNANDO
	_velocidade_atual = velocidade_retorno * 0.35
	_particulas_rastro.clear()

func esta_retornando() -> bool:
	return _estado == RETORNANDO

func _process(delta: float) -> void:
	_tempo += delta
	if _estado != MONTANDO:
		_sincronizar_direcao()
	if _estado == FLUTUANDO:
		var observador: Node2D = get_tree().get_first_node_in_group("jogador") as Node2D
		var distancia: float = distancia_brilho
		if is_instance_valid(observador):
			distancia = minf(distancia_brilho, global_position.distance_to(observador.global_position))
		var fator: float = 1.0 - smoothstep(0.0, maxf(distancia_brilho, 1.0), distancia)
		_brilho_atual = lerpf(_brilho_atual, lerpf(brilho_distante, brilho_proximo, fator), 1.0 - exp(-6.0 * delta))
	if is_instance_valid(_simbolo):
		# O mini chapéu já existe desde o começo da marcação (sem bolinha intermediária).
		_simbolo.visible = true
		var escala_visivel: float = 1.0
		if _estado == MONTANDO:
			var duracao_marcacao: float = maxf(tempo_reunir + tempo_descer, 0.01)
			var p: float = smoothstep(0.0, 1.0, clampf(_tempo / duracao_marcacao, 0.0, 1.0))
			_simbolo.position = _inicio.lerp(Vector2(0, -29), p)
			escala_visivel = lerpf(escala_inicial_marcacao, 1.0, p)
		elif _estado == FLUTUANDO:
			_simbolo.position = Vector2(0, -29 + sin(_tempo * velocidade_flutuar) * amplitude_flutuar)
		else:
			_simbolo.position = Vector2.ZERO
			escala_visivel = 1.0 # O chapéu mantém a escala do ícone até chegar à personagem.
		_simbolo.scale = Vector2.ONE * escala_icone * escala_visivel
		_material_luz.set_shader_parameter("intensidade", _brilho_atual)
	if _estado == MONTANDO and _tempo >= tempo_reunir + tempo_descer + 0.35:
		_estado = FLUTUANDO
	if _estado == RETORNANDO:
		_atualizar_retorno(delta)
	for i in range(_particulas_rastro.size() - 1, -1, -1):
		_particulas_rastro[i]["vida"] -= delta
		if float(_particulas_rastro[i]["vida"]) <= 0.0:
			_particulas_rastro.remove_at(i)
	queue_redraw()

func _atualizar_retorno(delta: float) -> void:
	if not is_instance_valid(_alvo):
		_estado = FLUTUANDO
		return
	var destino := _alvo.global_position + Vector2(0, -40)
	_velocidade_atual = minf(velocidade_retorno * 2.0, _velocidade_atual + velocidade_retorno * fator_aceleracao * delta)
	global_position = global_position.move_toward(destino, _velocidade_atual * delta)
	_tempo_emissao += delta
	while _tempo_emissao >= 0.018:
		_tempo_emissao -= 0.018
		for i in range(2):
			_particulas_rastro.append({"pos": global_position + Vector2(randf_range(-9, 9), randf_range(-18, -2)),
				"vida": randf_range(0.3, 0.58), "total": 0.58, "tam": randf_range(1.0, 2.6)})
	if global_position.distance_to(destino) < 10.0:
		recolhido.emit()

func _draw() -> void:
	var cor: Color = ESTILO.get("cor")
	if _estado == MONTANDO:
		# Partículas seguem a silhueta já visível, em vez de virarem uma esfera.
		var duracao_marcacao: float = maxf(tempo_reunir + tempo_descer, 0.01)
		var p: float = smoothstep(0.0, 1.0, clampf(_tempo / duracao_marcacao, 0.0, 1.0))
		for particula in _particulas:
			var onde: Vector2 = Vector2(particula["origem"]).lerp(Vector2(particula["destino"]), p)
			var fase: float = float(particula["fase"])
			onde += Vector2(cos(_tempo * 14.0 + fase), sin(_tempo * 17.0 + fase)) * (2.5 * (1.0 - p))
			OpheliaEfeitosComuns.desenhar_cintilo(self, onde, float(particula["tam"]) * 3.0 * (1.0 - 0.6 * p), cor)
		return
	var flutuar: float = sin(_tempo * velocidade_flutuar) * amplitude_flutuar
	var centro_chapeu := Vector2(0, -29 + flutuar) if _estado == FLUTUANDO else Vector2.ZERO
	if _estado == FLUTUANDO:
		# Mesmo desenho de HabilitarHabilidade._draw: cinco círculos
		# preenchidos, transparentes e sobrepostos; sem arcos nem ondas.
		var raio: float = tamanho_simbolo_halo * 0.5 * (1.0 + _brilho_atual * 0.25)
		for i in range(5, 0, -1):
			draw_circle(centro_chapeu, raio * float(i) / 2.0, Color(cor_luz, _brilho_atual * 0.015))
	for p in _particulas_rastro:
		var alfa: float = clampf(float(p["vida"]) / float(p["total"]), 0.0, 1.0)
		OpheliaEfeitosComuns.desenhar_cintilo(self, to_local(p["pos"]), float(p["tam"]) * 4.2 * alfa,
			Color(cor_luz.r, cor_luz.g, cor_luz.b, alfa))
