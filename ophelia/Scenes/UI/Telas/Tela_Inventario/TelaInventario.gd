extends CanvasLayer

signal abrir_catalogo_solicitado()
signal catalogar_solicitado(item: DadosItemOphelia)
const PARTICULAS_REGISTRO = preload("res://Scenes/UI/Telas/Tela_Catalago/ParticulasRegistroFlor.gd")
@export_group("Partículas da catalogação")
@export_range(0.2, 3.0, 0.05) var duracao_desintegrar_capsula: float = 0.95

@export var inventario: InventarioOphelia
@export var acao_inventario: StringName = &"ControleInventario"
@export var acao_fechar: StringName = &"ControlePausar"
@export_group("Consulta rápida de progresso (Tab)")
@export var acao_progresso_rapido: StringName = &"ControleProgressoRapido"
@export_range(0.15, 0.65, 0.01) var intervalo_duplo_tab: float = 0.32

@export_group("Texturas da interface")
@export var fundo: Texture2D
@export var circulo_slot: Texture2D
@export var borda_slot: Texture2D
@export var informacao_vazia: Texture2D
@export var decoracao_oficina: Texture2D
@export_group("Painel de informações")
@export_enum("Texto", "Imagem") var modo_informacao: int = 0
@export var fonte_informacao: Font
@export_group("Imagens de informação por item")
@export var imagens_informacao: Dictionary = {
	&"FrutaPrimavera": null,
	&"FrutaVerao": null,
	&"FrutaOutono": null,
	&"FrutaInverno": null,
	&"Ramo": null,
	&"Capsula": null,
	&"CapsulaSeiva": null,
	&"FlorCalla": null,
	&"EncapsuladaCalla": null,
	&"FlorLavanda": null,
	&"EncapsuladaLavanda": null,
	&"FlorCosmos": null,
	&"EncapsuladaCosmos": null,
	&"FlorLotus": null,
	&"EncapsuladaLotus": null,
	&"FlorLirio": null,
	&"EncapsuladaLirio": null,
	&"FlorViola": null,
	&"EncapsuladaViola": null,
	&"FlorColquico": null,
	&"EncapsuladaColquico": null,
	&"FlorPrincesa": null,
	&"EncapsuladaPrincesa": null,
	&"FlorAzaleia": null,
	&"EncapsuladaAzaleia": null,
	&"FlorDalia": null,
	&"EncapsuladaDalia": null,
	&"FlorHeleboro": null,
	&"EncapsuladaHeleboro": null,
	&"FlorCiclame": null,
	&"EncapsuladaCiclame": null,
	&"FlorCamelia": null,
	&"EncapsuladaCamelia": null,
	&"FlorPrimula": null,
	&"EncapsuladaPrimula": null,
	&"FlorFlocoNeve": null,
	&"EncapsuladaFlocoNeve": null,
	&"FlorTulipa": null,
	&"EncapsuladaTulipa": null,
	&"FlorMuguet": null,
	&"EncapsuladaMuguet": null,
	&"FlorIris": null,
	&"EncapsuladaIris": null,
	&"FlorNarciso": null,
	&"EncapsuladaNarciso": null,
	&"FlorSakura": null,
	&"EncapsuladaSakura": null,
}

