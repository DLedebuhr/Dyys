extends CharacterBody2D

# --- CONFIGURAÇÕES DE MOVIMENTAÇÃO ---
@export_group("Velocidade")
@export var velocidade_andar: float = 160.0
@export var velocidade_correr: float = 500.0
@export var aceleracao: float = 1800.0
@export var atrito: float = 2000.0

@export_group("Pulo")
@export var forca_pulo: float = -680.0
@export var gravidade_multiplicador_queda: float = 1.5 # Queda mais pesada/agradável

@export_group("Assistentes de Pulo (Coyote & Buffer)")
@export var coyote_time_limite: float = 0.15 # Segundos para pular após cair da plataforma
@export var jump_buffer_limite: float = 0.15 # Segundos de registro do pulo antes de tocar o chão

@export_group("Planar")
@export var planar_gravidade: float = 0.25 # Fração da gravidade normal durante a planagem
@export var velocidade_queda_planando: float = 80.0 # Velocidade máxima de queda planando
@export var planar_segurando_tecla: bool = true # true: planar enquanto segura | false: aperta de novo para cancelar

@export_group("Reações")
@export var duracao_irritada: float = 2.0          # Uma execução completa, ajustada para esta duração
@export var duracao_agradecer: float = 2.0         # Uma execução completa, ajustada para esta duração
@export var tempo_parada: float = 20.0             # Segundos sem agir até a reação "Parada"
@export var espera_maxima_reacao: float = 3.0      # Quanto um pedido de reação espera ela ficar livre
@export_flags_2d_physics var mascara_sensor: int = 65   # Camadas das áreas que ela detecta (AreaPrePortal)
@export var imprimir_reacoes: bool = true          # Escreve na Saída cada reação (para testar)

@export_subgroup("Transição para a frente")
@export var quadros_transicao_base: Array[Texture2D] = []
@export var quadros_transicao_chapeu: Array[Texture2D] = []
@export_range(0.05, 1.0, 0.01) var duracao_transicao_pose: float = 0.24

@export_subgroup("Brilho da batida de pé (Irritada)")
@export var brilho_batida_ativo: bool = true
@export var frame_batida_pe: int = 1               # Quadro da Irritada em que o pé bate no chão (-1 = em todo quadro)
@export var deslocamento_pe_batida: Vector2 = Vector2.ZERO  # Ajuste até o pé que bate (o X espelha com ela)
@export var cor_brilho_batida: Color = Color(1.0, 0.95, 0.6)
@export var quantidade_brilho_batida: int = 10
@export var alcance_brilho_batida: float = 60.0    # Velocidade com que as faíscas se espalham
@export var duracao_brilho_batida: float = 0.5
@export var tamanho_brilho_batida: float = 0.7
@export_range(0.0, 180.0) var espalhamento_brilho_batida: float = 75.0  # Graus em volta da direção "para cima"

# --- NÓS E REFERÊNCIAS ---
@onready var colisor_corpo: CollisionShape2D = %ColisaoCorpo
@onready var raycast_teto: RayCast2D = %SensorTeto
@onready var sprite: AnimatedSprite2D = %SpritePersonagem
@onready var lenco = %Lenco
@onready var habilidades: OpheliaHabilidades = %Habilidades

# --- VARIÁVEIS DE ESTADO INTERNO ---
# Correr: CapsLock ligado = corre | desligado = caminha (alterna a cada toque)
var esta_correndo: bool = false
var esta_sentada: bool = false
var sentou_por_inatividade: bool = false
var tempo_frontal_imovel: float = 0.0
var esta_levantando: bool = false
# Estado do planar (a animação continua sendo a de pulo; quem anima é o nó Asas)
var planando: bool = false

# false = animações "...Base" (sem chapéu) | true = animações "...Chapeu"
var usando_chapeu: bool = false

# --- REAÇÕES (Irritada, AgradecerAjuda, Parada): acontecem por interação, sem botões ---
const REACAO_IRRITADA: StringName = &"Irritada"
const REACAO_AGRADECER_AJUDA: StringName = &"AgradecerAjuda"
const REACAO_PARADA: StringName = &"Parada"

