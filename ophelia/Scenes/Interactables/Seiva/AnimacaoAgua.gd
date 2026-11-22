@tool
extends Node2D
## Somente efeitos visuais. Os três pontos são origens esquerdas das superfícies.
@export var mostrar_quedas: bool = true
@export_range(0, 1) var opacidade_quedas: float = 0.52
@export_group("Queda 1 para 2")
@export_range(1, 250) var espessura_inicio_12: float = 24.0
@export_range(1, 250) var espessura_final_12: float = 48.0
@export_group("Queda 2 para 3")
@export_range(1, 250) var espessura_inicio_23: float = 35.0
@export_range(1, 250) var espessura_final_23: float = 72.0
@export_group("Chegada da agua")
@export_range(0, 1) var clareza_final: float = 0.65
@export_range(1, 300) var extensao_clara: float = 120
@export_group("Opacidade no final da queda")
@export_range(0, 1) var inicio_opacidade_final: float = 0.78
@export_range(0, 1) var opacidade_final: float = 0.65
@export_group("Som da agua")
@export var som_agua: AudioStream
@export var ouvinte: Node2D
@export var repetir_som: bool = true
@export_range(20, 3000) var alcance_som: float = 700.0
@export_range(0.2, 4) var curva_volume: float = 1.4
@export_range(-60, 0) var volume_bacia_1_db: float = -22.0
@export_range(-60, 0) var volume_bacia_2_db: float = -12.0
@export_range(-60, 0) var volume_bacia_3_db: float = -6.0
@export var bus_som: StringName = &"Master"
@export_group("Movimento")
@export_range(0.02, 1) var velocidade_na_bacia: float = 0.12
@export_range(0.1, 3) var velocidade_na_queda: float = 1.0
@export_range(0, 500) var distancia_sem_detalhes: float = 150
@export_range(1, 500) var distancia_aparecimento: float = 220
@export_range(0.05, 3.0) var velocidade_fluxo: float = 0.45
var fontes_som: Array[AudioStreamPlayer] = []
var stream_atual: AudioStream



# Preparar o áudio da água
# ---------------------
# Cria os três emissores de som somente durante a partida.
func _ready() -> void:

	if Engine.is_editor_hint():

		return
	for i in range(3):

		var player := AudioStreamPlayer.new()
		player.name = "SomBacia%d" % (i + 1)
		player.volume_db = -80
		player.finished.connect(_repetir.bind(player))
		add_child(player)
		fontes_som.append(player)



# Repetir o som
# ---------------------
# Reinicia a reprodução quando a repetição está habilitada.
func _repetir(player: AudioStreamPlayer) -> void:

	if repetir_som and som_agua != null:

		player.play()



# Sincronizar as bacias e quedas
# ---------------------
# Propaga os ajustes visuais existentes e atualiza o áudio por proximidade.
func _process(_delta: float) -> void:

	if not is_node_ready():

		return
	# Um único preenchimento e um único shader para cada bacia de origem + queda.
	for par in [[$Queda12, $Ponto1/Agua], [$Queda23, $Ponto2/Agua]]:

		var q: Node2D = par[0]
		var b: Node2D = par[1]
		q.bacia_pos = q.to_local(b.global_position)
		q.bacia_tamanho = b.tamanho
		q.bacia_desnivel = b.desnivel
		q.reservatorio_ondas = b
		b.integrada = true
	$Queda12.inicio = $Inicio12.position
	$Queda12.fim = $Fim12.position
	$Queda23.inicio = $Inicio23.position
	$Queda23.fim = $Fim23.position
	for q in [$Queda12, $Queda23]:

		q.visible = mostrar_quedas
		q.opacidade = opacidade_quedas
		q.velocidade = velocidade_fluxo
		q.clareza_final = clareza_final
		q.extensao_clara = extensao_clara
		q.inicio_opacidade_final = inicio_opacidade_final
		q.opacidade_final = opacidade_final
		q.velocidade_bacia = velocidade_na_bacia
		q.velocidade_queda = velocidade_na_queda
		q.atraso_detalhes = distancia_sem_detalhes
		q.suavidade_inicio = distancia_aparecimento
	$Queda12.espessura_inicio = espessura_inicio_12
	$Queda12.espessura_final = espessura_final_12
	$Queda23.espessura_inicio = espessura_inicio_23
	$Queda23.espessura_final = espessura_final_23
	if not Engine.is_editor_hint():

		_atualizar_som(_delta)



# Calcular o volume por distância
# ---------------------
# Aplica a atenuação original conforme a posição do ouvinte.
func volume_por_distancia(base_db: float, distancia: float) -> float:

	var ganho: float = pow(clampf(1.0 - distancia / maxf(alcance_som, 1), 0, 1), curva_volume)
	return maxf(-80, base_db + linear_to_db(maxf(ganho, 0.00001)))



# Atualizar o som das bacias
# ---------------------
# Mantém os volumes e as transições definidos para cada ponto da fonte.
func _atualizar_som(delta: float) -> void:

	if fontes_som.size() != 3:

		return
	if stream_atual != som_agua:

		stream_atual = som_agua
		var audio: AudioStream = som_agua.duplicate() as AudioStream if som_agua != null else null
		if repetir_som and audio != null:

			if audio is AudioStreamOggVorbis or audio is AudioStreamMP3:

				audio.loop = true
			elif audio is AudioStreamWAV:

				audio.loop_mode = AudioStreamWAV.LOOP_FORWARD
				audio.loop_begin = 0
				audio.loop_end = int(audio.get_length() * audio.mix_rate)
		for player in fontes_som:

			player.stop()
			player.stream = audio
			if audio != null:

				player.play()
	var pos_ouvinte: Vector2
	if is_instance_valid(ouvinte):

		pos_ouvinte = ouvinte.global_position
	else:

		pos_ouvinte = (
			get_viewport().get_canvas_transform().affine_inverse()
			* (get_viewport_rect().size * 0.5)
		)
	var posicoes: Array[Vector2] = [
		(
			$Ponto1/Agua.global_position
			+ global_transform.basis_xform(Vector2($Ponto1/Agua.tamanho.x * 0.5, 0))
		),
		to_global($Fim12.position),
		to_global($Fim23.position)
	]
	var volumes: Array[float] = [volume_bacia_1_db, volume_bacia_2_db, volume_bacia_3_db]
	for i in range(3):

		fontes_som[i].bus = bus_som
		var alvo: float = volume_por_distancia(volumes[i], pos_ouvinte.distance_to(posicoes[i]))
		fontes_som[i].volume_db = move_toward(fontes_som[i].volume_db, alvo, delta * 100)
