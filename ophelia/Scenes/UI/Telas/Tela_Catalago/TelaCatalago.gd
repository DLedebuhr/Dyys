extends Control
## Mostra somente as espécies catalogadas no slot ativo.
## A arte de fundo e todas as posições dos TextureRect permanecem na cena original.
signal voltar_inventario_solicitado()
signal progresso_solicitado()

@export_group("Imagens opcionais por espécie")
@export var imagens_especies: Dictionary = {}
@export_group("Visual das espécies")
@export var mostrar_nome_no_hover: bool = true

const PASTA_ICONES := "res://Assets/Textures/UI/Tela_Inventario/Capsulas"
const ESPECIES := {
    "Calla": "IconeCallaEncapsulada.png",
    "Lotus": "IconeL#U00f3tusEncapsulada.png",
    "Lirio": "IconeL#U00edrioEncapsulada.png",
    "Cosmos": "IconeCosmosEncapsulada.png",
    "Lavanda": "IconeLavandaEncapsulada.png",
    "Colquico": "IconeC#U00f3lquicoEncapsulada.png",
    "Princesa": "IconePrincesaEncapsulada.png",
    "Viola": "IconeViolaEncapsulada.png",
    "Dalia": "IconeD#U00e1liaEncapsulada.png",
    "Azaleia": "IconeAzaleiaEncapsulada.png",
    "Heleboro": "IconeHel#U00e9boroEncapsulada.png",
    "Primula": "IconePr#U00edmulaEncapsulada.png",
    "FlocoNeve": "IconeFlocoNeveEncapsulada.png",
    "Ciclame": "IconeCiclameEncapsulada.png",
    "Camelia": "IconeCam#U00e9liaEncapsulada.png",
    "Muguet": "IconeMuguetEncapsulada.png",
    "Sakura": "IconeSakuraEncapsulada.png",
    "Narciso": "IconeNarcisoEncapsulada.png",
    "Iris": "Iconen#U00cdrisEncapsulada.png",
    "Tulipa": "IconeTulipaEncapsulada.png"
}

const EFEITO_REGISTRO = preload("res://Scenes/UI/Telas/Tela_Catalago/ParticulasRegistroFlor.gd")
@export_group("Efeito de nova espécie")
@export_range(0.6, 3.0, 0.05) var duracao_novo_registro: float = 1.45
@export_range(0.0, 1.0, 0.05) var pausa_entre_registros: float = 0.22
var _aberto: bool = false
var _efeito_atual: Control
var _tempo_pausa: float = -1.0
var _fila_bloqueada: bool = false
var _geracao_fila: int = 0
const TRANSICAO_TELAS = preload("res://Scenes/UI/Telas/TransicaoCompartilhada.gd")
var _animacao := TRANSICAO_TELAS.new()


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    # A cena é aberta pelo inventário sobre a partida pausada.
    hide()
    var voltar := get_node_or_null("Navegacao/Inventario") as BaseButton
    if voltar != null:
        voltar.pressed.connect(_voltar_ao_inventario)
    var progresso := get_node_or_null("Navegacao/Progresso") as BaseButton
    if progresso != null:
        progresso.pressed.connect(_ao_pedir_progresso)
    var fundo := get_node_or_null("Fundo") as Control
    if fundo != null:
        fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _atualizar_especies()
    for nome_fundo in ["FundoCorPadrao", "FundoCor"]:
        var camada: CanvasItem = get_node_or_null(nome_fundo) as CanvasItem
        if camada != null:
            camada.hide()

func abrir(_atraso: float = 0.0) -> void:
    _atualizar_especies()
    _aberto = true
    _fila_bloqueada = false
    _geracao_fila += 1
    _tempo_pausa = -1.0
    _animacao.abrir(self, false, _mostrar_proxima_animacao, _atraso)

func fechar(notificar: bool = true, concluido: Callable = Callable()) -> void:
    if not _aberto:
        return
    _aberto = false
    _geracao_fila += 1
    _tempo_pausa = -1.0
    if is_instance_valid(_efeito_atual):
        _efeito_atual.queue_free()
    _efeito_atual = null
    _animacao.fechar(self, func() -> void:
        if concluido.is_valid():
            concluido.call()
        if notificar:
            voltar_inventario_solicitado.emit()
    )

func _voltar_ao_inventario() -> void:
    fechar()