# Estas animações seguem a imagem original, sem espelhar para onde ela olha (a Transição espelha)
const ANIMACOES_SEM_ESPELHO = ["Irritada", "Agradecer", "Esperar"]

# Para onde ela está olhando. Fica guardado à parte do sprite, porque nas animações acima o
# sprite não espelha, mas ela volta a olhar para o mesmo lado quando a reação termina.
var olhando_esquerda: bool = false

var reacao_atual: StringName = &""      # Reação tocando agora (&"" = nenhuma)
enum EstadoPose { Normal, Entrando, Reagindo, EsperarMovimento, Saindo }
var estado_pose: EstadoPose = EstadoPose.Normal
var lado_transicao: bool = false
var duracao_transicao_atual: float = 0.0
var pulo_apos_transicao: bool = false
var tempo_transicao_pose: float = 0.0       # Tempo restante da Transição
var reacao_pendente: StringName = &""  # Pedido esperando ela ficar livre
var tempo_espera_reacao: float = 0.0         # Quanto tempo o pedido ainda espera
var tempo_ocioso: float = 0.0          # Há quantos segundos ela está sem agir
@onready var _sensor: Area2D = %SensorInteracao              # Detecta as áreas do cenário (AreaPrePortal)

# Contadores dos assistentes de pulo
var tempo_coyote: float = 0.0
var tempo_jump_buffer: float = 0.0

# Impulso externo (propulsor do lenço)
var tempo_embalo: float = 0.0       # Enquanto > 0 no ar, o embalo horizontal não é freado
var pode_cortar_pulo: bool = true   # Soltar o pulo corta a subida, menos se ela subiu por um impulso


# Cada módulo tem uma tarefa. O corpo conserva o estado compartilhado e é o único
# responsável por concluir o movimento físico com move_and_slide().
const Movimento = preload("res://ophelia/componentes/MovimentoOphelia.gd")
const Reacoes = preload("res://ophelia/componentes/ReacoesOphelia.gd")
const Animacao = preload("res://ophelia/componentes/AnimacaoOphelia.gd")
const Interacoes = preload("res://ophelia/componentes/InteracoesOphelia.gd")
var movimento = Movimento.new()
var reacoes = Reacoes.new()
var animacao = Animacao.new()
var interacoes = Interacoes.new()
@onready var entrada = %Entrada
@onready var vitalidade = %Vitalidade
var _pedidos: Array[Dictionary] = []
var _ativadas: Dictionary = {}
@export_range(1, 32, 1) var limite_fila_acoes: int = 12
@export var catalogo_completo: bool = false

func _ready() -> void:
	add_to_group("jogador")
	for componente in [movimento, reacoes, animacao, interacoes]:
		componente.configurar(self)
	_preparar_animacoes_reacao()
	sprite.frame_changed.connect(_ao_mudar_frame)
	sprite.animation_finished.connect(_ao_terminar_animacao_reacao)
	_sensor.collision_mask = mascara_sensor
	_sensor.get_node("FormaInteracao").shape = colisor_corpo.shape
	_sensor.get_node("FormaInteracao").position = colisor_corpo.position
	_sensor.area_entered.connect(_ao_entrar_em_area)
	_tocar("Parado", true)

func _physics_process(delta: float) -> void:
	_ativadas.clear()
	_coletar_pedidos()
	_processar_reacoes(delta)
	_executar_pedidos()
	_atualizar_temporizadores(delta)
	_processar_inputs_estado()
	_processar_planar()
	_aplicar_gravidade(delta)
	_processar_pulo()
	_processar_movimento_horizontal(delta)
	lenco.atualizar_fisica(delta)
	move_and_slide()
	lenco.atualizar_visual(delta)
	_atualizar_animacoes()
	_aplicar_espelho()
	vitalidade.atualizar(delta)
	entrada.limpar_quadro()

func _coletar_pedidos() -> void:
	for pedido in entrada.retirar_pedidos():
		var acao: StringName = pedido["acao"]
		if acao == &"ControleSentarLevantar" and not is_on_floor():
			continue
		if acao == &"ControlePropulsor" and is_on_floor():
			continue
		if _pedidos.size() < limite_fila_acoes:
			_pedidos.append(pedido)

