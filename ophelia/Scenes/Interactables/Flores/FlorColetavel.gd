@tool
extends Node2D

@export_group("Espécie")
@export_enum("Calla", "Lavanda", "Cosmos", "Lotus", "Lirio", "Viola", "Colquico", "Princesa", "Azaleia", "Dalia", "Heleboro", "Ciclame", "Camelia", "Primula", "FlocoNeve", "Tulipa", "Muguet", "Iris", "Narciso", "Sakura") var especie: String = "Calla":
	set(valor):
		especie = valor

		if is_inside_tree():

			carregar_texturas.call_deferred()

@export_dir var pasta_flores: String = "res://Assets/Textures/Flowers"
@export_group("Coleta e regeneração")
@export_range(1.0, 600.0, 1.0) var segundos_regeneracao: float = 10.0
@export_range(10.0, 500.0, 1.0) var distancia_coleta: float = 100.0
@export var acao_interagir: StringName = &"ControleInteragir"
@export_group("Reaparecimento suave")
@export_range(0.1, 3.0, 0.05) var duracao_reaparecer: float = 0.65
@export_group("Partículas da flor — efeito do teaser")
@export var cor_particulas: Color = Color(1.0, 0.95, 0.6)
@export_range(1, 100, 1) var quantidade_brilho: int = 18
@export_range(1.0, 300.0, 1.0) var alcance_brilho: float = 70.0
@export_range(0.1, 3.0, 0.05) var duracao_brilho: float = 0.7
@export_range(0.05, 5.0, 0.05) var tamanho_brilho: float = 1.0
@export_group("Som")
@export var som_coleta: AudioStream
@export var volume_coleta_db: float = 0.0
@export var barramento_som: StringName = &"Master"
@export_tool_button("Atualizar texturas") var atualizar_texturas = carregar_texturas
@export_tool_button("Preparar marcadores") var preparar_pontos = preparar_marcadores

var _transicao_visual: Tween
var _material_original: Material
var _capturou_material: bool = false

var _texturas: Array[Texture2D] = []
var _quantidade: int = 0
var _capacidade: int = 0
var _tempo_restante: float = 0.0

# Preparar a planta
# ---------------------
# Carrega a espécie e participa da mesma seleção de interação das frutas.
func _ready() -> void:

	carregar_texturas()

	if not Engine.is_editor_hint():

		add_to_group("coletaveis_ophelia")

# Carregar os estados da espécie
# ---------------------
# Exige numeração contínua, começando em zero; o último estado define a capacidade.
func carregar_texturas() -> void:

	var imagem: Sprite2D = get_node_or_null("Imagem") as Sprite2D

	if imagem == null:

		return

	if not _capturou_material:

		_material_original = imagem.material
		_capturou_material = true

	if _transicao_visual != null and _transicao_visual.is_valid():

		_transicao_visual.kill()

	imagem.material = _material_original
	_texturas.clear()
	_capacidade = 0
	_quantidade = 0
	_tempo_restante = 0.0

	var pasta: String = pasta_flores.path_join(especie)
	var diretorio: DirAccess = DirAccess.open(pasta)

	if diretorio == null:

		push_warning("Flores: pasta não encontrada: " + pasta)
		return

	var encontrados: Dictionary = {}

	for arquivo in diretorio.get_files():

		var nome: String = String(arquivo).trim_suffix(".import").trim_suffix(".remap")

		if nome.get_extension().to_lower() not in ["png", "webp", "svg", "jpg", "jpeg"]:

			continue

		var base: String = nome.get_basename()

		if not base.begins_with(especie):

			continue

		var numero: String = base.trim_prefix(especie)

		if numero.is_empty() or not numero.is_valid_int() or int(numero) < 0:

			continue

		var textura: Texture2D = load(pasta.path_join(nome)) as Texture2D

		if textura != null:

			encontrados[int(numero)] = textura

	if encontrados.size() < 2:

		push_warning("Flores: adicione " + especie + "0 e pelo menos o estado 1.")
		return

	for i in range(encontrados.size()):

		if not encontrados.has(i):

			push_warning("Flores: falta o estado " + especie + str(i) + ".")
			_texturas.clear()
			return

		_texturas.append(encontrados[i])

	_capacidade = _texturas.size() - 1
	_quantidade = _capacidade
	imagem.texture = _texturas[_quantidade]

# Verificar a coleta
# ---------------------
# Exige flores disponíveis, proximidade e personagem viva.
func pode_interagir(jogador: CharacterBody2D) -> bool:

	if Engine.is_editor_hint() or _quantidade <= 0 or not is_instance_valid(jogador):

		return false

	if get_tree().paused or not jogador.is_in_group("jogador"):

		return false

	if global_position.distance_to(jogador.global_position) > distancia_coleta:

		return false

	var vitalidade: Node = jogador.get_node_or_null("Vitalidade")

	return vitalidade != null and bool(vitalidade.call("esta_viva"))

