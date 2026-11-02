@tool
class_name GalhoFrutasOphelia
extends Node2D

signal cortado()
signal regenerado()

@export_group("Frutas por instância")
@export_range(0, 24, 1) var quantidade_frutas: int = 1
@export_enum("Marcadores na cena", "Lista de offsets") var modo_posicoes: int = 1
@export var texturas_frutas: Array[Texture2D] = []
@export var posicoes_frutas: Array[Vector2] = []
@export_range(0.1, 5.0, 0.1) var intervalo_entre_frutas: float = 0.8
@export var som_corte: AudioStream
@export var som_fruta_coleta: AudioStream
@export var som_fruta_impacto: AudioStream
@export var volume_sfx_db: float = -6.0
@export var barramento_sfx: StringName = &"SFX"

@export var estacao: CatalogoFrutasOphelia.Estacao = CatalogoFrutasOphelia.Estacao.PRIMAVERA
@export var catalogo: CatalogoFrutasOphelia = preload("CatalogoFrutas.tres")
@export_range(20.0, 400.0, 1.0) var comprimento: float = 110.0
@export_range(4, 24, 1) var segmentos: int = 10
@export_range(1.0, 8.0, 0.5) var largura_linha: float = 2.0
@export var textura_ponta: Texture2D
@export_range(4.0, 96.0, 1.0) var tamanho_ponta: float = 22.0
@export_range(0.0, 80.0, 1.0) var vento: float = 12.0
@export_range(0.0, 1.0, 0.05) var amortecimento: float = 0.9
@export_range(1.0, 600.0, 1.0) var segundos_regeneracao_frutas: float = 10.0 # Produção: 180.


@onready var linha: Line2D = $Linha
@onready var ponta: Sprite2D = $Ponta
@onready var frutos: Node2D = $Frutos
@onready var area_corte: Area2D = $AreaCorte
@onready var forma_corte: CollisionPolygon2D = $AreaCorte/Forma
@onready var visibilidade: VisibleOnScreenNotifier2D = $Visibilidade
@onready var particulas: CPUParticles2D = $ParticulasCorte

var _pontos := PackedVector2Array()
var _anteriores := PackedVector2Array()
var _frutas: Array[FrutaOphelia] = []
var _cortado: bool = false
var _corte_pendente: bool = false
var _tempo: float = 0.0
var _fora_da_tela: bool = true
var _ponto_corte: Vector2 = Vector2.ZERO
var _indice_corte: int = 0
var _fila_regeneracao: Array[FrutaOphelia] = []
var _espera_regeneracao: float = 0.0
var _assinatura_preview: int = 0
const CENA_FRUTA = preload("Fruta.tscn")

# Preparar o galho
# ---------------------
# Configura a corda, as frutas manuais e a detecção dos ataques.
func _ready() -> void:

	if Engine.is_editor_hint():

		frutos.hide()
		set_physics_process(false)
		set_process(true)
		_atualizar_preview()
		return

	frutos.show()
	set_process(false)
	linha.width = largura_linha
	linha.default_color = Color.WHITE
	area_corte.collision_layer = CamadasFisica.RECEBE_DANO
	area_corte.collision_mask = 0
	visibilidade.rect = Rect2(-comprimento - 80.0, -30.0, comprimento * 2.0 + 160.0, comprimento + 140.0)
	visibilidade.screen_exited.connect(_ao_sair_da_tela)
	visibilidade.screen_entered.connect(_ao_entrar_na_tela)
	ponta.texture = textura_ponta

	if textura_ponta != null:

		ponta.scale = Vector2.ONE * tamanho_ponta / maxf(maxf(textura_ponta.get_width(), textura_ponta.get_height()), 1.0)

	_configurar_frutas()

	OpheliaEfeitosComuns.configurar_emissor(particulas)
	particulas.one_shot = true
	particulas.amount = 16
	particulas.lifetime = 0.8
	particulas.explosiveness = 0.85
	particulas.direction = Vector2.UP
	particulas.spread = 180.0
	particulas.gravity = Vector2(0, -12)
	particulas.initial_velocity_min = 12.0
	particulas.initial_velocity_max = 45.0
	particulas.scale_amount_min = 0.2
	particulas.scale_amount_max = 0.5
	_reiniciar_corda()
	set_physics_process(false)