func limpar_comandos() -> void:
	_pedidos.clear()
	_ativadas.clear()
	entrada.retirar_pedidos()
	entrada.limpar_quadro()

func tem_pedido(acao: StringName) -> bool:
	for pedido in _pedidos:
		if pedido["acao"] == acao:
			return true
	return false

func tem_acao_pendente() -> bool:
	return not _pedidos.is_empty()

func acao_ativada(acao: StringName) -> bool:
	return _ativadas.has(acao)

func _executar_pedidos() -> void:
	if _reacao_trava() or not vitalidade.esta_viva():
		return
	var indice: int = 0
	while indice < _pedidos.size():
		var pedido: Dictionary = _pedidos[indice]
		var acao: StringName = pedido["acao"]
		if acao in [&"ControleAtaqueLenco", &"ControleDefesaLenco", &"ControlePropulsor", &"ControleFixarLenco"]:
			if not lenco.pode_receber_acao():
				indice += 1
				continue
			lenco.solicitar_comando(acao, pedido["mouse"])
		elif acao == &"ControleSoltarGancho":
			lenco.soltar_gancho()
		elif acao == &"ControleImpulsoLenco":
			lenco.impulso_gancho_pendente = true
		elif acao == &"ControleTrocarAtaque":
			if pode_usar(OpheliaHabilidades.ATAQUE_LENCO):
				lenco.modo_distancia = not lenco.modo_distancia
		else:
			_ativadas[acao] = true
		_pedidos.remove_at(indice)

func pode_usar(id: StringName) -> bool:
	return habilidades.pode_usar(id)

func esta_em_uso(id: StringName) -> bool:
	match id:
		OpheliaHabilidades.PLANAR:
			return planando
		OpheliaHabilidades.CORRER:
			return esta_correndo
		OpheliaHabilidades.SENTAR_LEVANTAR:
			return esta_sentada
		OpheliaHabilidades.FIXAR_LENCO:
			return _em_gancho()
		OpheliaHabilidades.ATAQUE_LENCO:
			return lenco != null and lenco.estado_atual == lenco.EstadoLenco.ATAQUE
		OpheliaHabilidades.DEFESA_LENCO:
			return lenco != null and lenco.estado_atual == lenco.EstadoLenco.DEFESA
		OpheliaHabilidades.PROPULSOR:
			return lenco != null and lenco.estado_atual == lenco.EstadoLenco.PROPULSOR
		OpheliaHabilidades.AGARRAR_OBJETO:
			return lenco != null and lenco.estado_atual == lenco.EstadoLenco.GANCHO and lenco.ancora_leve
	return false

func em_modo_debug() -> bool:
	return habilidades.esta_em_modo_debug()

func receber_dano(quantidade: int, origem: Vector2 = Vector2.ZERO) -> bool:
	return vitalidade.receber_dano(quantidade, origem, lenco.defesa_ativa())

func tomar_dano(quantidade: int) -> bool:
	return receber_dano(quantidade)

func definir_catalogo_completo(completo: bool) -> void:
	catalogo_completo = completo

func _em_gancho() -> bool:
	return movimento._em_gancho()
func _balancando() -> bool:
	return movimento._balancando()
func _atualizar_temporizadores(delta: float) -> void:
	movimento._atualizar_temporizadores(delta)
func _processar_inputs_estado() -> void:
	movimento._processar_inputs_estado()
func _definir_estado_sentada(sentar: bool) -> void:
	movimento._definir_estado_sentada(sentar)
func _processar_planar() -> void:
	movimento._processar_planar()
func _iniciar_planar() -> void:
	movimento._iniciar_planar()
func _encerrar_planar() -> void:
	movimento._encerrar_planar()
func _aplicar_gravidade(delta: float) -> void:
	movimento._aplicar_gravidade(delta)
func _processar_pulo() -> void:
	movimento._processar_pulo()
func _processar_movimento_horizontal(delta: float) -> void:
	movimento._processar_movimento_horizontal(delta)
func aplicar_impulso(impulso: Vector2, embalo: float = 0.0, velocidade_max: float = 0.0) -> void:
	movimento.aplicar_impulso(impulso, embalo, velocidade_max)
