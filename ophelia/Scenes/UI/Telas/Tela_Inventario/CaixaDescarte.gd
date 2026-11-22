@tool
extends TextureRect
## Caixa de descarte: só a pilha solta nesta área é removida.
## É possível arrastar a posição, alterar o tamanho e atribuir uma Texture no Inspector.

@export var tela_inventario: CanvasLayer
@export var mostrar_guia_sem_imagem: bool = true
@export var cor_guia: Color = Color(1.0, 0.55, 0.35, 0.85)

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_STOP
    expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    tooltip_text = "Arraste um item aqui para descartar a pilha inteira."
    resized.connect(queue_redraw)
    queue_redraw()

# Borda e X provisórios, visíveis no editor e no jogo apenas quando falta a textura.
func _draw() -> void:
    if not mostrar_guia_sem_imagem or texture != null:
        return
    var quadro := Rect2(Vector2.ZERO, size)
    draw_rect(quadro, Color(cor_guia.r, cor_guia.g, cor_guia.b, 0.18), true)
    draw_rect(quadro, cor_guia, false, 3.0)
    var centro := size * 0.5
    var diagonal := minf(size.x, size.y) * 0.16
    draw_line(centro - Vector2(diagonal, diagonal), centro + Vector2(diagonal, diagonal), cor_guia, 3.0, true)
    draw_line(centro + Vector2(-diagonal, diagonal), centro + Vector2(diagonal, -diagonal), cor_guia, 3.0, true)

func _inventario_real() -> Node:
    if not is_instance_valid(tela_inventario):
        return null
    return tela_inventario.get("inventario") as Node

func _can_drop_data(_posicao: Vector2, dados: Variant) -> bool:
    if Engine.is_editor_hint() or not (dados is Dictionary):
        return false
    var inv := _inventario_real()
    if inv == null or not inv.has_method("consultar") or not inv.has_method("descartar"):
        return false
    if tela_inventario.has_method("em_transicao") and bool(tela_inventario.call("em_transicao")):
        return false
    if int(dados.get("bolsa", -1)) != inv.get_instance_id():
        return false
    var local := StringName(dados.get("local", ""))
    var indice := int(dados.get("indice", -1))
    var atual: Dictionary = inv.call("consultar", local, indice)
    return int(atual.get("quantidade", 0)) > 0 and StringName(atual.get("id", "")) == StringName(dados.get("id", ""))

func _drop_data(posicao: Vector2, dados: Variant) -> void:
    if not _can_drop_data(posicao, dados):
        return
    var inv := _inventario_real()
    if inv == null:
        return
    if bool(inv.call("descartar", StringName(dados.get("local", "")), int(dados.get("indice", -1)), StringName(dados.get("id", "")))):
        tela_inventario.call("selecionar", null)