@export_group("Áreas independentes")
@export var painel: Control
@export var armazenamento: Control
@export var informacao: TextureRect
@export var oficina: Control
@export var navegacao: Control
@export var fundo_cor: ColorRect
@export var fundo_arte: TextureRect
@export var arte_oficina: TextureRect
@export var montar: BotaoAcaoInventario
@export var encapsular: BotaoAcaoInventario
@export var catalogar: BotaoAcaoInventario
@export var botao_catalogo: BotaoAcaoInventario
@export var botao_mapa: BotaoAcaoInventario
@export_group("Avisos em imagem")
@export var imagem_bolsa_cheia: Texture2D
@export var imagem_catalogo_indisponivel: Texture2D
@export var imagem_mapa_indisponivel: Texture2D
@export var imagem_registro_indisponivel: Texture2D
@export_range(0.5, 10.0, 0.1) var duracao_aviso: float = 2.5
var _escala_painel: Vector2 = Vector2.ONE
var _alpha_painel: float = 1.0
var _imagem_aviso: Texture2D
var _mensagem_aviso: String = ""
@onready var _texto_informacao: Control = $Painel/Informacao/Texto
@onready var _titulo_informacao: Label = $Painel/Informacao/Texto/Titulo
@onready var _subtitulo_informacao: Label = $Painel/Informacao/Texto/Subtitulo
@onready var _descricao_informacao: Label = $Painel/Informacao/Texto/Descricao
var _slots: Array[SlotInventarioOphelia] = []
var _selecionado: SlotInventarioOphelia
var _hover: SlotInventarioOphelia
var _pausa_propria: bool = false
var _transitando: bool = false
const TRANSICAO_TELAS = preload("res://Scenes/UI/Telas/TransicaoCompartilhada.gd")
var _animacao := TRANSICAO_TELAS.new()
var _tempo_aviso: float = 0.0
var _camada_catalogo: CanvasLayer
var _tela_catalogo: Control
var _tempo_reconexao: float = 0.0
var _camada_progresso: CanvasLayer
var _tela_progresso: Control
var _aviso_sem_inventario: bool = false
var _progresso_consulta_rapida: bool = false
var _ultimo_tab_ms: int = -10000
@onready var _fundo_compartilhado: ColorRect = $FundoCompartilhado
var _transicao_fundo: Tween



# Preparar a interface
# ---------------------
# Usa imagens separadas para fundo, informações, círculo e borda, sem botão de usar fruta.
func _ready() -> void:

	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 30
	if painel == null or armazenamento == null or informacao == null or oficina == null or navegacao == null:

		push_warning("TelaInventario: atribua as áreas independentes no Inspetor.")
		set_process_input(false)
		return

	painel.hide()
	_fundo_compartilhado.hide()
	var fundo_antigo := painel.get_node_or_null("FundoCorPadrao") as Control
	if fundo_antigo != null:
		fundo_antigo.hide()

	if fundo != null:

		fundo_arte.texture = fundo

	if decoracao_oficina != null:

		arte_oficina.texture = decoracao_oficina

	if informacao_vazia == null:

		informacao_vazia = informacao.texture

	_escala_painel = painel.scale
	_alpha_painel = painel.modulate.a

	var campos: Array[Label] = [_titulo_informacao, _subtitulo_informacao, _descricao_informacao]
	var tamanhos: Array[int] = [24, 14, 16]

	for i in range(campos.size()):

		var estilo: LabelSettings = LabelSettings.new()
		estilo.font = fonte_informacao
		estilo.font_size = tamanhos[i]
		estilo.font_color = Color.WHITE
		estilo.outline_size = 1
		estilo.outline_color = Color.WHITE
		estilo.line_spacing = 3.0
		estilo.shadow_size = 0
		estilo.shadow_color = Color(0, 0, 0, 0)
		estilo.shadow_offset = Vector2.ONE
		campos[i].label_settings = estilo

	_coletar_slots(armazenamento)
	_coletar_slots(oficina)
	montar.pressed.connect(_fabricar.bind(&"Montar"))
	encapsular.pressed.connect(_fabricar.bind(&"Encapsular"))
	catalogar.pressed.connect(_catalogar)
	botao_catalogo.pressed.connect(_abrir_catalogo)
	botao_mapa.pressed.connect(_abrir_mapa)
	_conectar.call_deferred()

# Encontrar os espaços montados
# ---------------------
# Liga os quatorze slots da bolsa e os três da oficina sem criar slots em tempo de execução.
func _coletar_slots(no: Node) -> void:

	for filho in no.get_children():

		if filho is SlotInventarioOphelia:

			filho.tela = self
			_slots.append(filho)

			if circulo_slot != null:

				filho.texture_normal = circulo_slot
				filho.texture_disabled = circulo_slot

			if borda_slot != null:

				filho.get_node("Borda").texture = borda_slot

		else:

			_coletar_slots(filho)

