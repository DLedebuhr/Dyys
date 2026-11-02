extends Node
## Substitui o script do nó Vitalidade. atualizar() permanece por compatibilidade.
signal vida_alterada(atual: float, maxima: int)
signal dano_recebido(quantidade: float, origem: Vector2)
signal dano_bloqueado(quantidade: float, origem: Vector2)
signal cura_recebida(quantidade: float, automatica: bool)
signal fruta_consumida(estacao: StringName, quantidade_curada: float)
signal recuperacao_alterada(indice: int, progresso: float)
signal estoque_alterado(estacao: StringName, quantidade: int)
signal morreu()
signal restaurada()
const ESTACOES: Array[StringName] = [&"Primavera", &"Verao", &"Outono", &"Inverno"]
@export_range(1, 6, 1) var vida_maxima: int = 3
@export_range(0.0, 5.0, 0.05) var invulnerabilidade_apos_dano: float = 1.0
@export_group("Recuperação automática")
@export var recuperacao_automatica: bool = true
@export_range(1.0, 600.0, 1.0) var segundos_por_vida: float = 30.0 # Produção: 300.
@export_group("Estoque provisório — sem inventário")
@export var usar_estoque_teste: bool = false
@export_range(0, 99, 1) var frutas_teste_por_estacao: int = 3
@export_enum("Primavera", "Verao", "Outono", "Inverno") var estacao_selecionada: String = "Primavera"
@export var escolher_fruta_disponivel: bool = true
@export var acao_usar_fruta: StringName = &"ControleUsarFruta"
var vida_atual: float = 3.0
var _invulnerabilidade: float = 0.0
var _tempo_recuperacao: float = 0.0
var _estoque: Dictionary = {}
var _consumindo_fruta: bool = false

# Preparar o nó
# ---------------------
# Configura referências, sinais e estado inicial.
func _ready() -> void:

	vida_maxima = clampi(vida_maxima, 1, 6)
	vida_atual = float(vida_maxima)

	for estacao in ESTACOES:

		_estoque[estacao] = frutas_teste_por_estacao if usar_estoque_teste else 0

# Atualizar a cada quadro
# ---------------------
# Atualiza os temporizadores, a interface ou os efeitos deste nó.
func _process(delta: float) -> void:

	_avancar_tempo(delta)

# Atualizar
# ---------------------
# Atualiza a rotina deste componente.
func atualizar(_delta: float) -> void:

	# Ophelia.gd já chama este método. O tempo é contado apenas em _process.
	pass

# Receber comandos disponíveis
# ---------------------
# Trata os comandos que a interface ainda não consumiu.
func _unhandled_input(event: InputEvent) -> void:

	if event is InputEventKey and event.echo:

		return

	if InputMap.has_action(acao_usar_fruta) and event.is_action_pressed(acao_usar_fruta):

		if usar_fruta_disponivel():

			get_viewport().set_input_as_handled()

# Esta viva
# ---------------------
# Verifica esta viva.
func esta_viva() -> bool:

	return vida_atual > 0.0

# Esta invulneravel
# ---------------------
# Verifica esta invulneravel.
func esta_invulneravel() -> bool:

	return _invulnerabilidade > 0.0

# Receber dano
# ---------------------
# Recebe dano.
func receber_dano(quantidade: float, origem: Vector2 = Vector2.ZERO, defendendo: bool = false) -> bool:

	if quantidade <= 0.0 or not esta_viva():

		return false

	if defendendo:

		dano_bloqueado.emit(quantidade, origem)
		return false

	if esta_invulneravel():

		return false

	var anterior: float = vida_atual
	vida_atual = maxf(0.0, vida_atual - quantidade)
	_invulnerabilidade = invulnerabilidade_apos_dano
	_zerar_recuperacao()
	vida_alterada.emit(vida_atual, vida_maxima)
	dano_recebido.emit(anterior - vida_atual, origem)

	if not esta_viva():

		morreu.emit()

	return true

# Curar
# ---------------------
# Recupera a rotina deste componente.
func curar(quantidade: float, automatica: bool = false) -> float:

	if quantidade <= 0.0 or not esta_viva():

		return 0.0

	var recuperado: float = minf(quantidade, float(vida_maxima) - vida_atual)

	if recuperado <= 0.0:

		return 0.0

	vida_atual += recuperado
	_zerar_recuperacao()
	vida_alterada.emit(vida_atual, vida_maxima)
	cura_recebida.emit(recuperado, automatica)
	return recuperado

