class_name EstadoPartida
extends RefCounted
## Gerente de saves independente de Autoload: os quatro slots são arquivos separados em user://.
## Os métodos estáticos compartilham o slot ativo entre as cenas nesta execução.
const PASTA := "user://partidas"
const TUTORIAL := "res://Scenes/Levels/Tutorial/Tutorial.tscn"
const ETAPAS := {"Tutorial": 0, "Verao": 1, "Outono": 2, "Inverno": 3, "Primavera": 4, "Final": 5, "Topo": 6}
static var slot_ativo: int = -1
static var partida: SaveData
static var carregamento_pendente: bool = false
# Registros e apresentações de teste existem só em memória, sem tocar nos quatro slots.
static var especies_debug: Array[String] = []
static var animacoes_debug: Array[String] = []

static func registrar_especie_debug(id: StringName) -> bool:
    if partida != null or String(id).is_empty() or especies_debug.has(String(id)):
        return false
    especies_debug.append(String(id))
    animacoes_debug.append(String(id))
    return true


static func _caminho(indice: int) -> String:
    return "%s/slot_%d.json" % [PASTA, indice + 1]

static func ler_slot(indice: int) -> SaveData:
    var vazio := SaveData.new()
    vazio.slot_index = indice
    if indice < 0 or indice > 3:
        return vazio
    var caminho := _caminho(indice)
    if not FileAccess.file_exists(caminho):
        return vazio
    var f := FileAccess.open(caminho, FileAccess.READ)
    if f == null:
        push_warning("Não foi possível ler o slot %d" % (indice + 1))
        return vazio
    var json := JSON.new()
    if json.parse(f.get_as_text()) != OK or not (json.data is Dictionary):
        push_warning("Save do slot %d inválido; não será sobrescrito ao carregar." % (indice + 1))
        return vazio
    return SaveData.de_dicionario(indice, json.data)

static func selecionar_slot(indice: int) -> SaveData:
    if indice < 0 or indice > 3:
        return null
    especies_debug.clear()
    animacoes_debug.clear()
    partida = ler_slot(indice)
    # Protege save existente danificado: não substituir por um novo jogo silenciosamente.
    if FileAccess.file_exists(_caminho(indice)) and not partida.ocupado:
        push_error("Slot %d contém save inválido; faça backup e verifique o arquivo." % (indice + 1))
        partida = null
        slot_ativo = -1
        return null
    slot_ativo = indice
    if not partida.ocupado:
        partida.ocupado = true
        partida.progresso_fase = 0
        partida.cena_atual = TUTORIAL
        partida.dados_jogo = {}
        gravar()
    carregamento_pendente = true
    return partida

static func gravar() -> bool:
    if slot_ativo < 0 or slot_ativo > 3 or partida == null:
        return false
    var pasta_abs := ProjectSettings.globalize_path(PASTA)
    if DirAccess.make_dir_recursive_absolute(pasta_abs) != OK:
        push_error("Não foi possível criar diretório de saves: " + pasta_abs)
        return false
    var caminho := _caminho(slot_ativo)
    var temporario := caminho + ".tmp"
    var f := FileAccess.open(temporario, FileAccess.WRITE)
    if f == null:
        push_error("Falha ao gravar save temporário: " + temporario)
        return false
    f.store_string(JSON.stringify(partida.para_dicionario(), "  "))
    f.flush()
    f.close()
    var destino := ProjectSettings.globalize_path(caminho)
    var temp_abs := ProjectSettings.globalize_path(temporario)
    var backup := destino + ".bak"
    if FileAccess.file_exists(caminho):
        if FileAccess.file_exists(caminho + ".bak"):
            DirAccess.remove_absolute(backup)
        if DirAccess.rename_absolute(destino, backup) != OK:
            push_error("Não foi possível criar o backup do save")
            return false
    var erro := DirAccess.rename_absolute(temp_abs, destino)
    if erro != OK:
        if FileAccess.file_exists(caminho + ".bak"):
            DirAccess.rename_absolute(backup, destino)
        push_error("Falha ao confirmar save %d" % (slot_ativo + 1))
        return false
    return true

static func salvar_personagem(ophelia: Node2D, sobrescrever_posicao: bool = true) -> void:
    if partida == null or not partida.ocupado or not is_instance_valid(ophelia):
        return
    var estado: Dictionary = partida.dados_jogo
    var bolsa := ophelia.get_node_or_null("Inventario")
    var hab := ophelia.get_node_or_null("Habilidades")
    var vida := ophelia.get_node_or_null("Vitalidade")
    var checkpoint := ophelia.get_node_or_null("CheckpointChapeu")
    if bolsa != null and bolsa.has_method("exportar_estado_save"):
        estado["inventario"] = bolsa.call("exportar_estado_save")
    if hab != null and hab.has_method("exportar_estado"):
        estado["habilidades"] = hab.call("exportar_estado")
    if vida != null:
        estado["vida"] = float(vida.get("vida_atual"))
        estado["vida_maxima"] = int(vida.get("vida_maxima"))
    if checkpoint != null and checkpoint.has_method("exportar_estado_save"):
        estado["chapeu"] = checkpoint.call("exportar_estado_save")
    if sobrescrever_posicao:
        estado["posicao"] = [ophelia.global_position.x, ophelia.global_position.y]
        estado["posicao_valida"] = true
    estado["catalogo_completo"] = bool(ophelia.get("catalogo_completo"))
    estado["itens_perdidos"] = _capturar_perdidos(ophelia.get_tree())
    _capturar_cenario(ophelia.get_tree())
    partida.dados_jogo = estado
    gravar()

