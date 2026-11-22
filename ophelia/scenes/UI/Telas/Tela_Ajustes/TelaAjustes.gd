extends Control
const PRINCIPAL := "res://Scenes/UI/Telas/Tela_Principal/TelaPrincipal.tscn"
const VOLUME := "res://Scenes/UI/Telas/Tela_Volume/AjustesVolume.tscn"
const CONTROLES := "res://Scenes/UI/Telas/Tela_Controles/TelaControles.tscn"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_conectar("HBoxContainer/Volume", &"volume")
	_conectar("HBoxContainer/Controles", &"controles")
	_conectar("Navegacao/Volume", &"volume")
	var voltar: BaseButton = get_node_or_null("Navegacao/Iniciar") as BaseButton
	if voltar != null:
		voltar.pressed.connect(_voltar)

func _conectar(caminho: String, destino: StringName) -> void:
	var botao: BaseButton = get_node_or_null(caminho) as BaseButton
	if botao != null:
		botao.pressed.connect(func(): _abrir(destino))

func _abrir(destino: StringName) -> void:
	if get_parent() != null and get_parent().has_method("abrir_subtela"):
		get_parent().call("abrir_subtela", destino)
	else:
		get_tree().change_scene_to_file(VOLUME if destino == &"volume" else CONTROLES)

func _voltar() -> void:
	if get_parent() != null and get_parent().has_method("voltar_ou_fechar"):
		get_parent().call("voltar_ou_fechar")
	else:
		get_tree().change_scene_to_file(PRINCIPAL)
