extends CanvasLayer

signal abrir_catalogo_solicitado()
signal abrir_mapa_solicitado()
signal catalogar_solicitado(item: DadosItemOphelia)

@export var inventario: Node
@export var acao_inventario: StringName = &"ControleInventario"
@export var acao_fechar: StringName = &"ui_cancel"
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
@export var imagens_informacao: Dictionary[StringName, Texture2D] = {
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
@export_group("Aparecer e desaparecer")
@export_range(0.1, 2.0, 0.05) var duracao_entrada: float = 0.45
@export_range(0.1, 2.0, 0.05) var duracao_saida: float = 0.25
@export_range(0.5, 1.0, 0.01) var escala_inicial: float = 0.92

@export_group("Áreas independentes")
@export var painel: Control
@export var armazenamento: Control
@export var informacao: TextureRect
@export var oficina: Control
@export var navegacao: Control
@export var fundo_cor: ColorRect
@export var fundo_arte: TextureRect
@export var arte_oficina: TextureRect
@export var montar: TextureButton
@export var encapsular: TextureButton
@export var catalogar: TextureButton
@export var botao_catalogo: TextureButton
@export var botao_mapa: TextureButton
@export_group("Avisos em imagem")
@export var imagem_bolsa_cheia: Texture2D
@export var imagem_catalogo_indisponivel: Texture2D
@export var imagem_mapa_indisponivel: Texture2D
@export var imagem_registro_indisponivel: Texture2D
@export_range(0.5, 10.0, 0.1) var duracao_aviso: float = 2.5
var _escala_painel: Vector2 = Vector2.ONE
var _alpha_painel: float = 1.0
var _imagem_aviso: Texture2D
@onready var _texto_informacao: Control = $Painel/Informacao/Texto
@onready var _titulo_informacao: Label = $Painel/Informacao/Texto/Titulo
@onready var _subtitulo_informacao: Label = $Painel/Informacao/Texto/Subtitulo
@onready var _descricao_informacao: Label = $Painel/Informacao/Texto/Descricao
var _slots: Array[SlotInventarioOphelia] = []
var _selecionado: SlotInventarioOphelia
var _hover: SlotInventarioOphelia
var _pausa_propria: bool = false
var _transitando: bool = false
var _transicao: Tween
var _tempo_aviso: float = 0.0

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

			inventario = jogador.get_node_or_null("Inventario")

	if not is_instance_valid(inventario):

		push_warning("TelaInventario: adicione o nó Inventario à Ophelia.")
		return

	inventario.alterado.connect(_atualizar)
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

	if painel.visible and not _transitando and event is InputEventMouseButton:

		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:

			_desselecionar_fora_dos_slots()
			
	if event is InputEventKey and event.echo:

		return

	var alternar: bool = InputMap.has_action(acao_inventario) and event.is_action_pressed(acao_inventario)
	var fechar: bool = painel.visible and InputMap.has_action(acao_fechar) and event.is_action_pressed(acao_fechar)

	if not alternar and not fechar:

		return

	get_viewport().set_input_as_handled()

	if _transitando:

		return

	if painel.visible:

		_fechar()

	elif is_instance_valid(inventario) and not get_tree().paused:

		var vida: Node = inventario.get_parent().get_node_or_null("Vitalidade")

		if vida != null and bool(vida.call("esta_viva")):

			_abrir()

# Aparecer suavemente
# ---------------------
# Anima o Painel inteiro de uma só vez, incluindo fundo, enfeites e todas as áreas.
func _abrir() -> void:

	_transitando = true
	_pausa_propria = true
	get_tree().paused = true
	_limpar_comandos()
	painel.show()
	_centralizar()
	_atualizar()
	painel.modulate.a = 0.0
	painel.scale = _escala_painel * escala_inicial
	_transicao = create_tween().set_parallel(true)
	_transicao.tween_property(painel, "modulate:a", _alpha_painel, duracao_entrada).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_transicao.tween_property(painel, "scale", _escala_painel, duracao_entrada).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_transicao.finished.connect(_fim_entrada)

# Liberar a interface após a entrada
# ---------------------
# Finaliza o bloqueio temporário dos arrastes.
func _fim_entrada() -> void:

	_transitando = false

# Desaparecer suavemente
# ---------------------
# Mantém o jogo pausado até terminar a saída; materiais da oficina continuam guardados nos seus slots.
func _fechar() -> void:

	_transitando = true
	_hover = null
	_transicao = create_tween().set_parallel(true)
	_transicao.tween_property(painel, "modulate:a", 0.0, duracao_saida).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_transicao.tween_property(painel, "scale", _escala_painel * escala_inicial, duracao_saida).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_transicao.finished.connect(_fim_saida)

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

	for slot in _slots:

		var dados: Dictionary = dados_slot(slot)
		var item: DadosItemOphelia = inventario.catalogo.obter(dados.get("id", &""))
		var bloqueado: bool = slot.local == "oficina" and inventario.entrada_bloqueada(slot.indice)
		slot.apresentar(dados, item, slot == _selecionado, bloqueado)

	var atual: Dictionary = inventario.receita()
	montar.definir_disponivel(atual.get("acao", &"") == &"Montar")
	encapsular.definir_disponivel(atual.get("acao", &"") == &"Encapsular")
	catalogar.definir_disponivel(inventario.flor_para_catalogar() != null)
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

	if _imagem_aviso != null and _tempo_aviso > 0.0:

		_texto_informacao.hide()
		informacao.texture = _imagem_aviso
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
# Não consome a flor enquanto a futura tela de catálogo não confirmar o registro.
func _catalogar() -> void:

	if _transitando:

		return

	var item: DadosItemOphelia = inventario.flor_para_catalogar()

	if item != null and inventario.solicitar_catalogacao():

		catalogar_solicitado.emit(item)

		if not catalogar_solicitado.has_connections():

			mostrar_aviso(imagem_registro_indisponivel)

# Pedir a tela de catálogo
# ---------------------
# Prepara a navegação sem trocar para uma cena que ainda não existe.
func _abrir_catalogo() -> void:

	if not _transitando:

		abrir_catalogo_solicitado.emit()

		if not abrir_catalogo_solicitado.has_connections():

			mostrar_aviso(imagem_catalogo_indisponivel)

# Pedir a tela do mapa
# ---------------------
# Mantém o botão pronto para ligar ao mapa quando ele for criado.
func _abrir_mapa() -> void:

	if not _transitando:

		abrir_mapa_solicitado.emit()

		if not abrir_mapa_solicitado.has_connections():

			mostrar_aviso(imagem_mapa_indisponivel)

# Avisar sobre a bolsa cheia
# ---------------------
# Converte a recusa do inventário na arte configurada, sem mostrar texto na tela.
func _ao_recusar_coleta(_mensagem: String) -> void:

	mostrar_aviso(imagem_bolsa_cheia)

# Mostrar uma imagem de aviso
# ---------------------
# Usa a própria área de informações; sem textura atribuída, não cria um aviso textual.
func mostrar_aviso(textura: Texture2D) -> void:

	if textura == null:

		return

	_imagem_aviso = textura
	_tempo_aviso = duracao_aviso
	_texto_informacao.hide()
	informacao.texture = textura

# Restaurar a informação do item
# ---------------------
# Conta o aviso apenas com o inventário visível e restaura a seleção quando ele termina.
func _process(delta: float) -> void:

	if painel == null or not painel.visible or _transitando or _tempo_aviso <= 0.0:

		return

	_tempo_aviso -= delta

	if _tempo_aviso <= 0.0:

		_imagem_aviso = null
		_mostrar_informacao(_hover if is_instance_valid(_hover) else _selecionado)

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