# Ligar ao inventário real
# ---------------------
# Atualiza a tela por sinais e encontra a bolsa como filha da Ophelia.
func _conectar() -> void:

	if not is_instance_valid(inventario):

		var jogador: Node = get_tree().get_first_node_in_group("jogador")

		if jogador != null:

			inventario = jogador.get_node_or_null("Inventario") as InventarioOphelia

	if not is_instance_valid(inventario):
		if not _aviso_sem_inventario:
			push_warning("TelaInventario: aguardando o nó Inventario da Ophelia para ativar a interface.")
			_aviso_sem_inventario = true
		return
	_aviso_sem_inventario = false
	if not inventario.alterado.is_connected(_atualizar):
		inventario.alterado.connect(_atualizar)
	if not inventario.coleta_recusada.is_connected(_ao_recusar_coleta):
		inventario.coleta_recusada.connect(_ao_recusar_coleta)
	_atualizar()

# Centralizar a animação
# ---------------------
# Centraliza uma única transformação no painel, sem animar as seções separadamente.
func _centralizar() -> void:

	painel.pivot_offset = painel.size * 0.5

# Consultar a transição
# ---------------------
# Evita iniciar arrastes enquanto a tela está aparecendo ou desaparecendo.
func em_transicao() -> bool:

	return _transitando

# Tratar abertura e fechamento
# ---------------------
# Usa apenas ações do Mapa de Entrada; I alterna a tela e Esc fecha.
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return
	if painel.visible and not _transitando and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_desselecionar_fora_dos_slots()

	# Consulta instantânea (segurar Tab) ou abertura persistente (duplo Tab).
	if InputMap.has_action(acao_progresso_rapido):
		if event.is_action_released(acao_progresso_rapido):
			if _progresso_consulta_rapida:
				_encerrar_progresso_rapido()
				get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed(acao_progresso_rapido):
			_tratar_tab_progresso()
			get_viewport().set_input_as_handled()
			return
	var tecla_i: bool = InputMap.has_action(acao_inventario) and event.is_action_pressed(acao_inventario)
	var tecla_c: bool = InputMap.has_action(&"ControleCatalago") and event.is_action_pressed(&"ControleCatalago")
	var tecla_p: bool = InputMap.has_action(&"ControleProgresso") and event.is_action_pressed(&"ControleProgresso")
	var tecla_esc: bool = event.is_action_pressed(acao_fechar)
	if not (tecla_i or tecla_c or tecla_p or tecla_esc):
		return

	# Quando o menu interno estiver aberto, ele tem prioridade.
	var menu: Node = get_tree().get_first_node_in_group("menu_interno_ophelia")
	if menu != null and bool(menu.get("aberto")):
		return

	if _transitando:
		get_viewport().set_input_as_handled()
		return
	if _tela_visivel(_tela_catalogo):
		get_viewport().set_input_as_handled()
		if tecla_c or tecla_esc:
			_fechar_pagina_atual()
		elif tecla_p:
			_abrir_progresso()
		elif tecla_i:
			_voltar_ao_inventario()
		return
	if _tela_visivel(_tela_progresso):
		get_viewport().set_input_as_handled()
		if tecla_p or tecla_esc:
			_fechar_pagina_atual()
		elif tecla_c:
			_abrir_catalogo()
		elif tecla_i:
			_voltar_ao_inventario()
		return
	if painel.visible:
		get_viewport().set_input_as_handled()
		if tecla_i or tecla_esc:
			_fechar()
		elif tecla_c:
			_abrir_catalogo()
		elif tecla_p:
			_abrir_progresso()
		return
	# Esc com nenhuma tela aberta fica reservado ao menu interno.
	if tecla_esc:
		return
	if not is_instance_valid(inventario) or get_tree().paused:
		return
	var vida: Node = inventario.get_parent().get_node_or_null("Vitalidade")
	if vida != null and bool(vida.call("esta_viva")):
		get_viewport().set_input_as_handled()
		if tecla_i:
			_abrir()
		elif tecla_c:
			_abrir_pagina_diretamente(&"catalogo")
		elif tecla_p:
			_abrir_pagina_diretamente(&"progresso")