# Montar a corda reta
# ---------------------
# Restaura a forma inicial sem substituir as frutas ou seus relógios.
func _reiniciar_corda() -> void:

	_pontos.clear()
	_anteriores.clear()

	for i in range(segmentos + 1):

		var ponto := Vector2(0, comprimento * float(i) / float(segmentos))
		_pontos.append(ponto)
		_anteriores.append(ponto)

	_atualizar_desenho()

# Verificar o estado do caule
# ---------------------
# Permite que as frutas aguardem o galho antes de reaparecer.
func esta_cortado() -> bool:

	return _cortado or _corte_pendente

# Receber um golpe
# ---------------------
# Aceita o ataque normal e os projéteis pela interface de dano existente.
func receber_dano(quantidade: int) -> bool:

	if quantidade <= 0 or esta_cortado():

		return false

	_definir_ponto_corte(to_local(get_global_mouse_position()))
	_corte_pendente = true
	call_deferred("_cortar")
	return true

# Cortar o caule
# ---------------------
# Derruba as frutas ainda presas e emite os cintilos padronizados.
func _cortar() -> void:

	_corte_pendente = false
	_cortado = true
	area_corte.set_deferred("monitorable", false)
	area_corte.set_deferred("collision_layer", 0)
	var posicao: Vector2 = _ponto_corte
	var trecho := PackedVector2Array(_pontos.slice(0, _indice_corte + 1))
	trecho.append(_ponto_corte)
	linha.points = trecho
	var audio: AudioStreamPlayer2D = get_node_or_null("SomCorte") as AudioStreamPlayer2D

	if audio != null and som_corte != null:

		audio.stream = som_corte
		audio.bus = barramento_sfx if AudioServer.get_bus_index(barramento_sfx) >= 0 else &"Master"
		audio.volume_db = volume_sfx_db
		audio.position = posicao
		audio.play()
	ponta.hide()
	particulas.position = posicao
	particulas.restart()
	particulas.emitting = true

	for fruta in _frutas:

		if is_instance_valid(fruta):

			fruta.soltar(Vector2(randf_range(-35, 35), randf_range(0, 30)))

	cortado.emit()

	if _fora_da_tela:

		_regenerar_galho()

# Restaurar fora da câmera
# ---------------------
# Regenera o galho cortado assim que ele sai da visão do jogador.
func _ao_sair_da_tela() -> void:

	_fora_da_tela = true
	set_physics_process(false)

	if _cortado:

		_regenerar_galho()

# Registrar o retorno à câmera
# ---------------------
# Mantém o galho cortado enquanto ainda está sendo observado.
func _ao_entrar_na_tela() -> void:

	_fora_da_tela = false
	set_physics_process(true)

# Recriar o caule
# ---------------------
# Restaura só o galho; cada fruta mantém seu próprio tempo de retorno.
func _regenerar_galho() -> void:

	_cortado = false
	area_corte.set_deferred("monitorable", true)
	area_corte.set_deferred("collision_layer", CamadasFisica.RECEBE_DANO)
	ponta.show()
	_reiniciar_corda()

	for fruta in _frutas:

		if is_instance_valid(fruta):

			fruta.tentar_regenerar()

	if not _fila_regeneracao.is_empty():

		set_process(true)

	regenerado.emit()

# Simular o balanço da corda
# ---------------------
# Usa segmentos leves com distâncias fixas e a origem presa ao cenário.
func _physics_process(delta: float) -> void:

	if _cortado or _pontos.is_empty():

		return

	_tempo += delta
	var passo: float = minf(delta, 1.0 / 30.0)
	var aceleracao := Vector2(sin(_tempo * 1.6) * vento, 500.0)

	for i in range(1, _pontos.size()):

		var atual: Vector2 = _pontos[i]
		_pontos[i] += (_pontos[i] - _anteriores[i]) * pow(amortecimento, passo * 60.0) + aceleracao * passo * passo
		_anteriores[i] = atual

	for repeticao in range(8):

		_pontos[0] = Vector2.ZERO

		for i in range(_pontos.size() - 1):

			var vetor: Vector2 = _pontos[i + 1] - _pontos[i]
			var distancia: float = vetor.length()

			if distancia < 0.001:

				continue

			var ajuste: Vector2 = vetor * (distancia - comprimento / float(segmentos)) / distancia

			if i == 0:

				_pontos[i + 1] -= ajuste

			else:

				_pontos[i] += ajuste * 0.5
				_pontos[i + 1] -= ajuste * 0.5

	_atualizar_desenho()