# Informar a ação disponível
# ---------------------
# O indicador central acrescenta a tecla configurada no Mapa de Entrada.
func obter_mensagem_interacao() -> String:

	return "COLETAR"

# Colher uma flor
# ---------------------
# Só altera a planta depois que o inventário aceita o item.
func interagir(jogador: CharacterBody2D) -> bool:

	if not pode_interagir(jogador):

		return false

	var inventario: Node = jogador.get_node_or_null("Inventario")

	if inventario == null:

		return false

	var id: StringName = StringName("Flor" + especie)

	if not bool(inventario.call("adicionar", id, 1)):

		return false

	var ponto: Node = get_node_or_null("PontosColeta/Flor%d" % _quantidade)

	if ponto == null:

		var temporario: Marker2D = Marker2D.new()
		temporario.set_script(load("res://Scenes/Interactables/Flores/PontoColetaFlor.gd"))
		add_child(temporario)
		temporario.global_position = $Imagem.global_position
		ponto = temporario
		temporario.call_deferred("queue_free")

	if ponto.has_method("emitir"):

		ponto.call("emitir", cor_particulas, quantidade_brilho, alcance_brilho, duracao_brilho, tamanho_brilho)

	_quantidade -= 1
	_mostrar_estado(false)
	_tempo_restante = segundos_regeneracao
	_tocar_som()
	return true

# Recuperar as flores retiradas
# ---------------------
# Retorna uma por intervalo; qualquer nova coleta reinicia a espera.
func _process(delta: float) -> void:

	if Engine.is_editor_hint() or _quantidade >= _capacidade:

		return

	_tempo_restante -= delta

	while _tempo_restante <= 0.0 and _quantidade < _capacidade:

		_quantidade += 1
		_mostrar_estado(true)
		_tempo_restante += maxf(segundos_regeneracao, 0.01)

# Tocar a coleta
# ---------------------
# Permite sobrepor sons de coletas rápidas sem interrompê-los.
func _tocar_som() -> void:

	if som_coleta == null:

		return

	var audio: AudioStreamPlayer2D = AudioStreamPlayer2D.new()
	audio.stream = som_coleta
	audio.volume_db = volume_coleta_db
	audio.bus = barramento_som
	add_child(audio)
	audio.finished.connect(audio.queue_free)
	audio.play()


# Preparar os pontos de coleta no editor
# ---------------------
# Cria somente os marcadores faltantes, preservando posições e cores já ajustadas.
func preparar_marcadores() -> void:

	if not Engine.is_editor_hint():

		return

	var pontos: Node2D = get_node_or_null("PontosColeta") as Node2D

	if pontos == null:

		return

	var dono: Node = get_tree().edited_scene_root
	var script_ponto: Script = load("res://Scenes/Interactables/Flores/PontoColetaFlor.gd") as Script

	for i in range(1, _capacidade + 1):

		var nome: String = "Flor%d" % i

		if pontos.has_node(NodePath(nome)):

			continue

		var ponto: Marker2D = Marker2D.new()
		ponto.name = nome
		ponto.set_script(script_ponto)
		pontos.add_child(ponto)
		ponto.owner = dono


# Mostrar o estado da planta
# ---------------------
# Mantém as partes iguais e faz a flor recuperada ganhar opacidade gradualmente.
func _mostrar_estado(suave: bool) -> void:

	var imagem: Sprite2D = $Imagem
	var anterior: Texture2D = imagem.texture

	if _transicao_visual != null and _transicao_visual.is_valid():

		_transicao_visual.kill()

	imagem.texture = _texturas[_quantidade]
	imagem.material = _material_original

	if not suave or anterior == null:

		return

	var shader: Shader = Shader.new()
	shader.code = """shader_type canvas_item;
uniform sampler2D anterior : filter_linear;
varying vec4 cor_no;
void vertex() { cor_no = COLOR; }
uniform float progresso : hint_range(0.0, 1.0) = 0.0;
void fragment() {
    vec4 modulacao = cor_no;
    COLOR = mix(texture(anterior, UV), texture(TEXTURE, UV), progresso) * modulacao;
}
"""
	var material_transicao: ShaderMaterial = ShaderMaterial.new()
	material_transicao.shader = shader
	material_transicao.set_shader_parameter("anterior", anterior)
	imagem.material = material_transicao
	_transicao_visual = create_tween()
	_transicao_visual.tween_method(func(valor: float): material_transicao.set_shader_parameter("progresso", valor), 0.0, 1.0, duracao_reaparecer).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_transicao_visual.tween_callback(func(): imagem.material = _material_original)