# Mostra a tela existente sem pausar o jogo. O segundo toque fixa a tela.
func _tratar_tab_progresso() -> void:
	# Tab também fecha qualquer uma das três telas abertas permanentemente.
	if _pausa_propria and (painel.visible or _tela_visivel(_tela_catalogo) or _tela_visivel(_tela_progresso)):
		_ultimo_tab_ms = -10000
		if painel.visible:
			if not _transitando:
				_fechar()
		else:
			_fechar_pagina_atual()
		return
	var agora: int = Time.get_ticks_msec()
	var duplo: bool = agora - _ultimo_tab_ms <= int(intervalo_duplo_tab * 1000.0)
	_ultimo_tab_ms = -10000 if duplo else agora
	if _transitando or get_tree().paused or painel.visible or _tela_visivel(_tela_catalogo):
		return
	if duplo:
		if _progresso_consulta_rapida and _tela_visivel(_tela_progresso):
			# A consulta já está visível: fixa a tela sem reiniciar a animação.
			_progresso_consulta_rapida = false
			_pausa_propria = true
			get_tree().paused = true
			_limpar_comandos()
		else:
			_abrir_pagina_diretamente(&"progresso")
		return
	if _tela_visivel(_tela_progresso) and _progresso_consulta_rapida:
		return
	if not _preparar_progresso():
		return
	_progresso_consulta_rapida = true
	var primeira_abertura: bool = not _fundo_compartilhado.visible
	_abrir_fundo_compartilhado()
	# Mesmo efeito usado na abertura definitiva, com uma vantagem mínima ao fundo.
	_tela_progresso.call("abrir", 0.06 if primeira_abertura else 0.0)

func _encerrar_progresso_rapido() -> void:
	if not _progresso_consulta_rapida:
		return
	_progresso_consulta_rapida = false
	if is_instance_valid(_tela_progresso):
		_tela_progresso.call("fechar", false)
	_fechar_fundo_compartilhado()

# Um único fundo durante toda a navegação entre I/C/P.
# Assim, apenas os elementos das telas repetem suas animações.
func _abrir_fundo_compartilhado() -> void:
	if _transicao_fundo != null and _transicao_fundo.is_valid():
		_transicao_fundo.kill()
	if not _fundo_compartilhado.visible:
		_fundo_compartilhado.modulate.a = 0.0
		_fundo_compartilhado.show()
		_transicao_fundo = create_tween()
		_transicao_fundo.tween_property(_fundo_compartilhado, "modulate:a", 1.0, TRANSICAO_TELAS.DURACAO_ENTRADA).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	elif _fundo_compartilhado.modulate.a < 1.0:
		_transicao_fundo = create_tween()
		_transicao_fundo.tween_property(_fundo_compartilhado, "modulate:a", 1.0, TRANSICAO_TELAS.DURACAO_ENTRADA).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _fechar_fundo_compartilhado() -> void:
	if _transicao_fundo != null and _transicao_fundo.is_valid():
		_transicao_fundo.kill()
	if not _fundo_compartilhado.visible:
		return
	_transicao_fundo = create_tween()
	_transicao_fundo.tween_property(_fundo_compartilhado, "modulate:a", 0.0, TRANSICAO_TELAS.DURACAO_SAIDA).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_transicao_fundo.finished.connect(_fundo_compartilhado.hide)

func _tela_visivel(tela: Control) -> bool:
	return is_instance_valid(tela) and tela.visible

func _abrir_pagina_diretamente(pagina: StringName) -> void:
	_abrir_fundo_compartilhado()
	_pausa_propria = true
	get_tree().paused = true
	_limpar_comandos()
	if pagina == &"catalogo":
		if not _preparar_catalogo():
			_pausa_propria = false
			get_tree().paused = false
			return
		_tela_catalogo.call("abrir", 0.06)
	else:
		if not _preparar_progresso():
			_pausa_propria = false
			get_tree().paused = false
			return
		_tela_progresso.call("abrir", 0.06)

func _fechar_pagina_atual() -> void:
	_fechar_fundo_compartilhado()
	if _tela_visivel(_tela_catalogo):
		_tela_catalogo.call("fechar", false)
	if _tela_visivel(_tela_progresso):
		_tela_progresso.call("fechar", false)
	if _pausa_propria:
		_pausa_propria = false
		get_tree().paused = false
	_limpar_comandos()