# Atualizar a linha e a área de corte
# ---------------------
# Move a ponta e os frutos juntos e acompanha a curva com uma área estreita.
func _atualizar_desenho() -> void:

	linha.points = _pontos
	ponta.position = _pontos[-1]
	frutos.position = _pontos[-1]
	var poligono := PackedVector2Array()

	for i in range(_pontos.size()):

		poligono.append(_pontos[i] + Vector2(-5, 0))

	for i in range(_pontos.size() - 1, -1, -1):

		poligono.append(_pontos[i] + Vector2(5, 0))

	forma_corte.polygon = poligono

# Configurar a quantidade da instância
# ---------------------
# Usa as posições do Inspetor e cria somente as frutas necessárias.
func _configurar_frutas() -> void:

	var existentes: Array[FrutaOphelia] = []

	for filho in frutos.get_children():

		if filho is FrutaOphelia:

			existentes.append(filho)

	for i in range(quantidade_frutas):

		var fruta: FrutaOphelia

		if i < existentes.size():

			fruta = existentes[i]

		else:

			fruta = CENA_FRUTA.instantiate() as FrutaOphelia
			fruta.name = "Fruta%d" % (i + 1)
			fruta.position = _posicao_configurada(i)
			frutos.add_child(fruta)

		if i < texturas_frutas.size() and texturas_frutas[i] != null:

			fruta.textura_personalizada = texturas_frutas[i]

		fruta.definir_nascimento(_posicao_configurada(i))
		fruta.segundos_regeneracao = segundos_regeneracao_frutas
		fruta.vincular(self, estacao, catalogo)

		if som_fruta_coleta != null:

			fruta.som_coleta = som_fruta_coleta

		if som_fruta_impacto != null:

			fruta.som_impacto = som_fruta_impacto

		fruta.volume_sfx_db = volume_sfx_db
		fruta.barramento_sfx = barramento_sfx
		_frutas.append(fruta)

	for i in range(quantidade_frutas, existentes.size()):

		existentes[i].desativar()

# Resolver a posição de uma fruta
# ---------------------
# Preserva as posições configuradas e oferece uma disposição inicial para slots novos.
func _posicao_configurada(indice: int) -> Vector2:

	var marcadores: Node2D = get_node_or_null("PosicoesFrutas") as Node2D

	if modo_posicoes == 0 and marcadores != null and indice < marcadores.get_child_count():

		var marcador: Node2D = marcadores.get_child(indice) as Node2D

		if marcador != null:

			return marcador.position

	if modo_posicoes == 0 and marcadores == null and frutos != null:

		var existentes: Array[Node] = frutos.get_children()

		if indice < existentes.size() and existentes[indice] is FrutaOphelia:

			return (existentes[indice] as Node2D).position

	if indice < posicoes_frutas.size():

		return posicoes_frutas[indice]

	if quantidade_frutas <= 1:

		return Vector2.ZERO

	var angulo: float = TAU * float(indice) / float(quantidade_frutas) - PI * 0.5
	return Vector2(cos(angulo), sin(angulo)) * 18.0 + Vector2(0, 8)

# Registrar o impacto real
# ---------------------
# Cruza o percurso do golpe com os segmentos atuais da corda.
func receber_golpe(quantidade: int, inicio: Vector2, fim: Vector2) -> bool:

	if quantidade <= 0 or esta_cortado():

		return false

	var de: Vector2 = to_local(inicio)
	var ate: Vector2 = to_local(fim)
	var melhor: Vector2 = ate
	var distancia: float = INF

	for i in range(_pontos.size() - 1):

		var cruzamento: Variant = Geometry2D.segment_intersects_segment(de, ate, _pontos[i], _pontos[i + 1])

		if cruzamento is Vector2 and de.distance_squared_to(cruzamento) < distancia:

			melhor = cruzamento
			distancia = de.distance_squared_to(cruzamento)

	_definir_ponto_corte(melhor)
	_corte_pendente = true
	call_deferred("_cortar")
	return true

