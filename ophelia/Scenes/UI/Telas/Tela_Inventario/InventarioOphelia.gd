extends Node

signal alterado()
signal coleta_recusada(mensagem: String)
signal catalogacao_solicitada(item: DadosItemOphelia)

@export_range(1, 100, 1) var capacidade: int = 14
@export var catalogo: CatalogoItensOphelia = preload("CatalogoItens.tres")
@export_dir var pasta_icones: String = "res://Assetes/Texture/Flowers/Inventairo"
@export_group("Teste opcional")
@export var adicionar_itens_teste: bool = false

var _espacos: Array[Dictionary] = []
var _em_transacao: bool = false
var _oficina: Array[Dictionary] = [{"id": &"", "quantidade": 0}, {"id": &"", "quantidade": 0}]
var _resultado: Dictionary = {"id": &"", "quantidade": 0}

# Preparar os espaços
# ---------------------
# Começa vazio; o conteúdo de teste só é adicionado quando solicitado no Inspetor.
func _ready() -> void:

	catalogo.carregar_icones(pasta_icones)

	for i in range(capacidade):

		_espacos.append({"id": &"", "quantidade": 0})

	if adicionar_itens_teste:

		for id in [&"FrutaPrimavera", &"FrutaVerao", &"FrutaOutono", &"FrutaInverno"]:

			adicionar(id, 3)

		adicionar(&"Ramo", 4)
		adicionar(&"Capsula", 1)
		adicionar(&"CapsulaSeiva", 1)
		adicionar(&"FlorCalla", 2)
		adicionar(&"EncapsuladaCalla", 1)

# Consultar um espaço
# ---------------------
# Devolve uma cópia para que a interface não altere o estoque diretamente.
func obter_espaco(indice: int) -> Dictionary:

	return _espacos[indice].duplicate() if indice >= 0 and indice < _espacos.size() else {}

# Contar um item
# ---------------------
# Soma as unidades em todas as pilhas com o mesmo identificador.
func quantidade(id: StringName) -> int:

	var total: int = 0

	for espaco in _espacos:

		if espaco["id"] == id:

			total += int(espaco["quantidade"])

	return total

# Verificar espaço antes da coleta
# ---------------------
# Considera vagas e espaço restante nas pilhas existentes, sem modificar o inventário.
func pode_adicionar(id: StringName, unidades: int = 1) -> bool:

	if _em_transacao or catalogo == null or unidades <= 0:

		return false

	var item: DadosItemOphelia = catalogo.obter(id)

	if item == null:

		return false

	var restantes: int = unidades
	var limite: int = item.capacidade_pilha()

	for espaco in _espacos:

		if espaco["id"] == id or int(espaco["quantidade"]) == 0:

			restantes -= mini(restantes, limite - int(espaco["quantidade"]))

			if restantes <= 0:

				return true

	return false

# Adicionar uma coleta completa
# ---------------------
# Recusa a operação inteira se não couber, mantendo o objeto disponível no cenário.
func adicionar(id: StringName, unidades: int = 1) -> bool:

	if _em_transacao or unidades <= 0 or catalogo == null or catalogo.obter(id) == null:

		return false

	if not pode_adicionar(id, unidades):

		coleta_recusada.emit("BOLSA CHEIA")
		return false

	var restantes: int = unidades
	var limite: int = catalogo.obter(id).capacidade_pilha()

	# Completa pilhas antes de ocupar novos espaços.
	for preencher_vazios in [false, true]:

		for espaco in _espacos:

			var vazio: bool = int(espaco["quantidade"]) == 0

			if vazio != preencher_vazios or (not vazio and espaco["id"] != id):

				continue

			var inserir: int = mini(restantes, limite - int(espaco["quantidade"]))
			espaco["id"] = id
			espaco["quantidade"] += inserir
			restantes -= inserir

			if restantes == 0:

				alterado.emit()
				return true

	return false

# Remover unidades de um item
# ---------------------
# Não remove parcialmente quando a quantidade pedida não está disponível.
func remover(id: StringName, unidades: int = 1) -> bool:

	if _em_transacao or unidades <= 0 or quantidade(id) < unidades:

		return false

	var restantes: int = unidades

	for espaco in _espacos:

		if espaco["id"] != id:

			continue

		var retirar: int = mini(restantes, int(espaco["quantidade"]))
		espaco["quantidade"] -= retirar
		restantes -= retirar

		if int(espaco["quantidade"]) == 0:

			espaco["id"] = &""

		if restantes == 0:

			alterado.emit()
			return true

	return false