func _voltar_ao_inventario() -> void:
	_trocar_pagina(&"inventario")

# Uma única sequência para todas as setas: sair, depois entrar.
# O fundo de cor é o mesmo e nunca reinicia durante essas trocas.
func _trocar_pagina(destino: StringName) -> void:
	if _transitando:
		return
	if destino == &"inventario" and painel.visible:
		return
	if destino == &"catalogo" and _tela_visivel(_tela_catalogo):
		return
	if destino == &"progresso" and _tela_visivel(_tela_progresso):
		return
	if destino == &"catalogo" and not _preparar_catalogo():
		return
	if destino == &"progresso" and not _preparar_progresso():
		return
	_transitando = true
	_abrir_fundo_compartilhado()
	var ao_sair: Callable = Callable(self, "_concluir_troca_pagina").bind(destino)
	if painel.visible:
		_animacao.fechar(painel, ao_sair)
	elif _tela_visivel(_tela_catalogo):
		_tela_catalogo.call("fechar", false, ao_sair)
	elif _tela_visivel(_tela_progresso):
		_tela_progresso.call("fechar", false, ao_sair)
	else:
		_concluir_troca_pagina(destino)

func _concluir_troca_pagina(destino: StringName) -> void:
	_transitando = false
	match destino:
		&"inventario":
			_abrir()
		&"catalogo":
			_tela_catalogo.call("abrir", 0.0)
			abrir_catalogo_solicitado.emit()
		&"progresso":
			_tela_progresso.call("abrir", 0.0)



# Aparecer suavemente
# ---------------------
# Anima o Painel inteiro de uma só vez, incluindo fundo, enfeites e todas as áreas.
func _abrir() -> void:
	var primeira_abertura: bool = not _fundo_compartilhado.visible
	_abrir_fundo_compartilhado()
	_transitando = true
	if not _pausa_propria:
		_pausa_propria = true
		get_tree().paused = true
	_limpar_comandos()
	_centralizar()
	_atualizar()
	_animacao.abrir(painel, false, _fim_entrada, 0.06 if primeira_abertura else 0.0)

# Liberar a interface após a entrada
# ---------------------
# Finaliza o bloqueio temporário dos arrastes.
func _fim_entrada() -> void:

	_transitando = false

# Desaparecer suavemente
# ---------------------
# Mantém o jogo pausado até terminar a saída; materiais da oficina continuam guardados nos seus slots.
func _fechar() -> void:
	_fechar_fundo_compartilhado()
	_transitando = true
	_hover = null
	_animacao.fechar(painel, _fim_saida)

# Devolver o controle ao jogo
# ---------------------
# Restaura a pausa somente quando a própria tela a iniciou.
func _fim_saida() -> void:

	painel.hide()
	_transitando = false

	if _pausa_propria:

		get_tree().paused = false
		_pausa_propria = false

	_limpar_comandos()

# Limpar comandos acumulados
# ---------------------
# Evita acionar o lenço ao sair da tela depois de clicar nos espaços.
func _limpar_comandos() -> void:

	if is_instance_valid(inventario) and inventario.get_parent().has_method("limpar_comandos"):

		inventario.get_parent().call("limpar_comandos")

# Consultar o conteúdo mostrado
# ---------------------
# A saída mostra a prévia da receita, mas só permite retirar o resultado depois da fabricação.
func dados_slot(slot: SlotInventarioOphelia) -> Dictionary:

	var dados: Dictionary = inventario.consultar(StringName(slot.local), slot.indice)

	if slot.local == "resultado" and int(dados.get("quantidade", 0)) == 0:

		var receita_atual: Dictionary = inventario.receita()

		if not receita_atual.is_empty():

			return {"id": receita_atual["id"], "quantidade": 0, "previa": true}

	return dados