# Consumir uma fruta do inventário
# ---------------------
# Usa o mesmo estoque exibido na interface, mantendo o atalho em jogo.
func usar_fruta(estacao: StringName) -> bool:

	if not ESTACOES.has(estacao) or not esta_viva():

		return false

	var inventario: Node = get_parent().get_node_or_null("Inventario")

	if inventario == null:

		return false

	var consumiu: bool = bool(inventario.call("usar_fruta_estacao", estacao))

	if consumiu:

		estoque_alterado.emit(estacao, quantidade_frutas(estacao))

	return consumiu

# Aplicar a cura da fruta
# ---------------------
# O inventário controla o consumo; a Vitalidade aplica a cura e seus efeitos.
func aplicar_cura_fruta(estacao: StringName) -> bool:

	if not ESTACOES.has(estacao) or not esta_viva():

		return false

	_consumindo_fruta = true

	var recuperado: float = curar(0.5)

	_consumindo_fruta = false

	if recuperado <= 0.0:

		return false

	fruta_consumida.emit(estacao, recuperado)

	return true

# Consumir uma fruta disponível
# ---------------------
# Prefere a estação selecionada e evita falhar quando só há frutas de outra estação.
func usar_fruta_disponivel() -> bool:

	var selecionada := StringName(estacao_selecionada)

	if quantidade_frutas(selecionada) > 0 or not escolher_fruta_disponivel:

		return usar_fruta(selecionada)

	for estacao in ESTACOES:

		if quantidade_frutas(estacao) > 0:

			return usar_fruta(estacao)

	return false

# Esta consumindo fruta
# ---------------------
# Verifica esta consumindo fruta.
func esta_consumindo_fruta() -> bool:

	# Consultado pelos efeitos durante o sinal vida_alterada da cura.
	return _consumindo_fruta

# Guardar a fruta coletada
# ---------------------
# Adiciona ao inventário real e recusa a coleta se não houver espaço.
func adicionar_fruta(estacao: StringName, quantidade: int = 1) -> bool:

	if not ESTACOES.has(estacao) or quantidade <= 0 or not esta_viva():

		return false

	var inventario: Node = get_parent().get_node_or_null("Inventario")

	if inventario == null:

		return false

	var id: StringName = StringName("Fruta" + String(estacao))
	var adicionou: bool = bool(inventario.call("adicionar", id, quantidade))

	if adicionou:

		estoque_alterado.emit(estacao, quantidade_frutas(estacao))

	return adicionou

# Contar frutas guardadas
# ---------------------
# Consulta a quantidade da estação no inventário real.
func quantidade_frutas(estacao: StringName) -> int:

	var inventario: Node = get_parent().get_node_or_null("Inventario")

	if inventario == null:

		return 0

	var id: StringName = StringName("Fruta" + String(estacao))

	return int(inventario.call("quantidade", id))

# Aumentar vida maxima
# ---------------------
# Aumenta vida maxima.
func aumentar_vida_maxima() -> bool:

	if vida_maxima >= 6 or not esta_viva():

		return false

	vida_maxima += 1
	vida_atual += 1.0 # Preenche apenas o novo espaço; não cura os antigos.
	_zerar_recuperacao()
	vida_alterada.emit(vida_atual, vida_maxima)
	cura_recebida.emit(1.0, false)
	return true

# Restaurar
# ---------------------
# Restaura a rotina deste componente.
func restaurar() -> void:

	vida_atual = float(vida_maxima)
	_invulnerabilidade = invulnerabilidade_apos_dano
	_zerar_recuperacao()
	vida_alterada.emit(vida_atual, vida_maxima)
	restaurada.emit()

# Zerar recuperação
# ---------------------
# Reinicia recuperação.
func _zerar_recuperacao() -> void:

	_tempo_recuperacao = 0.0
	recuperacao_alterada.emit(-1, 0.0)

# Avancar tempo
# ---------------------
# Avança tempo.
func _avancar_tempo(delta: float) -> void:

	_invulnerabilidade = maxf(0.0, _invulnerabilidade - delta)

	if not recuperacao_automatica or not esta_viva() or vida_atual >= float(vida_maxima):

		return
	# Completa primeiro a vida parcial e depois recupera uma inteira por vez.

	var restante_delta: float = maxf(delta, 0.0)

	while restante_delta > 0.0 and vida_atual < float(vida_maxima):

		var quantidade: float = minf(1.0, ceilf(vida_atual + 0.0001) - vida_atual)
		var duracao: float = maxf(segundos_por_vida, 0.01) * quantidade
		var passo: float = minf(restante_delta, maxf(0.0, duracao - _tempo_recuperacao))
		_tempo_recuperacao += passo
		restante_delta -= passo
		recuperacao_alterada.emit(int(floorf(vida_atual)), clampf(_tempo_recuperacao / duracao, 0.0, 1.0))

		if _tempo_recuperacao + 0.00001 < duracao:

			break

		curar(quantidade, true)
