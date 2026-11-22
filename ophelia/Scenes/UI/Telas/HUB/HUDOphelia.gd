extends CanvasLayer
@onready var menu_interno: Control = $MenuInterno/TelaMenu

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS

func _input(event: InputEvent) -> void:
    if event is InputEventKey and event.echo:
        return
    if not event.is_action_pressed(&"ControlePausar"):
        return
    if menu_interno != null and bool(menu_interno.get("aberto")):
        get_viewport().set_input_as_handled()
        menu_interno.call("voltar_ou_fechar")
    elif not get_tree().paused:
        get_viewport().set_input_as_handled()
        menu_interno.call("abrir")
