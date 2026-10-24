class_name Habilidades
extends Node
# Nó "Habilidades" (filho do Player). Responde só uma pergunta: QUEM PODE usar cada habilidade.
# O que a personagem está FAZENDO agora (planando, sentada, com o lenço preso...) continua no
# Player: veja Player.esta_em_uso(id). Assim "desbloqueada" e "em uso" nunca se misturam.
#
# Duas camadas de permissão:
#   - REAL: o que ela aprendeu de verdade (é o que o save vai gravar).
#   - TEMPORÁRIA: o modo debug libera tudo, mas nunca mexe no que é real.

signal habilidade_desbloqueada(id: StringName)   # Aprendeu uma habilidade (de verdade)
signal modo_debug_alterado(ativo: bool)          # Modo debug ligou/desligou
signal estado_carregado()                        # Os desbloqueios reais foram substituídos (carregar save / esquecer)

# --- IDENTIFICADORES (use sempre estes, nunca texto solto) ---
const ANDAR_ESQUERDA: StringName = &"AndarEsquerda"
const ANDAR_DIREITA: StringName = &"AndarDireita"
const PULAR: StringName = &"Pular"
const SENTAR_LEVANTAR: StringName = &"SentarLevantar"
const CORRER: StringName = &"Correr"
const FIXAR_LENCO: StringName = &"FixarLenco"
const IMPULSO_LENCO: StringName = &"ImpulsoLenco"

const ATAQUE_LENCO: StringName = &"AtaqueLenco"
const DEFESA_LENCO: StringName = &"DefesaLenco"
const PLANAR: StringName = &"Planar"
const AGARRAR_OBJETO: StringName = &"AgarrarObjeto"

# Disponíveis desde o começo (nunca ficam bloqueadas)
const INICIAIS := [
	ANDAR_ESQUERDA, ANDAR_DIREITA, PULAR, SENTAR_LEVANTAR,
	CORRER, FIXAR_LENCO, IMPULSO_LENCO,
]
# Só passam a valer depois de aprendidas em um interativo (a ordem aqui é a ordem do save)
const APRENDIDAS := [ATAQUE_LENCO, DEFESA_LENCO, PLANAR, AGARRAR_OBJETO]

@export var imprimir_eventos: bool = true   # Escreve na Saída cada desbloqueio e troca do modo debug
@export var sequencia_debug: Array[int] = [6, 6, 6]   # Dígitos que ligam/desligam o modo debug
@export var tempo_entre_digitos: float = 1.5          # Segundos máximos entre um dígito e o próximo
@export var somente_em_build_debug: bool = false  # true: o 666 só funciona no editor e em builds de debug (opcional; depois entra uma senha mais difícil)

var _aprendidas: Dictionary = {}   # Desbloqueios REAIS: id -> true
var _debug: bool = false           # Liberação TEMPORÁRIA (nunca é gravada)
var _avisados: Dictionary = {}     # Para avisar de nome errado uma vez só
var _seq_pos: int = 0              # Quantos dígitos da sequência do debug já foram digitados
var _seq_ultimo_ms: int = 0        # Instante do último dígito

# --- CONSULTAS ---

# A habilidade pode ser usada AGORA? (é o que o Player e o lenço perguntam)
func pode_usar(id: StringName) -> bool:
	if not _conhecida(id):
		_avisar_desconhecida(id)
		return false
	return _debug or esta_desbloqueada(id)

# Aprendida de verdade? (ignora o modo debug; é o que vai para o save)
func esta_desbloqueada(id: StringName) -> bool:
	return INICIAIS.has(id) or _aprendidas.has(id)

func esta_em_modo_debug() -> bool:
	return _debug

# --- PONTO DE INTEGRAÇÃO: os interativos pedem o desbloqueio por aqui ---
# Retorna true só quando aprendeu AGORA (false se já tinha ou se o nome está errado).
# Vale mesmo com o modo debug ligado: aprender é sempre real.
func solicitar_desbloqueio(id: StringName) -> bool:
	if not APRENDIDAS.has(id):
		push_warning("Habilidades: '%s' não é uma habilidade que se aprende (confira o nome)." % id)
		return false
	if _aprendidas.has(id):
		return false
	_aprendidas[id] = true
	_log("desbloqueou %s | reais: %s" % [id, exportar_estado()])
	habilidade_desbloqueada.emit(id)
	return true

