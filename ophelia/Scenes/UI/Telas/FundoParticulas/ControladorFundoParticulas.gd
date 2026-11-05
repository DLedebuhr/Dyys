extends Node


@export_file("*.tscn") var caminho_fundo: String

var _fundo: CanvasLayer = null


# Ativar o fundo
# ---------------------
# Mantém a mesma instância durante a navegação dos menus.
func ativar() -> void:

	if is_instance_valid(_fundo):

		return

	if caminho_fundo.is_empty():

		push_warning("FundoParticulas: configure Caminho Fundo no Inspetor.")
		return

	var cena: PackedScene = load(caminho_fundo) as PackedScene

	if cena == null:

		push_warning("FundoParticulas: não foi possível carregar a cena.")
		return

	var instancia: Node = cena.instantiate()

	if not instancia is CanvasLayer:

		instancia.free()
		push_warning("FundoParticulas: a raiz visual deve ser CanvasLayer.")
		return

	_fundo = instancia as CanvasLayer
	add_child(_fundo)


# Desativar o fundo
# ---------------------
# Libera o fundo ao entrar na partida.
func desativar() -> void:

	if not is_instance_valid(_fundo):

		_fundo = null
		return

	_fundo.hide()
	_fundo.queue_free()
	_fundo = null
