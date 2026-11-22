class_name InventarioOphelia
extends Node

signal alterado()
signal coleta_recusada(mensagem: String)
signal catalogacao_solicitada(item: DadosItemOphelia)
signal flor_murchou(id: StringName, unidades: int)

@export_range(1, 100, 1) var capacidade: int = 14
@export_group("Validade das flores")
@export_range(1.0, 3600.0, 1.0) var validade_flores_segundos: float = 10.0 # Teste: 10 s; produção: 600 s.
@export var catalogo: CatalogoItensOphelia = preload("CatalogoItens.tres")
@export_dir var pasta_icones: String = "res://Assets/Textures/UI/Tela_Inventario/Flores"
@export_group("Teste opcional")
@export var adicionar_itens_teste: bool = false

var _espacos: Array[Dictionary] = []
var _tempo_flores: float = 0.0
var _prazos_flores: Dictionary = {} # id da espécie -> prazos individuais, mesmo após mover para a oficina.
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

# Trocar uma cápsula vazia por outra com seiva sem perder espaço ou itens.
# A operação usa o mesmo slot, inclusive se a cápsula estiver na oficina.
func possui_capsula_vazia() -> bool:
	for espaco in _espacos + _oficina + [_resultado]:
		if espaco.get("id", &"") == &"Capsula" and int(espaco.get("quantidade", 0)) > 0:
			return true
	return false

func encher_capsula_com_seiva() -> bool:
	if _em_transacao or catalogo == null:
		return false
	if catalogo.obter(&"Capsula") == null or catalogo.obter(&"CapsulaSeiva") == null:
		return false
	for espaco in _espacos + _oficina + [_resultado]:
		if espaco.get("id", &"") != &"Capsula" or int(espaco.get("quantidade", 0)) != 1:
			continue
		_em_transacao = true
		espaco["id"] = &"CapsulaSeiva"
		_em_transacao = false
		alterado.emit()
		return true
	return false

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

				_registrar_flores(id, unidades)
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

			_consumir_validade_flor(id, unidades)
			alterado.emit()
			return true

	return false

# Remover de um espaço específico
# ---------------------
# Mantém o controle da pilha selecionada para ações futuras da oficina.
func remover_do_espaco(indice: int, unidades: int = 1) -> bool:

	if _em_transacao or indice < 0 or indice >= _espacos.size() or unidades <= 0 or int(_espacos[indice]["quantidade"]) < unidades:

		return false

	var id_removido: StringName = _espacos[indice]["id"]
	_espacos[indice]["quantidade"] -= unidades
	_consumir_validade_flor(id_removido, unidades)

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

	_consumir_validade_flor(_oficina[indice]["id"], unidades)
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

# Flor encapsulada pronta para o catálogo: Resultado sempre tem prioridade.
# Não confunde a prévia da receita (quantidade 0) com um item fabricado.
func flor_para_catalogar() -> DadosItemOphelia:
	if catalogo == null:
		return null
	if int(_resultado.get("quantidade", 0)) > 0:
		var produto: DadosItemOphelia = catalogo.obter(StringName(_resultado.get("id", &"")))
		if produto != null and produto.tipo == DadosItemOphelia.Tipo.FLOR_ENCAPSULADA:
			return produto
	for entrada in _oficina:
		if int(entrada.get("quantidade", 0)) <= 0:
			continue
		var flor: DadosItemOphelia = catalogo.obter(StringName(entrada.get("id", &"")))
		if flor != null and flor.tipo == DadosItemOphelia.Tipo.FLOR_ENCAPSULADA:
			return flor
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


# Prazos individuais das flores comuns (as encapsuladas não apodrecem).
func _registrar_flores(id: StringName, unidades: int) -> void:
	var item: DadosItemOphelia = catalogo.obter(id)
	if item == null or item.tipo != DadosItemOphelia.Tipo.FLOR:
		return
	var prazos: Array = _prazos_flores.get(id, [])
	for i in range(unidades):
		prazos.append(_tempo_flores + validade_flores_segundos)
	_prazos_flores[id] = prazos

# Consumir as flores mais antigas da mesma espécie, inclusive em receitas.
func _consumir_validade_flor(id: StringName, unidades: int) -> void:
	if not _prazos_flores.has(id):
		return
	var prazos: Array = _prazos_flores[id]
	for i in range(mini(unidades, prazos.size())):
		prazos.pop_front()
	if prazos.is_empty():
		_prazos_flores.erase(id)