# Remover de um espaço específico
# ---------------------
# Mantém o controle da pilha selecionada para ações futuras da oficina.
func remover_do_espaco(indice: int, unidades: int = 1) -> bool:

	if _em_transacao or indice < 0 or indice >= _espacos.size() or unidades <= 0 or int(_espacos[indice]["quantidade"]) < unidades:

		return false

	_espacos[indice]["quantidade"] -= unidades

	if int(_espacos[indice]["quantidade"]) == 0:

		_espacos[indice]["id"] = &""

	alterado.emit()
	return true

# Usar a fruta selecionada
# ---------------------
# Consome uma unidade somente quando há cura; a barra e as partículas usam os sinais existentes.
func usar(indice: int) -> bool:

	if _em_transacao or indice < 0 or indice >= _espacos.size():

		return false

	var espaco: Dictionary = _espacos[indice]
	var item: DadosItemOphelia = catalogo.obter(espaco["id"])
	var vida: Node = get_parent().get_node_or_null("Vitalidade")

	if item == null or item.tipo != DadosItemOphelia.Tipo.FRUTA or vida == null or not bool(vida.call("esta_viva")) or float(vida.get("vida_atual")) >= float(vida.get("vida_maxima")):

		return false

	_em_transacao = true
	espaco["quantidade"] -= 1
	var curou: bool = bool(vida.call("aplicar_cura_fruta", item.estacao))

	if not curou:

		espaco["quantidade"] += 1

	elif int(espaco["quantidade"]) == 0:

		espaco["id"] = &""

	_em_transacao = false

	if curou:

		alterado.emit()

	return curou

# Usar uma fruta da estação
# ---------------------
# Preserva o atalho de cura já existente, agora consumindo o inventário real.
func usar_fruta_estacao(estacao: StringName) -> bool:

	for i in range(_espacos.size()):

		if _espacos[i]["id"] == StringName("Fruta" + String(estacao)):

			return usar(i)

	return false

# Consultar qualquer slot da interface
# ---------------------
# Compartilha uma identificação entre bolsa, entradas da oficina e resultado protegido.
func consultar(local: StringName, indice: int = 0) -> Dictionary:

	var espaco: Dictionary = _referencia(local, indice)
	return espaco.duplicate() if not espaco.is_empty() else {}

# Encontrar um espaço interno
# ---------------------
# Impede índices inválidos sem expor referências mutáveis para a interface.
func _referencia(local: StringName, indice: int) -> Dictionary:

	if local == &"bolsa" and indice >= 0 and indice < _espacos.size():

		return _espacos[indice]

	if local == &"oficina" and indice >= 0 and indice < 2:

		return _oficina[indice]

	if local == &"resultado":

		return _resultado

	return {}

# Verificar a entrada bloqueada
# ---------------------
# Uma flor encapsulada deixa disponível apenas o slot que já a contém.
func entrada_bloqueada(indice: int) -> bool:

	var outro: DadosItemOphelia = catalogo.obter(_oficina[1 - indice]["id"])
	return outro != null and outro.tipo == DadosItemOphelia.Tipo.FLOR_ENCAPSULADA

# Validar um conteúdo na oficina
# ---------------------
# Não aceita frutas e impede misturar uma flor preservada com outro material.
func _aceita_entrada(indice: int, id: StringName) -> bool:

	if id == &"":

		return true

	if entrada_bloqueada(indice):

		return false

	var item: DadosItemOphelia = catalogo.obter(id)

	if item == null or item.tipo == DadosItemOphelia.Tipo.FRUTA:

		return false

	return item.tipo != DadosItemOphelia.Tipo.FLOR_ENCAPSULADA or int(_oficina[1 - indice]["quantidade"]) == 0

# Conferir uma transferência
# ---------------------
# O resultado pode sair para a bolsa, mas nunca recebe itens; trocas são verificadas nos dois sentidos.
func pode_mover(origem: StringName, de: int, destino: StringName, para: int) -> bool:

	if _em_transacao or destino == &"resultado" or (origem == destino and de == para):

		return false

	var a: Dictionary = _referencia(origem, de)
	var b: Dictionary = _referencia(destino, para)

	if a.is_empty() or b.is_empty() or int(a["quantidade"]) == 0:

		return false

	if origem == &"resultado" and destino != &"bolsa":

		return false

	if destino == &"oficina" and not _aceita_entrada(para, a["id"]):

		return false

	if origem == &"oficina" and b["id"] != a["id"] and not _aceita_entrada(de, b["id"]):

		return false

	if origem == &"resultado" and b["id"] != &"" and b["id"] != a["id"]:

		return false

	if a["id"] == b["id"]:

		return int(b["quantidade"]) < catalogo.obter(a["id"]).capacidade_pilha()

	return true

