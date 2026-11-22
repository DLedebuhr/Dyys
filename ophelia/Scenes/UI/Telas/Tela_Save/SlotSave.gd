extends Control
class_name SlotSave

signal slot_selecionado(slot_index: int, data: SaveData)

@export_range(0, 3) var slot_index: int = 0
@export var texturas_progresso: Array[Texture2D] = []

@onready var botao_slot: TextureButton = $BotaoSlot
@onready var imagem_progresso: TextureRect = $BotaoSlot/ImagemProgresso

var save_data_atual: SaveData
var _preview_ativo: bool = false
var _tween_preview: Tween

func _ready() -> void:
    imagem_progresso.mouse_filter = Control.MOUSE_FILTER_IGNORE
    botao_slot.mouse_filter = Control.MOUSE_FILTER_STOP
    botao_slot.pressed.connect(_ao_clicar)
    atualizar_exibicao(EstadoPartida.ler_slot(slot_index))

func atualizar_exibicao(dados: SaveData) -> void:
    save_data_atual = dados
    if not _preview_ativo:
        _mostrar_progresso_real()

func _mostrar_progresso_real() -> void:
    if texturas_progresso.is_empty():
        imagem_progresso.texture = null
        return
    var fase := 0
    if save_data_atual != null and save_data_atual.ocupado:
        fase = clampi(save_data_atual.progresso_fase, 0, 6)
    imagem_progresso.texture = texturas_progresso[clampi(fase, 0, texturas_progresso.size() - 1)]

# MostrarEnfeite percorre apenas as imagens estáticas. Não modifica o save.
func mostrar_enfeite() -> void:
    if _tween_preview != null and _tween_preview.is_running():
        _tween_preview.kill()
    _preview_ativo = true
    if texturas_progresso.is_empty():
        return
    _tween_preview = create_tween()
    for i in range(texturas_progresso.size()):
        var textura: Texture2D = texturas_progresso[i]
        _tween_preview.tween_callback(func() -> void: imagem_progresso.texture = textura)
        _tween_preview.tween_interval(0.10)

func ocultar_enfeite() -> void:
    if _tween_preview != null and _tween_preview.is_running():
        _tween_preview.kill()
    _preview_ativo = false
    _mostrar_progresso_real()

func _ao_clicar() -> void:
    slot_selecionado.emit(slot_index, save_data_atual)
