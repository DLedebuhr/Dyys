extends Node
const ACOES: Array[StringName] = [
	&"ControlePular", &"ControleSentarLevantar", &"ControlePropulsor",
	&"ControleCorrer", &"ControleAtaqueLenco", &"ControleDefesaLenco",
	&"ControleFixarLenco", &"ControleImpulsoLenco", &"ControleTrocarAtaque",
]
var habilitada: bool = true
var _pedidos: Array[Dictionary] = []
var _pressionadas: Dictionary = {}
var _soltas: Dictionary = {}

# Preparar o nó
# ---------------------
# Configura referências, sinais e estado inicial.
func _ready() -> void:

	for acao in ACOES + [&"ControleAndarEsquerda", &"ControleAndarDireita", &"ControleMostrarAlcance"]:

		if not InputMap.has_action(acao):

			push_error("OPHELIA: falta a ação '%s' no InputMap. Configure essa ação no Mapa de Entrada do projeto." % acao)

# Receber comandos disponíveis
# ---------------------
# Trata os comandos que a interface ainda não consumiu.
func _unhandled_input(event: InputEvent) -> void:

	if not habilitada:

		return

	if event is InputEventKey and event.echo:

		return

	for acao in ACOES + [&"ControleMostrarAlcance"]:

		if not InputMap.has_action(acao):

			continue

		if event.is_action_pressed(acao):

			_pressionadas[acao] = true

			if acao in ACOES:

				_pedidos.append({"acao": acao, "mouse": get_parent().get_global_mouse_position()})

		elif event.is_action_released(acao):

			_soltas[acao] = true

			if acao == &"ControleFixarLenco":

				_pedidos.append({"acao": &"ControleSoltarGancho", "mouse": Vector2.ZERO})

# Pressionou
# ---------------------
# Processa pressionou.
func pressionou(acao: StringName) -> bool:

	return _pressionadas.has(acao)

# Soltou
# ---------------------
# Processa soltou.
func soltou(acao: StringName) -> bool:

	return _soltas.has(acao)

# Retirar pedidos
# ---------------------
# Retira pedidos.
func retirar_pedidos() -> Array[Dictionary]:

	var resultado: Array[Dictionary] = _pedidos.duplicate()
	_pedidos.clear()
	return resultado

# Limpar quadro
# ---------------------
# Limpa quadro.
func limpar_quadro() -> void:

	_pressionadas.clear()
	_soltas.clear()