# Atualizar os estados visuais
# ---------------------
# Mostra as quantidades, bordas, entradas bloqueadas e os quatro estados dos botões.
func _atualizar() -> void:
	if not is_instance_valid(inventario) or inventario.catalogo == null:
		return
	for slot in _slots:

		var dados: Dictionary = dados_slot(slot)
		var item: DadosItemOphelia = inventario.catalogo.obter(dados.get("id", &""))
		var bloqueado: bool = slot.local == "oficina" and inventario.entrada_bloqueada(slot.indice)
		slot.apresentar(dados, item, slot == _selecionado, bloqueado)

	var atual: Dictionary = inventario.receita()
	montar.definir_disponivel(atual.get("acao", &"") == &"Montar")
	encapsular.definir_disponivel(atual.get("acao", &"") == &"Encapsular")
	var flor_pronta: DadosItemOphelia = inventario.flor_para_catalogar()
	# Catalogar continua clicável mesmo sem flor: assim explica o motivo em vez de ignorar o clique.
	# Com flor em Resultado ou Oficina, o mesmo botão registra a espécie no slot ativo.
	catalogar.definir_disponivel(true)
	if flor_pronta == null:
		catalogar.tooltip_text = ""
	elif EstadoPartida.partida == null:
		catalogar.tooltip_text = ""
	elif inventario.especie_ja_registrada(flor_pronta.especie):
		catalogar.tooltip_text = ""
	else:
		catalogar.tooltip_text = ""
	_mostrar_informacao(_hover if is_instance_valid(_hover) else _selecionado)

# Selecionar um espaço
# ---------------------
# Mantém a imagem de informação e a borda do objeto escolhido.
func selecionar(slot: SlotInventarioOphelia) -> void:

	if not _transitando:

		_selecionado = slot
		_atualizar()

# Inspecionar temporariamente
# ---------------------
# Troca apenas a imagem informativa ao passar o mouse por um item.
func inspecionar(slot: SlotInventarioOphelia) -> void:

	if is_instance_valid(inventario) and not _transitando:

		_hover = slot
		_mostrar_informacao(slot)

# Encerrar a inspeção temporária
# ---------------------
# Retorna à imagem referente ao item selecionado.
func sair_inspecao(slot: SlotInventarioOphelia) -> void:

	if _hover == slot:

		_hover = null
		_mostrar_informacao(_selecionado)

# Trocar a imagem de informação
# ---------------------
# Seleciona texto ou imagem sem apagar as artes cadastradas e conserva os avisos em imagem.
func _mostrar_informacao(slot: SlotInventarioOphelia) -> void:

	if _tempo_aviso > 0.0:
		if _imagem_aviso != null:
			_texto_informacao.hide()
			informacao.texture = _imagem_aviso
		elif not _mensagem_aviso.is_empty():
			informacao.texture = null
			_texto_informacao.show()
			_titulo_informacao.text = "CATÁLOGO"
			_subtitulo_informacao.text = ""
			_descricao_informacao.text = _mensagem_aviso
		return

	var item: DadosItemOphelia = null

	if is_instance_valid(slot) and is_instance_valid(inventario):

		item = inventario.catalogo.obter(dados_slot(slot).get("id", &""))

	if item == null:

		_exibir_texto(null)
		return

	var imagem: Texture2D = imagens_informacao.get(item.id)

	if imagem == null:

		imagem = item.imagem_informacao

	if modo_informacao == 1 and imagem != null:

		_texto_informacao.hide()
		informacao.texture = imagem

	else:

		_exibir_texto(item)

# Preencher as informações do item
# ---------------------
# Mostra título, subtítulo e descrição ou a ajuda padrão.
func _exibir_texto(item: DadosItemOphelia) -> void:

	informacao.texture = null
	_texto_informacao.show()
	_subtitulo_informacao.show()

	if item == null:

		_titulo_informacao.text = "Painel de Ajuda"
		_subtitulo_informacao.text = "/ᐠ｡ꞈ｡ᐟ\\"
		_descricao_informacao.text = "Selecione o item para descobrir seu significado"
		return

	_titulo_informacao.text = item.nome
	_descricao_informacao.text = item.descricao

	match item.id:

		&"FrutaVerao":
			_subtitulo_informacao.text = "Sol • Energia • Vitalidade"

		&"FrutaOutono":
			_subtitulo_informacao.text = "Colheita • Aconchego • Nutrição"

		&"FrutaInverno":
			_subtitulo_informacao.text = "Resistência • Alento • Vigor"

		&"FrutaPrimavera":
			_subtitulo_informacao.text = "Frescor • Renovação • Leveza"

		&"Ramo":
			_subtitulo_informacao.text = "Natureza • Recurso • Possibilidade"

		&"Capsula":
			_subtitulo_informacao.text = "Abrigo • Cuidado • Potencial"

		&"CapsulaSeiva":
			_subtitulo_informacao.text = "Essência • Proteção • Preservação"

		_:
			_subtitulo_informacao.text = item.subtitulo

