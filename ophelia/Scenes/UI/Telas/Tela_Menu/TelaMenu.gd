extends Control
## Pausa; permite salvar, voltar ao menu inicial e abrir Ajustes / Volume / Controles.
## Esta cena fica como uma sobreposição no HUD, sem mudar de nível.
const PRINCIPAL := "res://Scenes/UI/Telas/Tela_Principal/TelaPrincipal.tscn"
const PAGINAS := {
    &"ajustes": "res://Scenes/UI/Telas/Tela_Ajustes/TelaAjustes.tscn",
    &"volume": "res://Scenes/UI/Telas/Tela_Volume/AjustesVolume.tscn",
    &"controles": "res://Scenes/UI/Telas/Tela_Controles/TelaControles.tscn"
}
var aberto: bool = false
var _subtela: Control
var _pagina: StringName = &""
var _guardando: bool = false

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    add_to_group("menu_interno_ophelia")
    hide()
    var salvar: BaseButton = get_node_or_null("HBoxContainer/Salvar") as BaseButton
    var ajustes: BaseButton = get_node_or_null("HBoxContainer/Ajustes") as BaseButton
    var sair: BaseButton = get_node_or_null("HBoxContainer/Sair") as BaseButton
    if salvar != null: salvar.pressed.connect(salvar_agora)
    if ajustes != null: ajustes.pressed.connect(func(): abrir_subtela(&"ajustes"))
    if sair != null: sair.pressed.connect(sair_para_tela_principal)

func abrir() -> void:
    if aberto:
        return
    aberto = true
    get_tree().paused = true
    show()
    modulate.a = 0.0
    create_tween().tween_property(self, "modulate:a", 1.0, 0.22)

func fechar() -> void:
    if not aberto:
        return
    _limpar_subtela()
    aberto = false
    var t: Tween = create_tween()
    t.tween_property(self, "modulate:a", 0.0, 0.18)
    t.finished.connect(func():
        hide()
        get_tree().paused = false
    )

func voltar_ou_fechar() -> void:
    if _subtela != null:
        _limpar_subtela()
    else:
        fechar()

func abrir_subtela(pagina: StringName) -> void:
    if not PAGINAS.has(pagina):
        return
    _limpar_subtela()
    var arquivo: String = PAGINAS[pagina]
    var cena: PackedScene = load(arquivo) as PackedScene
    if cena == null:
        push_error("Não foi possível abrir a tela interna: " + arquivo)
        return
    _subtela = cena.instantiate() as Control
    if _subtela == null:
        return
    _subtela.process_mode = Node.PROCESS_MODE_ALWAYS
    add_child(_subtela)
    _pagina = pagina
    $HBoxContainer.hide()
    $Fundo.hide()
    var fundo: CanvasItem = _subtela.get_node_or_null("FundoCorPadrao") as CanvasItem
    if fundo != null:
        fundo.show()

func _limpar_subtela() -> void:
    if is_instance_valid(_subtela):
        _subtela.queue_free()
    _subtela = null
    _pagina = &""
    $HBoxContainer.show()
    $Fundo.show()

func salvar_agora() -> void:
    if _guardando:
        return
    _guardando = true
    var jogador: Node2D = get_tree().get_first_node_in_group("jogador") as Node2D
    if jogador != null and EstadoPartida.partida != null:
        EstadoPartida.salvar_personagem(jogador)
        print("Menu: partida salva no slot ", EstadoPartida.slot_ativo + 1)
    else:
        push_warning("Salvar indisponível: personagem ou slot ativo não encontrado.")
    _guardando = false

func sair_para_tela_principal() -> void:
    salvar_agora()
    aberto = false
    get_tree().paused = false
    EstadoPartida.encerrar_slot()
    FundoParticulas.ativar()
    get_tree().change_scene_to_file(PRINCIPAL)
