extends Node
## Aplica o slot carregado ao entrar numa cena e autosalva sem capturar o modo debug.
@export_range(3.0, 120.0, 1.0) var intervalo_autosave: float = 15.0
@export_range(0.2, 10.0, 0.1) var espera_apos_alteracao: float = 1.5
var _ophelia: CharacterBody2D
var _tempo: float = 0.0
var _pendente: float = -1.0
var _pronto: bool = false

func _ready() -> void:
    _ophelia = get_parent() as CharacterBody2D
    if _ophelia == null:
        return
    call_deferred("_iniciar")

func _iniciar() -> void:
    if EstadoPartida.partida == null:
        return
    var p := EstadoPartida.partida
    var dado: Dictionary = p.dados_jogo
    var bolsa := _ophelia.get_node_or_null("Inventario")
    var hab := _ophelia.get_node_or_null("Habilidades")
    var vida := _ophelia.get_node_or_null("Vitalidade")
    var chapeu := _ophelia.get_node_or_null("CheckpointChapeu")
    if bolsa != null and bolsa.has_method("importar_estado_save"):
        # Limpa os itens provisórios do Inspector num novo slot, sem gravá-los como progresso.
        bolsa.call("importar_estado_save", dado.get("inventario", {}))
    if hab != null and hab.has_method("importar_estado"):
        hab.call("importar_estado", dado.get("habilidades", []))
    if vida != null:
        vida.set("vida_maxima", clampi(int(dado.get("vida_maxima", vida.get("vida_maxima"))), 1, 6))
        vida.set("vida_atual", clampf(float(dado.get("vida", vida.get("vida_maxima"))), 0.01, float(vida.get("vida_maxima"))))
        vida.emit_signal("vida_alterada", vida.get("vida_atual"), vida.get("vida_maxima"))
    _ophelia.set("catalogo_completo", bool(dado.get("catalogo_completo", false)))
    if bool(dado.get("posicao_valida", false)):
        var pos: Array = dado.get("posicao", [])
        if pos.size() == 2:
            _ophelia.global_position = Vector2(float(pos[0]), float(pos[1]))
    if chapeu != null and chapeu.has_method("importar_estado_save"):
        chapeu.call("importar_estado_save", dado.get("chapeu", {}))
    EstadoPartida.restaurar_cenario(get_tree())
    _restaurar_perdidos(dado.get("itens_perdidos", []))
    if bolsa != null and bolsa.has_signal("alterado"):
        bolsa.connect("alterado", _solicitar_salvar)
    if hab != null:
        hab.connect("habilidade_desbloqueada", _solicitar_salvar)
    if vida != null:
        vida.connect("vida_alterada", _solicitar_salvar)
    _pronto = true
    EstadoPartida.carregamento_pendente = false
    _solicitar_salvar()

func _restaurar_perdidos(lista: Array) -> void:
    var mundo: Node = get_tree().current_scene
    if mundo == null:
        return
    for atual in get_tree().get_nodes_in_group("item_perdido_ophelia"):
        atual.queue_free()
    var script_perdido = preload("res://Ophelia/Inventario/ItemPerdido.gd")
    for registro in lista:
        if not (registro is Dictionary):
            continue
        var p: Array = registro.get("posicao", [])
        if p.size() != 2 or float(registro.get("restante", 0.0)) <= 0:
            continue
        var novo: Node2D = script_perdido.new()
        novo.call("configurar", registro, _ophelia, _ophelia.get_node("Inventario"), float(registro["restante"]), 56.0)
        mundo.add_child(novo)
        novo.global_position = Vector2(float(p[0]), float(p[1]))

func _solicitar_salvar(_a = null, _b = null) -> void:
    if _pronto:
        _pendente = espera_apos_alteracao

func _process(delta: float) -> void:
    if not _pronto:
        return
    _tempo += delta
    if _pendente >= 0.0:
        _pendente -= delta
    if _tempo >= intervalo_autosave or (_pendente >= -0.1 and _pendente <= 0.0):
        salvar_agora()

func salvar_agora() -> void:
    if not _pronto:
        return
    _tempo = 0.0
    _pendente = -1.0
    EstadoPartida.salvar_personagem(_ophelia)

func _exit_tree() -> void:
    if _pronto and is_instance_valid(_ophelia) and not EstadoPartida.carregamento_pendente and EstadoPartida.partida != null:
        EstadoPartida.salvar_personagem(_ophelia)