# Executar uma receita disponível
# ---------------------
# Revalida os materiais no inventário, sem permitir clicar durante uma transição.
func _fabricar(acao: StringName) -> void:

	if not _transitando:

		inventario.fabricar(acao)

# Pedir o registro de uma flor
# ---------------------
# Registra a espécie no save e só então consome a flor encapsulada.
func _catalogar() -> void:
	if _transitando or not is_instance_valid(inventario):
		return
	var item: DadosItemOphelia = inventario.flor_para_catalogar()
	if item == null:
		mostrar_aviso(imagem_registro_indisponivel, "Coloque uma flor encapsulada em Resultado ou na Oficina.")
		return
	if EstadoPartida.partida == null and not inventario._catalogacao_debug_sem_save():
		mostrar_aviso(imagem_registro_indisponivel, "Selecione um slot de save ou ative o debug para catalogar.")
		return
	if inventario.especie_ja_registrada(item.especie):
		mostrar_aviso(imagem_registro_indisponivel, "Esta espécie já foi registrada neste save.")
		return
	var origem_efeito: Vector2 = catalogar.get_global_rect().get_center()
	var tamanho_efeito: Vector2 = Vector2(90, 90)
	for slot in _slots:
		var dados: Dictionary = inventario.consultar(StringName(slot.local), slot.indice)
		if StringName(dados.get("id", &"")) == item.id and int(dados.get("quantidade", 0)) > 0:
			origem_efeito = slot.get_global_rect().get_center()
			tamanho_efeito = slot.size * 0.85
			break
	if inventario.catalogar_flor_preservada():
		_animar_capsula_catalogada(item.icone, origem_efeito, tamanho_efeito)
		catalogar_solicitado.emit(item)
		_atualizar()
		mostrar_aviso(null, "Espécie registrada apenas nesta sessão de debug." if EstadoPartida.partida == null else "Espécie registrada! Abra o catálogo para ver a descoberta.")
	else:
		push_warning("Catalogar: falha ao registrar %s no slot de save." % String(item.especie))
		mostrar_aviso(imagem_registro_indisponivel, "Não foi possível gravar o registro. Verifique a saída do Godot.")

# Pedir a tela de catálogo
# ---------------------
# Abre o catálogo sobre o inventário e preserva a pausa e a fase atual.
func _abrir_catalogo() -> void:
	_trocar_pagina(&"catalogo")

func _abrir_progresso() -> void:
	_trocar_pagina(&"progresso")


# Pedir a tela do mapa
# ---------------------
# Mantém o botão pronto para ligar ao mapa quando ele for criado.
func _abrir_mapa() -> void:
	# O antigo botão Mapa é a seta da direita e agora abre Progresso.
	_abrir_progresso()

# Avisar sobre a bolsa cheia
# ---------------------
# Converte a recusa do inventário na arte configurada, sem mostrar texto na tela.
func _ao_recusar_coleta(_mensagem: String) -> void:

	mostrar_aviso(imagem_bolsa_cheia)

# Mostrar uma imagem de aviso
# ---------------------
# Usa a própria área de informações; sem textura atribuída, não cria um aviso textual.
func mostrar_aviso(textura: Texture2D, mensagem: String = "") -> void:

	if textura == null and mensagem.is_empty():
		return
	_imagem_aviso = textura
	_mensagem_aviso = mensagem
	_tempo_aviso = duracao_aviso
	_mostrar_informacao(_hover if is_instance_valid(_hover) else _selecionado)