# Mover, empilhar ou trocar objetos
# ---------------------
# Arrasta a pilha inteira; se a pilha de destino tiver limite, conserva a sobra na origem.
func mover(origem: StringName, de: int, destino: StringName, para: int) -> bool:

	if not pode_mover(origem, de, destino, para):

		return false

	var a: Dictionary = _referencia(origem, de)
	var b: Dictionary = _referencia(destino, para)

	if a["id"] == b["id"]:

		var limite: int = catalogo.obter(a["id"]).capacidade_pilha()
		var transferir: int = mini(int(a["quantidade"]), limite - int(b["quantidade"]))
		b["quantidade"] += transferir
		a["quantidade"] -= transferir

		if int(a["quantidade"]) == 0:

			a["id"] = &""

	else:

		var anterior: Dictionary = b.duplicate()
		b["id"] = a["id"]
		b["quantidade"] = a["quantidade"]
		a["id"] = anterior["id"]
		a["quantidade"] = anterior["quantidade"]

	alterado.emit()
	return true

# Reconhecer a receita
# ---------------------
# Permite dois ramos na mesma entrada ou um em cada entrada e mantém a espécie ao encapsular.
func receita() -> Dictionary:

	if int(_resultado["quantidade"]) > 0:

		return {}

	var a: DadosItemOphelia = catalogo.obter(_oficina[0]["id"])
	var b: DadosItemOphelia = catalogo.obter(_oficina[1]["id"])
	var total_ramos: int = 0
	var apenas_ramos: bool = true

	for espaco in _oficina:

		if int(espaco["quantidade"]) > 0:

			apenas_ramos = apenas_ramos and espaco["id"] == &"Ramo"

			if espaco["id"] == &"Ramo":

				total_ramos += int(espaco["quantidade"])

	if apenas_ramos and total_ramos >= 2:

		return {"acao": &"Montar", "id": &"Capsula"}

	if a != null and b != null:

		var flor: DadosItemOphelia = a if a.tipo == DadosItemOphelia.Tipo.FLOR else b
		var capsula: DadosItemOphelia = b if flor == a else a

		if flor.tipo == DadosItemOphelia.Tipo.FLOR and capsula.tipo == DadosItemOphelia.Tipo.CAPSULA_SEIVA:

			var id: StringName = StringName("Encapsulada" + String(flor.especie))

			if catalogo.obter(id) != null:

				return {"acao": &"Encapsular", "id": id}

	return {}

# Consumir uma entrada
# ---------------------
# Remove apenas a quantidade exigida e conserva o restante da pilha na oficina.
func _consumir_entrada(indice: int, unidades: int) -> void:

	_oficina[indice]["quantidade"] -= unidades

	if int(_oficina[indice]["quantidade"]) == 0:

		_oficina[indice]["id"] = &""

# Fabricar o resultado
# ---------------------
# Revalida a receita antes de consumir materiais e mantém a saída protegida até ser retirada.
func fabricar(acao: StringName) -> bool:

	if _em_transacao:

		return false

	var atual: Dictionary = receita()

	if atual.is_empty() or atual["acao"] != acao:

		return false

	if acao == &"Montar":

		var faltam: int = 2

		for i in range(2):

			var consumir: int = mini(faltam, int(_oficina[i]["quantidade"]))
			_consumir_entrada(i, consumir)
			faltam -= consumir

	else:

		_consumir_entrada(0, 1)
		_consumir_entrada(1, 1)

	_resultado = {"id": atual["id"], "quantidade": 1}
	alterado.emit()
	return true

# Consultar a flor pronta para catalogar
# ---------------------
# Exige uma única entrada ocupada por flor preservada e nenhuma saída pendente.
func flor_para_catalogar() -> DadosItemOphelia:

	if int(_resultado["quantidade"]) > 0:

		return null

	for i in range(2):

		var item: DadosItemOphelia = catalogo.obter(_oficina[i]["id"])

		if item != null and item.tipo == DadosItemOphelia.Tipo.FLOR_ENCAPSULADA and int(_oficina[1 - i]["quantidade"]) == 0:

			return item

	return null

# Solicitar o registro futuro
# ---------------------
# Disponibiliza o botão sem consumir a flor antes de existir um catálogo que confirme o registro.
func solicitar_catalogacao() -> bool:

	var item: DadosItemOphelia = flor_para_catalogar()

	if item == null:

		return false

	catalogacao_solicitada.emit(item)
	return true