# --- MODO DEBUG (liberação temporária) ---
func definir_modo_debug(ativo: bool) -> void:
	if _debug == ativo:
		return
	if ativo and not _debug_permitido():
		return   # Numa build final ninguém liga o modo debug
	_debug = ativo
	if not ativo:
		Engine.time_scale = 1.0   # Desligar o debug também desliga a câmera lenta
	_log("modo debug %s | reais: %s" % ["LIGADO" if ativo else "desligado", exportar_estado()])
	modo_debug_alterado.emit(ativo)

func alternar_modo_debug() -> void:
	definir_modo_debug(not _debug)

# --- SAVE (pontos de integração; o sistema de save fica para outra tarefa) ---
# Só os desbloqueios REAIS. O modo debug nunca entra aqui.
func exportar_estado() -> Array[String]:
	var saida: Array[String] = []
	for id in APRENDIDAS:
		if _aprendidas.has(id):
			saida.append(String(id))
	return saida

# Substitui os desbloqueios reais pela lista recebida (nomes desconhecidos são ignorados)
func importar_estado(ids: Array) -> void:
	_aprendidas.clear()
	for item in ids:
		var id := StringName(item)
		if APRENDIDAS.has(id):
			_aprendidas[id] = true
	_log("estado carregado | reais: %s" % [exportar_estado()])
	estado_carregado.emit()

func esquecer_todas() -> void:
	importar_estado([])

# --- INTERNO ---
func _conhecida(id: StringName) -> bool:
	return INICIAIS.has(id) or APRENDIDAS.has(id)

func _avisar_desconhecida(id: StringName) -> void:
	if _avisados.has(id):
		return
	_avisados[id] = true
	push_warning("Habilidades: não existe a habilidade '%s'. Ela foi tratada como BLOQUEADA." % id)

func _log(texto: String) -> void:
	if imprimir_eventos:
		print("Habilidades: ", texto)

# --- ENTRADAS ---
func _unhandled_input(event: InputEvent) -> void:
	var tecla := event as InputEventKey
	if tecla == null or not tecla.pressed or tecla.echo:
		return

	if _debug_permitido():
		_processar_sequencia_debug(tecla)

	# Ferramentas de desenvolvimento: só com o modo debug ligado (jogadores nunca chegam aqui)
	if not _debug:
		return
	match tecla.physical_keycode:
		KEY_K:
			_aprender_proxima()
		KEY_J:
			esquecer_todas()
		KEY_L:
			_alternar_camera_lenta()

# O modo debug existe sempre, a menos que 'somente_em_build_debug' esteja marcado (aí só no editor e em builds de debug)
func _debug_permitido() -> bool:
	return not somente_em_build_debug or OS.is_debug_build()

# Digitar a sequência (666) liga/desliga o modo debug. Qualquer outra tecla zera a contagem.
func _processar_sequencia_debug(tecla: InputEventKey) -> void:
	var digito := _digito_da_tecla(tecla)
	if digito < 0 or sequencia_debug.is_empty():
		_seq_pos = 0
		return

	var agora := Time.get_ticks_msec()
	if _seq_pos > 0 and agora - _seq_ultimo_ms > int(tempo_entre_digitos * 1000.0):
		_seq_pos = 0   # Demorou demais: recomeça
	_seq_ultimo_ms = agora

	if digito == sequencia_debug[_seq_pos]:
		_seq_pos += 1
	else:
		_seq_pos = 1 if digito == sequencia_debug[0] else 0

	if _seq_pos >= sequencia_debug.size():
		_seq_pos = 0
		alternar_modo_debug()

# Dígito da tecla (fileira de cima ou teclado numérico); -1 se não for número
func _digito_da_tecla(tecla: InputEventKey) -> int:
	var k := tecla.physical_keycode
	if k >= KEY_0 and k <= KEY_9:
		return k - KEY_0
	if k >= KEY_KP_0 and k <= KEY_KP_9:
		return k - KEY_KP_0
	return -1

# Câmera lenta (tecla L) para calibrar animações e a origem do lenço quadro a quadro
func _alternar_camera_lenta() -> void:
	Engine.time_scale = 1.0 if Engine.time_scale < 1.0 else 0.15
	_log("câmera lenta %s" % ("LIGADA" if Engine.time_scale < 1.0 else "desligada"))

func _exit_tree() -> void:
	Engine.time_scale = 1.0

func _aprender_proxima() -> void:
	for id in APRENDIDAS:
		if not _aprendidas.has(id):
			solicitar_desbloqueio(id)
			return
	_log("já aprendeu todas")