# Restaurar a informação do item
# ---------------------
# Conta o aviso apenas com o inventário visível e restaura a seleção quando ele termina.
func _process(delta: float) -> void:
	# Em algumas cenas o HUB é carregado antes da Ophelia: reconectar quando ela aparecer.
	if not is_instance_valid(inventario):
		_tempo_reconexao -= delta
		if _tempo_reconexao <= 0.0:
			_tempo_reconexao = 0.5
			_conectar()

	if painel == null or not painel.visible or _transitando or _tempo_aviso <= 0.0:

		return

	_tempo_aviso -= delta

	if _tempo_aviso <= 0.0:

		_imagem_aviso = null
		_mensagem_aviso = ""
		_mostrar_informacao(_hover if is_instance_valid(_hover) else _selecionado)

# Abrir o catálogo sobre a partida pausada sem trocar de cena ou destruir o inventário.
func _preparar_catalogo() -> bool:
	if is_instance_valid(_tela_catalogo):
		return true
	var caminho: String = "res://Scenes/UI/Telas/Tela_Catalago/TelaCatalago.tscn"
	var cena: PackedScene = load(caminho) as PackedScene
	if cena == null:
		return false
	_camada_catalogo = CanvasLayer.new()
	_camada_catalogo.name = "CamadaCatalogo"
	_camada_catalogo.layer = 40
	_camada_catalogo.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_camada_catalogo)
	_tela_catalogo = cena.instantiate() as Control
	if _tela_catalogo == null:
		_camada_catalogo.queue_free()
		return false
	_camada_catalogo.add_child(_tela_catalogo)
	var fundo_catalogo := _tela_catalogo.get_node_or_null("FundoCorPadrao") as Control
	if fundo_catalogo != null:
		fundo_catalogo.hide()
	_tela_catalogo.connect("voltar_inventario_solicitado", _voltar_ao_inventario)
	_tela_catalogo.connect("progresso_solicitado", _abrir_progresso)
	return true

func _preparar_progresso() -> bool:
	if is_instance_valid(_tela_progresso):
		return true
	var caminho: String = "res://Scenes/UI/Telas/Tela_Progresso/TelaProgresso.tscn"
	var cena: PackedScene = load(caminho) as PackedScene
	if cena == null:
		return false
	_camada_progresso = CanvasLayer.new()
	_camada_progresso.name = "CamadaProgresso"
	_camada_progresso.layer = 41
	_camada_progresso.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_camada_progresso)
	_tela_progresso = cena.instantiate() as Control
	if _tela_progresso == null:
		_camada_progresso.queue_free()
		return false
	_camada_progresso.add_child(_tela_progresso)
	var fundo_progresso := _tela_progresso.get_node_or_null("FundoCorPadrao") as Control
	if fundo_progresso != null:
		fundo_progresso.hide()
	_tela_progresso.connect("inventario_solicitado", _voltar_ao_inventario)
	_tela_progresso.connect("catalogo_solicitado", _abrir_catalogo)
	return true


# Restaurar a pausa ao remover a tela
# ---------------------
# Libera o cenário se a interface sair da árvore durante uma transição.
func _exit_tree() -> void:

	if _pausa_propria:

		get_tree().paused = false


# Desselecionar ao clicar fora
# ---------------------
# Limpa a seleção quando o clique não está sobre nenhum slot.
func _desselecionar_fora_dos_slots() -> void:

	for slot in _slots:

		if slot.is_visible_in_tree() and slot.get_global_rect().has_point(slot.get_global_mouse_position()):

			return

	_selecionado = null
	_hover = null
	_atualizar()


func _animar_capsula_catalogada(textura: Texture2D, centro: Vector2, tamanho: Vector2) -> void:
	if textura == null:
		return
	# Camada própria: o efeito continua mesmo com a partida pausada.
	var camada := CanvasLayer.new()
	camada.name = "ParticulasCapsulaCatalogada"
	camada.layer = 55
	camada.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(camada)
	var efeito: Control = PARTICULAS_REGISTRO.new()
	camada.add_child(efeito)
	efeito.set_anchors_preset(Control.PRESET_FULL_RECT)
	efeito.iniciar(textura, centro, tamanho, false, duracao_desintegrar_capsula)
	efeito.terminou.connect(camada.queue_free, CONNECT_ONE_SHOT)
