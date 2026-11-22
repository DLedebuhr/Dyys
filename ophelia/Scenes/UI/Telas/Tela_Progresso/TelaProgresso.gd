extends Control
## Tela de progresso: navegação funcional; conteúdo poderá ser implementado depois.
signal inventario_solicitado()
signal catalogo_solicitado()

const TRANSICAO_TELAS = preload("res://Scenes/UI/Telas/TransicaoCompartilhada.gd")
var _animacao := TRANSICAO_TELAS.new()

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    hide()
    var botao_inventario: BaseButton = get_node_or_null("Navegacao/Inventario") as BaseButton
    var botao_catalogo: BaseButton = get_node_or_null("Navegacao/Catalago") as BaseButton
    if botao_inventario != null:
        botao_inventario.pressed.connect(func(): inventario_solicitado.emit())
    if botao_catalogo != null:
        botao_catalogo.pressed.connect(func(): catalogo_solicitado.emit())
    for nome_fundo in ["FundoCorPadrao", "FundoCor"]:
        var camada: CanvasItem = get_node_or_null(nome_fundo) as CanvasItem
        if camada != null:
            camada.hide()

func abrir(_atraso: float = 0.0) -> void:
    _animacao.abrir(self, false, Callable(), _atraso)

func fechar(_notificar: bool = false, concluido: Callable = Callable()) -> void:
    if not visible:
        return
    _animacao.fechar(self, concluido)
