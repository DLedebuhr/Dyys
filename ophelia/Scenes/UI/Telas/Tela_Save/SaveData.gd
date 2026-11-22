class_name SaveData
extends Resource
## Dados individuais do slot, versão 1. Nunca armazena objetos Node/Resource no arquivo JSON.
@export_range(0, 3) var slot_index: int = 0
@export_range(0, 6) var progresso_fase: int = 0
@export var mundo_atual: int = 1
@export var ocupado: bool = false
@export var finalizado: bool = false
@export var cena_atual: String = "res://Scenes/Levels/Tutorial/Tutorial.tscn"
@export var dados_jogo: Dictionary = {}

func existe_save() -> bool:
    return ocupado

func para_dicionario() -> Dictionary:
    return {
        "versao": 1, "slot": slot_index, "ocupado": ocupado,
        "progresso_fase": progresso_fase, "mundo_atual": mundo_atual,
        "finalizado": finalizado, "cena_atual": cena_atual,
        "dados_jogo": dados_jogo.duplicate(true)
    }

static func de_dicionario(indice: int, origem: Dictionary) -> SaveData:
    var d := SaveData.new()
    d.slot_index = clampi(indice, 0, 3)
    if int(origem.get("versao", 0)) != 1 or int(origem.get("slot", -1)) != indice:
        return d
    d.ocupado = bool(origem.get("ocupado", false))
    d.progresso_fase = clampi(int(origem.get("progresso_fase", 0)), 0, 6)
    d.mundo_atual = int(origem.get("mundo_atual", 1))
    d.finalizado = bool(origem.get("finalizado", false))
    d.cena_atual = String(origem.get("cena_atual", d.cena_atual))
    if origem.get("dados_jogo") is Dictionary:
        d.dados_jogo = origem["dados_jogo"].duplicate(true)
    return d
