class_name SlotInventarioOphelia
extends TextureButton

@export_enum("bolsa", "oficina", "resultado") var local: String = "bolsa"
@export var indice: int = 0
var tela: CanvasLayer
var _hover: bool = false
var _selecionado: bool = false

# Preparar o espaço
# ---------------------
# Separa o círculo permanente, o ícone do objeto e a borda de seleção.
func _ready() -> void:

	mouse_entered.connect(_entrar)
	mouse_exited.connect(_sair)
	pressed.connect(_selecionar)
	focus_entered.connect(_selecionar)

# Atualizar o conteúdo
# ---------------------
# Mantém o círculo vazio visível e só exibe ícone e quantidade quando houver objeto.
func apresentar(dados: Dictionary, item: DadosItemOphelia, selecionado: bool, bloqueado: bool) -> void:

	_selecionado = selecionado
	disabled = bloqueado
	self_modulate = Color(1, 1, 1, 0.35) if bloqueado else Color.WHITE
	$Icone.texture = item.icone if item != null else null
	# Oculta somente o círculo quando há um item.
	self_modulate.a = 0.0 if item != null else (0.35 if bloqueado else 1.0)
	$Icone.modulate.a = 0.45 if bool(dados.get("previa", false)) else 1.0
	$Quantidade.text = str(dados.get("quantidade", 0)) if item != null and item.pode_empilhar() and int(dados.get("quantidade", 0)) > 0 else ""
	tooltip_text = item.nome if item != null else ""
	_atualizar_borda()

# Mostrar o destaque
# ---------------------
# A borda é uma imagem independente e não substitui o círculo nem o item.
func _atualizar_borda() -> void:

	$Borda.visible = not disabled and (_hover or _selecionado)

# Inspecionar ao passar o mouse
# ---------------------
# Mostra a imagem informativa sem mudar a seleção permanente.
func _entrar() -> void:

	_hover = true
	_atualizar_borda()

	if is_instance_valid(tela) and not disabled:

		tela.inspecionar(self)

# Encerrar a inspeção temporária
# ---------------------
# Restaura a imagem do item selecionado ao retirar o mouse.
func _sair() -> void:

	_hover = false
	_atualizar_borda()

	if is_instance_valid(tela):

		tela.sair_inspecao(self)

# Selecionar o objeto
# ---------------------
# Mantém a seleção mesmo depois que o mouse sai do espaço.
func _selecionar() -> void:

	if is_instance_valid(tela):

		tela.selecionar(self)

# Iniciar o arraste
# ---------------------
# A prévia acompanha o mouse, mas o estoque só muda quando o destino aceita o item.
func _get_drag_data(_posicao: Vector2) -> Variant:

	if disabled or not is_instance_valid(tela) or tela.em_transicao():

		return null

	var dados: Dictionary = tela.inventario.consultar(StringName(local), indice)

	if int(dados.get("quantidade", 0)) <= 0:

		return null

	var previa := TextureRect.new()
	previa.texture = $Icone.texture
	previa.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	previa.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	previa.custom_minimum_size = Vector2(72, 72)
	previa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_drag_preview(previa)
	return {"bolsa": tela.inventario.get_instance_id(), "local": StringName(local), "indice": indice, "id": dados["id"]}

# Validar o destino
# ---------------------
# Protege o resultado e impede misturar arrastes de outra instância do inventário.
func _can_drop_data(_posicao: Vector2, dados: Variant) -> bool:

	if disabled or not is_instance_valid(tela) or tela.em_transicao() or not dados is Dictionary:

		return false

	if dados.get("bolsa", 0) != tela.inventario.get_instance_id():

		return false

	var atual: Dictionary = tela.inventario.consultar(dados.get("local", &""), int(dados.get("indice", -1)))

	if atual.get("id", &"") != dados.get("id", &""):

		return false

	return tela.inventario.pode_mover(dados["local"], dados["indice"], StringName(local), indice)

# Concluir o arraste
# ---------------------
# Move, empilha ou troca os conteúdos sem descartar nada se o destino for inválido.
func _drop_data(posicao: Vector2, dados: Variant) -> void:

	if _can_drop_data(posicao, dados):

		tela.inventario.mover(dados["local"], dados["indice"], StringName(local), indice)
		tela.selecionar(self)


# Formatar o nome ao passar o mouse
# ---------------------
# Usa a fonte do inventário e o padrão de texto branco, com tamanho 22.
func _make_custom_tooltip(for_text: String) -> Object:

	var nome_item: Label = Label.new()
	var estilo: LabelSettings = LabelSettings.new()
	estilo.font = preload("res://Assets/Fonts/tt-milks-casual-pie-line.ttf")

	if is_instance_valid(tela) and tela.fonte_informacao != null:

		estilo.font = tela.fonte_informacao

	estilo.font_size = 22
	estilo.font_color = Color.WHITE
	estilo.outline_size = 1
	estilo.outline_color = Color.WHITE
	estilo.line_spacing = 3.0
	estilo.shadow_size = 0
	estilo.shadow_color = Color(0, 0, 0, 0)
	estilo.shadow_offset = Vector2.ONE
	nome_item.label_settings = estilo
	nome_item.text = for_text
	return nome_item
