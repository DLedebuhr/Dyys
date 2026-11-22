extends Control

const CENA_PRINCIPAL := "res://Scenes/UI/Telas/Tela_Principal/TelaPrincipal.tscn"

@onready var slots: Array[SlotSave] = [
    $HBoxContainer/SlotSave,
    $HBoxContainer/SlotSave2,
    $HBoxContainer/SlotSave3,
    $HBoxContainer/SlotSave4
]
@onready var enfeite_revelar: Control = $EnfeiteEsquerda
@onready var botao_voltar: TextureButton = $Voltar

func _ready() -> void:
    for i in range(slots.size()):
        var slot := slots[i]
        slot.slot_index = i
        slot.atualizar_exibicao(EstadoPartida.ler_slot(i))
        slot.slot_selecionado.connect(_ao_selecionar_slot)

    # Área invisível sobre o enfeite que já faz parte do fundo.
    enfeite_revelar.mouse_entered.connect(_mostrar_enfeite)
    enfeite_revelar.mouse_exited.connect(_ocultar_enfeite)
    botao_voltar.pressed.connect(_voltar)

func _mostrar_enfeite() -> void:
    for slot in slots:
        slot.mostrar_enfeite()

func _ocultar_enfeite() -> void:
    for slot in slots:
        slot.ocultar_enfeite()

func _ao_selecionar_slot(indice: int, _dados: SaveData) -> void:
    var dados := EstadoPartida.selecionar_slot(indice)
    if dados == null:
        return
    var destino := dados.cena_atual
    if destino.is_empty() or not ResourceLoader.exists(destino):
        push_warning("Cena salva indisponível; abrindo o tutorial.")
        destino = EstadoPartida.TUTORIAL
        dados.cena_atual = destino
        EstadoPartida.gravar()
    var fundo := get_tree().root.get_node_or_null("FundoParticulas")
    if fundo != null and fundo.has_method("desativar"):
        fundo.call("desativar")
    get_tree().change_scene_to_file(destino)

func _voltar() -> void:
    get_tree().change_scene_to_file(CENA_PRINCIPAL)
