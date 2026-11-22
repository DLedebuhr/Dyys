extends Control
const AJUSTES := "res://Scenes/UI/Telas/Tela_Ajustes/TelaAjustes.tscn"
const CONTROLES := "res://Scenes/UI/Telas/Tela_Controles/TelaControles.tscn"

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    var ajustes: BaseButton = get_node_or_null("Navegacao/Ajustes") as BaseButton
    var controles: BaseButton = get_node_or_null("Navegacao/Controles") as BaseButton
    if ajustes != null: ajustes.pressed.connect(func(): _ir(&"ajustes"))
    if controles != null: controles.pressed.connect(func(): _ir(&"controles"))

func _ir(destino: StringName) -> void:
    if get_parent() != null and get_parent().has_method("abrir_subtela"):
        get_parent().call("abrir_subtela", destino)
    else:
        get_tree().change_scene_to_file(AJUSTES if destino == &"ajustes" else CONTROLES)