func _process(delta: float) -> void:
	_tempo_flores += delta
	if _em_transacao:
		return
	var mudou: bool = false
	for id in _prazos_flores.keys():
		var prazos: Array = _prazos_flores[id]
		var vencidas: int = 0
		while not prazos.is_empty() and float(prazos[0]) <= _tempo_flores:
			prazos.pop_front()
			vencidas += 1
		if vencidas > 0:
			var restantes: int = vencidas
			for espaco in _espacos + _oficina:
				if espaco["id"] != id:
					continue
				var retirar: int = mini(restantes, int(espaco["quantidade"]))
				espaco["quantidade"] -= retirar
				restantes -= retirar
				if int(espaco["quantidade"]) == 0:
					espaco["id"] = &""
				if restantes == 0:
					break
			flor_murchou.emit(id, vencidas)
			mudou = true
		if prazos.is_empty():
			_prazos_flores.erase(id)
	if mudou:
		alterado.emit()

# Na morte: flores comuns e cápsulas vazias desaparecem; ramos/frutas caem;
# flores encapsuladas e cápsulas cheias de seiva ficam protegidas na bolsa.
func retirar_na_morte() -> Array[Dictionary]:
	var perdidos: Array[Dictionary] = []
	_em_transacao = false
	for espaco in _espacos + _oficina + [_resultado]:
		var id: StringName = espaco["id"]
		var unidades: int = int(espaco["quantidade"])
		if unidades <= 0:
			continue
		var item: DadosItemOphelia = catalogo.obter(id) if catalogo != null else null
		if item == null:
			continue
		match item.tipo:
			DadosItemOphelia.Tipo.FLOR, DadosItemOphelia.Tipo.CAPSULA:
				espaco["id"] = &""
				espaco["quantidade"] = 0
			DadosItemOphelia.Tipo.FRUTA, DadosItemOphelia.Tipo.RAMO:
				perdidos.append({"id": String(id), "quantidade": unidades})
				espaco["id"] = &""
				espaco["quantidade"] = 0
			DadosItemOphelia.Tipo.CAPSULA_SEIVA, DadosItemOphelia.Tipo.FLOR_ENCAPSULADA:
				pass # Esses itens permanecem protegidos.
	_prazos_flores.clear()
	alterado.emit()
	return perdidos

# Quantidade de flores ainda não encapsuladas em bolsa e oficina.
func contar_flores_comuns() -> int:
	var total: int = 0
	for espaco in _espacos + _oficina:
		if int(espaco["quantidade"]) <= 0 or catalogo == null:
			continue
		var item: DadosItemOphelia = catalogo.obter(espaco["id"])
		if item != null and item.tipo == DadosItemOphelia.Tipo.FLOR:
			total += int(espaco["quantidade"])
	return total


# Persistência exata dos espaços, da oficina e das flores que ainda estão vivas.
func exportar_estado_save() -> Dictionary:
	var lista_bolsa: Array = []
	for e in _espacos:
		lista_bolsa.append({"id": String(e["id"]), "quantidade": int(e["quantidade"])})
	var lista_oficina: Array = []
	for e in _oficina:
		lista_oficina.append({"id": String(e["id"]), "quantidade": int(e["quantidade"])})
	var prazos: Dictionary = {}
	for id in _prazos_flores.keys():
		var restantes: Array = []
		for instante in _prazos_flores[id]:
			restantes.append(maxf(0.0, float(instante) - _tempo_flores))
		prazos[String(id)] = restantes
	return {"bolsa": lista_bolsa, "oficina": lista_oficina,
			"resultado": {"id": String(_resultado["id"]), "quantidade": int(_resultado["quantidade"])},
			"prazos_flores": prazos}

func importar_estado_save(dados: Dictionary) -> void:
	_em_transacao = true
	for e in _espacos + _oficina + [_resultado]:
		e["id"] = &""
		e["quantidade"] = 0
	var bolsa: Array = dados.get("bolsa", [])
	for i in range(mini(_espacos.size(), bolsa.size())):
		_restaurar_espaco(_espacos[i], bolsa[i])
	var oficina: Array = dados.get("oficina", [])
	for i in range(mini(_oficina.size(), oficina.size())):
		_restaurar_espaco(_oficina[i], oficina[i])
	_restaurar_espaco(_resultado, dados.get("resultado", {}))
	_tempo_flores = 0.0
	_prazos_flores.clear()
	var prazos: Dictionary = dados.get("prazos_flores", {})
	for id_texto in prazos.keys():
		var id: StringName = StringName(id_texto)
		var item := catalogo.obter(id)
		if item == null or item.tipo != DadosItemOphelia.Tipo.FLOR:
			continue
		var valores: Array = []
		for restante in prazos[id_texto]:
			valores.append(maxf(0.0, float(restante)))
		valores.sort()
		_prazos_flores[id] = valores
	_em_transacao = false
	alterado.emit()

