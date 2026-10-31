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
@export var usar_estoque_teste: bool = true
@export_range(0, 99, 1) var frutas_teste_por_estacao: int = 3
@export_enum("Primavera", "Verao", "Outono", "Inverno") var estacao_selecionada: String = "Primavera"
@export var acao_usar_fruta: StringName = &"ControleUsarFruta"

var vida_atual: float = 3.0
var _invulnerabilidade: float = 0.0
var _tempo_recuperacao: float = 0.0
var _estoque: Dictionary = {}
var _consumindo_fruta: bool = false

func _ready() -> void:
	vida_maxima = clampi(vida_maxima, 1, 6)
	vida_atual = float(vida_maxima)
	for estacao in ESTACOES:
		_estoque[estacao] = frutas_teste_por_estacao if usar_estoque_teste else 0

func _process(delta: float) -> void:
	_avancar_tempo(delta)

func atualizar(_delta: float) -> void:
	# Ophelia.gd já chama este método. O tempo é contado apenas em _process.
	pass

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return
	if InputMap.has_action(acao_usar_fruta) and event.is_action_pressed(acao_usar_fruta):
		if usar_fruta(StringName(estacao_selecionada)):
			get_viewport().set_input_as_handled()

func esta_viva() -> bool:
	return vida_atual > 0.0

func esta_invulneravel() -> bool:
	return _invulnerabilidade > 0.0

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

func usar_fruta(estacao: StringName) -> bool:
	# Trocar apenas este estoque pela futura transação do inventário.
	if not usar_estoque_teste or not ESTACOES.has(estacao) or quantidade_frutas(estacao) <= 0:
		return false
	if not esta_viva() or vida_atual >= float(vida_maxima):
		return false
	_estoque[estacao] = quantidade_frutas(estacao) - 1
	_consumindo_fruta = true
	var recuperado: float = curar(0.5)
	_consumindo_fruta = false
	if recuperado <= 0.0:
		_estoque[estacao] = quantidade_frutas(estacao) + 1
		return false
	fruta_consumida.emit(estacao, recuperado)
	estoque_alterado.emit(estacao, quantidade_frutas(estacao))
	return true

func esta_consumindo_fruta() -> bool:
	# Consultado pelos efeitos durante o sinal vida_alterada da cura.
	return _consumindo_fruta

func quantidade_frutas(estacao: StringName) -> int:
	return int(_estoque.get(estacao, 0))

func aumentar_vida_maxima() -> bool:
	if vida_maxima >= 6 or not esta_viva():
		return false
	vida_maxima += 1
	vida_atual += 1.0 # Preenche apenas o novo espaço; não cura os antigos.
	_zerar_recuperacao()
	vida_alterada.emit(vida_atual, vida_maxima)
	cura_recebida.emit(1.0, false)
	return true

func restaurar() -> void:
	vida_atual = float(vida_maxima)
	_invulnerabilidade = invulnerabilidade_apos_dano
	_zerar_recuperacao()
	vida_alterada.emit(vida_atual, vida_maxima)
	restaurada.emit()

func _zerar_recuperacao() -> void:
	_tempo_recuperacao = 0.0
	recuperacao_alterada.emit(-1, 0.0)

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