# Projetar o corte sobre a linha
# ---------------------
# Guarda a posição exata do corte, inclusive entre dois nós da corda.
func _definir_ponto_corte(ponto: Vector2) -> void:

	var distancia: float = INF

	for i in range(_pontos.size() - 1):

		var candidato: Vector2 = Geometry2D.get_closest_point_to_segment(ponto, _pontos[i], _pontos[i + 1])
		var atual: float = candidato.distance_squared_to(ponto)

		if atual < distancia:

			distancia = atual
			_ponto_corte = candidato
			_indice_corte = i

# Enfileirar uma fruta madura
# ---------------------
# Evita que várias frutas prontas reapareçam juntas após a regeneração do galho.
func solicitar_regeneracao(fruta: FrutaOphelia) -> void:

	if not _fila_regeneracao.has(fruta):

		_fila_regeneracao.append(fruta)

	set_process(true)

# Controlar o retorno sequencial
# ---------------------
# Libera uma fruta por intervalo e atualiza a prévia no editor.
func _process(delta: float) -> void:

	if Engine.is_editor_hint():

		_atualizar_preview()
		return

	if esta_cortado():

		set_process(false)
		return

	_espera_regeneracao = maxf(0.0, _espera_regeneracao - delta)

	if not esta_cortado() and not _fila_regeneracao.is_empty() and _espera_regeneracao <= 0.0:

		var fruta: FrutaOphelia = _fila_regeneracao.pop_front()

		if is_instance_valid(fruta):

			fruta.call_deferred("_regenerar")
			_espera_regeneracao = intervalo_entre_frutas

	if _fila_regeneracao.is_empty() and _espera_regeneracao <= 0.0:

		set_process(false)

# Mostrar as posições antes de jogar
# ---------------------
# Atualiza a prévia da quantidade e dos offsets escolhidos por instância.
func _atualizar_preview() -> void:

	var assinatura: int = hash([comprimento, largura_linha, textura_ponta, tamanho_ponta, quantidade_frutas, modo_posicoes, posicoes_frutas, texturas_frutas, catalogo, estacao, _posicoes_marcadores()])

	if assinatura == _assinatura_preview:

		return

	_assinatura_preview = assinatura
	linha.points = PackedVector2Array([Vector2.ZERO, Vector2(0, comprimento)])
	linha.width = largura_linha
	linha.default_color = Color.WHITE
	ponta.position = Vector2(0, comprimento)
	var marcadores: Node2D = get_node_or_null("PosicoesFrutas") as Node2D

	if marcadores != null:

		marcadores.position = Vector2(0, comprimento)
	ponta.texture = textura_ponta

	if textura_ponta != null:

		ponta.scale = Vector2.ONE * tamanho_ponta / maxf(maxf(textura_ponta.get_width(), textura_ponta.get_height()), 1)

	queue_redraw()

# Desenhar as frutas na prévia
# ---------------------
# Permite ajustar os offsets no Inspetor e ver o resultado sem executar a fase.
func _draw() -> void:

	if not Engine.is_editor_hint():

		return

	var textura: Texture2D = catalogo.obter_textura(estacao) if catalogo != null else null

	for i in range(quantidade_frutas):

		var ponto: Vector2 = Vector2(0, comprimento) + _posicao_configurada(i)
		var desenho: Texture2D = texturas_frutas[i] if i < texturas_frutas.size() and texturas_frutas[i] != null else textura

		if desenho != null:

			var tamanho: Vector2 = desenho.get_size()
			var fator: float = 24.0 / maxf(maxf(tamanho.x, tamanho.y), 1.0)
			draw_texture_rect(desenho, Rect2(ponto - tamanho * fator * 0.5, tamanho * fator), false)

		else:

			draw_circle(ponto, 9, Color.WHITE)

		draw_string(ThemeDB.fallback_font, ponto + Vector2(10, -6), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 12)

# Acompanhar os marcadores da prévia
# ---------------------
# Atualiza o desenho somente quando uma posição manual muda.
func _posicoes_marcadores() -> Array[Vector2]:

	var posicoes: Array[Vector2] = []
	var marcadores: Node = get_node_or_null("PosicoesFrutas")

	if marcadores != null:

		for filho in marcadores.get_children():

			if filho is Node2D:

				posicoes.append(filho.position)

	return posicoes