func _restaurar_espaco(destino: Dictionary, origem: Variant) -> void:
	if not (origem is Dictionary):
		return
	var id: StringName = StringName(origem.get("id", ""))
	var item := catalogo.obter(id) if catalogo != null else null
	if item == null:
		return
	destino["id"] = id
	destino["quantidade"] = clampi(int(origem.get("quantidade", 0)), 0, item.capacidade_pilha())
	if destino["quantidade"] == 0:
		destino["id"] = &""


# Arrastar até a caixa de descarte elimina a pilha inteira do slot de origem.
# Os dados são validados novamente para evitar descartar um item que já foi movido.
func descartar(local: StringName, indice: int, id_esperado: StringName) -> bool:
	if _em_transacao:
		return false
	var origem: Dictionary = _referencia(local, indice)
	if origem.is_empty() or int(origem.get("quantidade", 0)) <= 0 or origem.get("id", &"") != id_esperado:
		return false
	var unidades: int = int(origem["quantidade"])
	_consumir_validade_flor(id_esperado, unidades)
	origem["id"] = &""
	origem["quantidade"] = 0
	alterado.emit()
	return true


func _catalogacao_debug_sem_save() -> bool:
	if EstadoPartida.partida != null:
		return false
	var jogador: Node = get_parent()
	return jogador != null and jogador.has_method("em_modo_debug") and jogador.em_modo_debug()

# Chamar quando a futura tela de catálogo CONFIRMAR a espécie, não ao apertar o botão.
func confirmar_registro_especie(especie: StringName) -> void:
	EstadoPartida.registrar_especie(especie)

func especie_ja_registrada(especie: StringName) -> bool:
	if _catalogacao_debug_sem_save():
		return EstadoPartida.especie_registrada(especie)
	return EstadoPartida.especie_registrada(especie)

# Registrar uma flor encapsulada depositada na oficina.
# A espécie é salva antes de consumir a flor; um erro no disco não perde o item.
func catalogar_flor_preservada() -> bool:
	if _em_transacao or catalogo == null:
		return false
	var debug_sem_save: bool = _catalogacao_debug_sem_save()
	if EstadoPartida.partida == null and not debug_sem_save:
		push_warning("Catalogar: é necessário um save ou o modo debug para testar.")
		return false
	var item: DadosItemOphelia = flor_para_catalogar()
	if item == null or String(item.especie).is_empty() or especie_ja_registrada(item.especie):
		return false

	# A saída da oficina conta mesmo antes de arrastar a cápsula para outro slot.
	var origem: Dictionary = {}
	if _resultado["id"] == item.id and int(_resultado["quantidade"]) > 0:
		origem = _resultado
	else:
		for i in range(_oficina.size()):
			if _oficina[i]["id"] == item.id and int(_oficina[i]["quantidade"]) > 0:
				origem = _oficina[i]
				break
	if origem.is_empty():
		return false

	# Registrar no slot primeiro: se gravar falhar, a cápsula não será consumida.
	if debug_sem_save:
		if not EstadoPartida.registrar_especie_debug(item.especie):
			return false
	elif not EstadoPartida.registrar_especie(item.especie):
		return false
	_em_transacao = true
	origem["quantidade"] = int(origem["quantidade"]) - 1
	if int(origem["quantidade"]) == 0:
		origem["id"] = &""
	_em_transacao = false
	_atualizar_catalogo_completo()
	alterado.emit()
	var personagem := get_parent() as Node2D
	if personagem != null and not debug_sem_save:
		EstadoPartida.salvar_personagem(personagem)
	return true

func _atualizar_catalogo_completo() -> void:
	if EstadoPartida.partida == null or catalogo == null:
		return
	var especies: Dictionary = {}
	for item in catalogo.itens:
		if item != null and item.tipo == DadosItemOphelia.Tipo.FLOR_ENCAPSULADA and not String(item.especie).is_empty():
			especies[item.especie] = true
	var completo: bool = not especies.is_empty()
	for especie in especies:
		if not EstadoPartida.especie_registrada(especie):
			completo = false
			break
	EstadoPartida.partida.dados_jogo["catalogo_completo"] = completo
	var personagem := get_parent()
	if personagem != null and personagem.has_method("definir_catalogo_completo"):
		personagem.call("definir_catalogo_completo", completo)