func agradecer_ajuda() -> void:
	reacoes.agradecer_ajuda()
func tocar_reacao(id: StringName) -> void:
	reacoes.tocar_reacao(id)
func cancelar_reacao() -> void:
	reacoes.cancelar_reacao()
func _processar_reacoes(delta: float) -> void:
	reacoes._processar_reacoes(delta)
func _livre_para_reagir() -> bool:
	return reacoes._livre_para_reagir()
func _pode_iniciar_reacao(id: StringName, agindo: bool) -> bool:
	return reacoes._pode_iniciar_reacao(id, agindo)
func _iniciar_reacao(id: StringName) -> void:
	reacoes._iniciar_reacao(id)
func _tocar_transicao_pose(saindo: bool) -> void:
	reacoes._tocar_transicao_pose(saindo)
func _comecar_animacao_reacao() -> void:
	reacoes._comecar_animacao_reacao()
func _entrar_esperar_movimento() -> void:
	reacoes._entrar_esperar_movimento()
func _iniciar_saida_frontal(direcao: float) -> void:
	reacoes._iniciar_saida_frontal(direcao)
func _concluir_transicao_pose() -> void:
	reacoes._concluir_transicao_pose()
func _ao_terminar_animacao_reacao() -> void:
	reacoes._ao_terminar_animacao_reacao()
func _reacao_trava() -> bool:
	return reacoes._reacao_trava()
func progresso_pose_frontal() -> float:
	return reacoes.progresso_pose_frontal()
func _nome_espera_frontal() -> String:
	return reacoes._nome_espera_frontal()
func _log_reacao(texto: String) -> void:
	reacoes._log_reacao(texto)
func _preparar_animacoes_reacao() -> void:
	animacao._preparar_animacoes_reacao()
func _aplicar_espelho() -> void:
	animacao._aplicar_espelho()
func _duracao_animacao(nome: String) -> float:
	return animacao._duracao_animacao(nome)
func _anim_da_reacao(id: StringName) -> String:
	return animacao._anim_da_reacao(id)
func definir_chapeu(usar: bool) -> void:
	animacao.definir_chapeu(usar)
func _nome_anim(nome: String) -> String:
	return animacao._nome_anim(nome)
func _tem_anim(nome: String) -> bool:
	return animacao._tem_anim(nome)
func _tocar(nome: String, reiniciar: bool = false) -> void:
	animacao._tocar(nome, reiniciar)
func _atualizar_animacoes() -> void:
	animacao._atualizar_animacoes()
func _ao_mudar_frame() -> void:
	interacoes._ao_mudar_frame()
func _posicao_pes_global() -> Vector2:
	return interacoes._posicao_pes_global()
func _brilho_nos_pes() -> void:
	interacoes._brilho_nos_pes()
func _textura_brilho() -> Texture2D:
	return interacoes._textura_brilho()
func _ao_entrar_em_area(area: Area2D) -> void:
	interacoes._ao_entrar_em_area(area)
func _deve_ficar_irritada(_area: Area2D) -> bool:
	return interacoes._deve_ficar_irritada(_area)

func teletransportar(destino: Vector2, destino_e_dos_pes: bool = true) -> bool:
	if not em_modo_debug():
		push_warning("OPHELIA: teletransporte só funciona com o modo debug (666) ligado.")
		return false

	var origem_destino = destino
	if destino_e_dos_pes:
		origem_destino = destino - (_posicao_pes_global() - global_position)

	# Zera tudo o que estava em andamento
	cancelar_reacao()
	planando = false
	esta_levantando = false
	esta_sentada = false
	if lenco != null and lenco.has_method("soltar_tudo"):
		lenco.soltar_tudo()
	velocity = Vector2.ZERO
	tempo_embalo = 0.0
	tempo_coyote = 0.0
	tempo_jump_buffer = 0.0

	global_position = origem_destino
	if has_method("reset_physics_interpolation"):
		call("reset_physics_interpolation")
	var camera = get_viewport().get_camera_2d()
	if camera != null:
		camera.reset_smoothing()   # A câmera pula junto, sem deslizar pelo mapa
	return true