static func _capturar_perdidos(arvore: SceneTree) -> Array:
    var resultado: Array = []
    for no in arvore.get_nodes_in_group("item_perdido_ophelia"):
        if no.has_method("exportar_estado_save") and not no.is_queued_for_deletion():
            resultado.append(no.call("exportar_estado_save"))
    return resultado

static func _capturar_cenario(arvore: SceneTree) -> void:
    if partida == null:
        return
    var dados: Dictionary = partida.dados_jogo.get("cenarios", {})
    var cena := arvore.current_scene
    if cena == null:
        return
    var estado: Dictionary = {}
    for no in arvore.get_nodes_in_group("PersistenteSave"):
        if cena.is_ancestor_of(no) and no.has_method("exportar_estado_save"):
            estado[str(cena.get_path_to(no))] = no.call("exportar_estado_save")
    dados[partida.cena_atual] = estado
    partida.dados_jogo["cenarios"] = dados

static func restaurar_cenario(arvore: SceneTree) -> void:
    if partida == null or arvore.current_scene == null:
        return
    var todos: Dictionary = partida.dados_jogo.get("cenarios", {})
    var dados: Dictionary = todos.get(partida.cena_atual, {})
    for caminho in dados.keys():
        var no := arvore.current_scene.get_node_or_null(NodePath(caminho))
        if no != null and no.has_method("importar_estado_save"):
            no.call("importar_estado_save", dados[caminho])

static func entrar_nivel(destino: String, ophelia: Node2D) -> void:
    if partida == null or not partida.ocupado or destino.is_empty():
        return
    salvar_personagem(ophelia, false)
    partida.cena_atual = destino
    partida.progresso_fase = maxi(partida.progresso_fase, etapa_de_cena(destino))
    partida.mundo_atual = etapa_de_cena(destino)
    partida.dados_jogo["posicao_valida"] = false
    partida.dados_jogo["chapeu"] = {"posto": true, "ativo": false}
    partida.dados_jogo["itens_perdidos"] = []
    carregamento_pendente = true
    gravar()

static func etapa_de_cena(caminho: String) -> int:
    var nome: String = caminho.get_file().get_basename()
    return int(ETAPAS.get(nome, 0))

static func registrar_especie(id: StringName) -> bool:
    if partida == null or not partida.ocupado or String(id).is_empty():
        return false
    var anteriores: Array = partida.dados_jogo.get("especies_catalogadas", [])
    if anteriores.has(String(id)):
        return true
    var pendentes_antigos: Array = partida.dados_jogo.get("animacoes_catalogo_pendentes", [])
    var ids: Array = anteriores.duplicate()
    ids.append(String(id))
    var pendentes: Array = pendentes_antigos.duplicate()
    if not pendentes.has(String(id)):
        pendentes.append(String(id))
    partida.dados_jogo["especies_catalogadas"] = ids
    partida.dados_jogo["animacoes_catalogo_pendentes"] = pendentes
    if gravar():
        return true
    partida.dados_jogo["especies_catalogadas"] = anteriores
    partida.dados_jogo["animacoes_catalogo_pendentes"] = pendentes_antigos
    return false

# Cada slot guarda a ordem dos registros que ainda não foram animados no catálogo.
static func animacoes_catalogo_pendentes() -> Array:
    if partida == null:
        return animacoes_debug.duplicate()
    return partida.dados_jogo.get("animacoes_catalogo_pendentes", []).duplicate()

# Só remove a animação pendente depois que ela realmente terminou na tela.
static func confirmar_animacao_catalogo(id: StringName) -> bool:
    if partida == null:
        animacoes_debug.erase(String(id))
        return true
    var anteriores: Array = partida.dados_jogo.get("animacoes_catalogo_pendentes", [])
    var pendentes: Array = anteriores.duplicate()
    if not pendentes.has(String(id)):
        return true
    pendentes.erase(String(id))
    partida.dados_jogo["animacoes_catalogo_pendentes"] = pendentes
    if gravar():
        return true
    partida.dados_jogo["animacoes_catalogo_pendentes"] = anteriores
    return false

static func especie_registrada(id: StringName) -> bool:
    return especies_debug.has(String(id)) if partida == null else partida.dados_jogo.get("especies_catalogadas", []).has(String(id))

static func concluir_jogo() -> void:
    if partida != null:
        partida.finalizado = true
        partida.progresso_fase = 6
        gravar()

static func encerrar_slot() -> void:
    slot_ativo = -1
    partida = null
    especies_debug.clear()
    animacoes_debug.clear()
    carregamento_pendente = false