func _ao_pedir_progresso() -> void:
    progresso_solicitado.emit()

# A navegação pelas teclas I/C/P/Esc é centralizada no inventário.
# Aqui ficam somente os botões da cena.

func _atualizar_especies() -> void:
    for estacao in ["Verao", "Outono", "Inverno", "Primavera"]:
        var grupo := get_node_or_null(estacao)
        if grupo == null:
            continue
        for filho in grupo.get_children():
            if not (filho is TextureRect):
                continue
            var retrato := filho as TextureRect
            var especie := StringName(retrato.name)
            if not ESPECIES.has(String(especie)):
                continue
            # O campo mantém exatamente a posição e o tamanho escolhidos no editor.
            retrato.mouse_filter = Control.MOUSE_FILTER_IGNORE
            retrato.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
            retrato.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
            var registrada := EstadoPartida.especie_registrada(especie)
            var pendente: bool = EstadoPartida.animacoes_catalogo_pendentes().has(String(especie))
            retrato.texture = _icone(especie) if registrada and not pendente else null
            # Nenhum aviso/tooltip sobre a arte: os avisos pertencem ao painel de ajuda.
            retrato.tooltip_text = ""

func _icone(especie: StringName) -> Texture2D:
    var personalizada := imagens_especies.get(especie) as Texture2D
    if personalizada != null:
        return personalizada
    var nome_arquivo: String = ESPECIES.get(String(especie), "")
    if nome_arquivo.is_empty():
        return null
    var caminho := PASTA_ICONES.path_join(nome_arquivo)
    if not ResourceLoader.exists(caminho):
        push_warning("Catálogo: ícone não encontrado: " + caminho)
        return null
    return load(caminho) as Texture2D

# Apenas um registro por vez, obedecendo a ordem salva no slot ativo.
func _mostrar_proxima_animacao() -> void:
    if not _aberto or _fila_bloqueada or is_instance_valid(_efeito_atual):
        return
    var pendentes: Array = EstadoPartida.animacoes_catalogo_pendentes()
    if pendentes.is_empty():
        return
    var especie := StringName(pendentes[0])
    var retrato: TextureRect = _retrato_da_especie(especie)
    if retrato == null:
        # Nunca descartar silenciosamente uma espécie: ela permanece pendente.
        push_warning("Catálogo: não há posição para a espécie pendente: " + String(especie))
        _fila_bloqueada = true
        return
    var centro: Vector2 = get_global_transform().affine_inverse() * retrato.get_global_rect().get_center()
    var icone: Texture2D = _icone(especie)
    _efeito_atual = EFEITO_REGISTRO.new() as Control
    add_child(_efeito_atual)
    _efeito_atual.connect("terminou", Callable(self, "_ao_terminar_animacao").bind(especie), CONNECT_ONE_SHOT)
    _efeito_atual.call("iniciar", icone, centro, retrato.size, true, duracao_novo_registro)

func _ao_terminar_animacao(especie: StringName) -> void:
    _efeito_atual = null
    if not _aberto:
        return
    if not EstadoPartida.confirmar_animacao_catalogo(especie):
        push_warning("Catálogo: falha ao marcar a animação de %s como exibida." % String(especie))
        _fila_bloqueada = true
        return
    var retrato: TextureRect = _retrato_da_especie(especie)
    if retrato != null:
        retrato.texture = _icone(especie)
    # Prossegue mesmo com a partida pausada. A geração impede que um callback
    # antigo reabra a animação após sair da tela.
    _aguardar_proxima_animacao(_geracao_fila)

func _aguardar_proxima_animacao(geracao: int) -> void:
    if pausa_entre_registros > 0.0:
        await get_tree().create_timer(pausa_entre_registros, true).timeout
    if is_inside_tree() and _aberto and geracao == _geracao_fila:
        _mostrar_proxima_animacao()


func _retrato_da_especie(especie: StringName) -> TextureRect:
    for estacao in ["Verao", "Outono", "Inverno", "Primavera"]:
        var retrato := get_node_or_null(NodePath(estacao + "/" + String(especie))) as TextureRect
        if retrato != null:
            return retrato
    return null

func _icone_encapsulada(especie: StringName) -> Texture2D:
    # Todas as apresentações e registros utilizam as mesmas artes encapsuladas.
    return _icone(especie)
