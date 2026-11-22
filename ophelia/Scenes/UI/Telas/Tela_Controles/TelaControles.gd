extends Control
## Painel de controles: cada campo já foi posicionado na cena.
## As imagens são atribuídas APENAS no Inspector, no vetor Imagens Controles.
## Índice 0: imagem-base quando nenhuma área está sob o mouse.
## Índices 1 a 17: seguem a ordem da lista NOMES_AREAS abaixo.

const NOMES_AREAS := [
	"Q", "W", "E", "R", "I", "P",
	"A", "S", "D", "F", "G", "C",
	"TAB", "SHIFT", "ESC", "MouseEsquerdo", "MouseDireito"
]

# Preencha com Texture2D/SVG/PNG no Inspector da raiz.
# O índice 0 é a base. Todos os índices podem ficar vazios por enquanto.
@export var imagens_controles: Array[Texture2D] = [
	null, # 0: Base
	null, # 1: Q
	null, # 2: W
	null, # 3: E
	null, # 4: R
	null, # 5: I
	null, # 6: P
	null, # 7: A
	null, # 8: S
	null, # 9: D
	null, # 10: F
	null, # 11: G
	null, # 12: C
	null, # 13: TAB
	null, # 14: SHIFT
	null, # 15: ESC
	null, # 16: Botão esquerdo do mouse
	null, # 17: Botão direito do mouse
]

@export_file("*.tscn") var cena_ajustes: String = "res://Scenes/UI/Telas/Tela_Ajustes/TelaAjustes.tscn"

@onready var descricao: TextureRect = $TextureRect
@onready var botao_ajustes: TextureButton = $Ajustes

var _areas: Array[Control] = []
var _indice_anterior: int = -1
var _textura_original: Texture2D

func _ready() -> void:
	_textura_original = descricao.texture
	descricao.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Não reposiciona nada: cada campo é usado no lugar em que você deixou.
	for nome in NOMES_AREAS:
		var campo: Control = get_node_or_null("Control/" + nome) as Control
		if campo == null:
			push_warning("Área de controle não encontrada: " + nome)
		else:
			campo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_areas.append(campo)

	process_mode = Node.PROCESS_MODE_ALWAYS
	botao_ajustes.pressed.connect(_abrir_ajustes)
	_mostrar_imagem(0)

func _process(_delta: float) -> void:
	# Verificação por posição: funciona inclusive com Control invisível e
	# não depende de sinais de hover nem altera os campos posicionados.
	var pos_mouse: Vector2 = get_global_mouse_position()
	var novo_indice: int = 0

	for nome_indice in range(_areas.size()):
		var campo: Control = _areas[nome_indice]
		if campo == null or not campo.is_visible_in_tree():
			continue
		if campo.get_global_rect().has_point(pos_mouse):
			novo_indice = nome_indice + 1
			break

	if novo_indice != _indice_anterior:
		_mostrar_imagem(novo_indice)

func _mostrar_imagem(indice: int) -> void:
	_indice_anterior = indice
	var imagem: Texture2D = null

	if indice >= 0 and indice < imagens_controles.size():
		imagem = imagens_controles[indice]

	# Se a imagem da tecla não foi preenchida, usa a imagem-base.
	if imagem == null and imagens_controles.size() > 0:
		imagem = imagens_controles[0]
	if imagem == null:
		imagem = _textura_original

	descricao.texture = imagem

func _abrir_ajustes() -> void:
	_trocar_cena(cena_ajustes)

func _trocar_cena(caminho: String) -> void:
	if get_parent() != null and get_parent().has_method("abrir_subtela"):
		get_parent().call("abrir_subtela", &"ajustes")
		return
	if caminho.is_empty() or not ResourceLoader.exists(caminho, "PackedScene"):
		push_error("Cena de destino não encontrada: " + caminho)
		return
	var erro: Error = get_tree().change_scene_to_file(caminho)
	if erro != OK:
		push_error("Não foi possível abrir a cena: " + caminho + " (" + str(erro) + ")")
