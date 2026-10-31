# ===== SCRIPT DO NÓ "ControladorLenco" (filho do Player). coordenado por Ophelia.gd =====
extends Node2D

enum EstadoLenco { REPOUSO, ATAQUE, PROPULSOR, DEFESA, GANCHO }
var estado_atual: EstadoLenco = EstadoLenco.REPOUSO

# --- COMPRIMENTOS E ALCANCES INDEPENDENTES ---
@export var comprimento_maximo: float = 100.0  # Comprimento visual no repouso
@export var alcance_ataque: float = 180.0      # Alcance do ataque (Q) esticado
@export var alcance_propulsor: float = 200.0   # Alcance do propulsor (E): quanto as fitas esticam
@export var alcance_gancho: float = 350.0      # Alcance máximo do gancho

@export var pontos_por_fita: int = 9          # 5 nós base + 4 interpolações
@export var sensibilidade_arrasto_pulo: float = 0.06 # Reatividade do lenço no pulo/queda

# --- CONFIGURAÇÕES DO GANCHO ---
@export var forca_embalo_ar: float = 500.0   # Aceleração horizontal ao balançar com a corda esticada

# --- ORIGEM DAS FITAS POR ANIMAÇÃO ---
# A gola já está no desenho; aqui a ORIGEM DAS FITAS é que acompanha a gola desenhada.
# Quanto a origem desce (+Y) / desloca (X) em cada FRAME da animação,
# em relação à posição normal (y=21 em pé). As chaves são os nomes reais das animações
# (Base e Chapeu).
# sentar: y=32, 39, 48  ->  offsets 11, 18, 27
# Se a lista tiver menos itens que a animação, o último valor é mantido.
# X é espelhado automaticamente quando o sprite está virado (flip_h).
@export var offset_gola_por_animacao: Dictionary = {
	"SentarBase": [Vector2(0, 9), Vector2(0, 16), Vector2(0, 25)],
	"SentarChapeu": [Vector2(0, 9), Vector2(0, 16), Vector2(0, 25)],
	"LevantarBase": [Vector2(0, 25), Vector2(0, 16), Vector2(0, 9)],
	"LevantarChapeu": [Vector2(0, 25), Vector2(0, 16), Vector2(0, 9)],
}
@export var suavidade_offset_gola: float = 100.0 # Maior = acompanha mais rápido

# --- SUAVIDADE DO ATAQUE / DEFESA ---
# Ataque (Q) e defesa (E): UM aperto dispara a ação inteira na direção do mouse e ela volta sozinha
@export var duracao_formacao_ataque: float = 0.22 # Tempo (s) da ponta até a posição final (Q)
@export var tempo_ativo_ataque: float = 0.12      # Tempo (s) com o ataque esticado (causa dano)
@export var duracao_formacao_defesa: float = 0.4  # Tempo (s) das fitas desenharem a redoma até fechar (E)
@export var tempo_ativo_defesa: float = 0.45      # Tempo (s) com a redoma fechada
@export var recarga_acao: float = 0.15            # Pausa (s) ao terminar, antes de poder usar de novo
@export var duracao_retorno: float = 0.4    # Tempo (s) para o lenço voltar ao repouso solto
@export var subdivisoes_curva: int = 4      # Arredondamento das curvas (1 = sem arredondar)

# --- INDICADOR DE ALCANCE DO GANCHO ---
@export var indicador_alcance_ativo: bool = true
@export var alcance_alternar: bool = false      # false: mostra enquanto segura | true: liga/desliga a cada aperto
@export var duracao_aviso_alcance: float = 1.2  # Segundos visível ao clicar sem ter onde prender
@export var cor_alcance: Color = Color(1.0, 1.0, 1.0, 1.0)
const ACAO_ALCANCE: String = "ControleMostrarAlcance"

# O ataque à distância acertou algo que o ataque machuca (ligue aqui o dano, se o seu inimigo não reagir sozinho)
signal projetil_acertou(alvo: Node)

@onready var fita_tras: Line2D = %FitaTras
@onready var fita_frente: Line2D = %FitaFrente
@onready var raio_alcance: RayCast2D = %SensorGancho
@onready var jogador: CharacterBody2D = get_node("..")

# Nós de Colisão
@onready var area_ataque: Area2D = $AreaAtaque
@onready var area_defesa: Area2D = $AreaDefesa

@export var textura_ponta: Texture2D
@export var tamanho_ponta: Vector2 = Vector2(24, 24)

# --- IMPULSO E AGARRAR OBJETO (habilidade aprendida na Primavera) ---
# Valores PROVISÓRIOS, ainda não aprovados: ajuste no Inspetor.
@export_group("Impulso e agarrar objeto")
@export var velocidade_impulso: float = 650.0          # Impulso da personagem rumo a um ponto firme (antes fixo no código)
@export var velocidade_impulso_objeto: float = 650.0   # Impulso que lança um objeto leve rumo à personagem
@export var limite_forca_lenco: float = 5.0            # Maior "força necessária" (massa) que o lenço consegue puxar
@export var leves_exigem_habilidade: bool = true       # true: objetos leves só prendem o lenço depois de aprender AgarrarObjeto
@export var soltar_alem_do_alcance: float = 1.3        # Solta o objeto leve se passar de (alcance_gancho x isto)

# --- LENÇO DE FRENTE (Irritada / Agradecer) ---
# De lado, as duas fitas saem do mesmo ponto (cada uma de um lado do pescoço, vistas de perfil).
# Quando ela olha para o jogador, as duas continuam uma de cada lado do pescoço: as origens se afastam
# para os lados e cada fita cai para o seu lado (a de trás é a que atravessa). Ao terminar, voltam juntas à posição normal.
@export_group("Lenço de frente")
@export var angulo_caimento_frente: float = 55.0   # Graus abaixo da horizontal de cada ponta (90 = reta para baixo)
@export var inverter_lados_frente: bool = false    # Troca qual fita vai para qual lado
@export var separacao_pescoco_frente: float = 10.0 # De frente: distância (px) de cada fita até o centro do pescoço
# Origem de CADA fita, somada à origem comum (mesmo formato do offset_gola_por_animacao: um Vector2 por quadro).
# Vazio = as duas saem do mesmo ponto. Exemplo: "IrritadaBase": [Vector2(-12, 0), Vector2(-12, 0)]
@export var offset_fita_tras_por_animacao: Dictionary = {}
@export var offset_fita_frente_por_animacao: Dictionary = {}

@export_group("Calibração (modo debug)")
@export var mostrar_origens_debug: bool = true     # Com o modo debug ligado, desenha as origens das fitas e o quadro atual

@export_group("Defesa (círculo)")
# Um único raio mantém a mesma medida na horizontal e na vertical.
@export_range(20.0, 500.0, 1.0) var raio_defesa: float = 92.0
@export_range(0.0, 45.0, 1.0) var sobreposicao_arcos_defesa: float = 0.0
@export var redoma_deslocamento: Vector2 = Vector2.ZERO
var caminho_defesa_frente: Array[Vector2] = []
var caminho_defesa_tras: Array[Vector2] = []

@export_group("Teclas")

# --- ATAQUE À DISTÂNCIA (Shift troca a forma do ataque) ---
# Valores PROVISÓRIOS, ainda não aprovados: ajuste no Inspetor.
# Com o modo ligado, Q lança um projétil independente sem esconder as pontas do lenço.
@export_group("Ataque à distância (Shift)")
@export var textura_projetil: Texture2D
@export var tamanho_projetil: Vector2 = Vector2(24, 24)
@export var raio_apoio_projetil: float = 20.0
@export var dano_ataque_normal: int = 10
@export var dano_projetil: int = 5
@export_flags_2d_physics var mascara_dano: int = 1
@export var velocidade_projetil: float = 700.0      # Velocidade da ponta indo
@export var alcance_projetil: float = 420.0         # Distância máxima que a ponta voa
@export var velocidade_volta_projetil: float = 950.0   # Velocidade da ponta voltando
@export var tempo_recarga_projetil: float = 5.0 # Espera no ponto de impacto antes de retornar
@export var raio_projetil: float = 10.0             # Tamanho do brilho e do acerto da ponta

# --- PROPULSOR (tecla S, só no ar) --- valores PROVISÓRIOS, ainda não aprovados
# S também é a tecla de sentar, mas sentar só vale no chão e o propulsor só vale no ar: nunca se cruzam.
@export_group("Propulsor (no ar)")
@export var forca_propulsor: float = 680.0         # Velocidade do impulso no sentido contrário ao mouse
@export var usos_propulsor_no_ar: int = 1          # Quantos usos por salto (zera ao tocar o chão)
@export var embalo_propulsor: float = 0.12          # Segundos em que o impulso não é freado pelo atrito do ar
@export var velocidade_max_propulsor: float = 700.0  # Limite da velocidade depois do impulso
@export var duracao_formacao_propulsor: float = 0.12  # Tempo (s) das fitas até a posição final
@export var tempo_ativo_propulsor: float = 0.2     # Tempo (s) com as fitas esticadas

var pontos_tras: Array[Vector2] = []
var pontos_frente: Array[Vector2] = []

var tempo_balanco: float = 0.0
var vel_suave: float = 0.0
var vel_y_suave: float = 0.0

var ponto_ancora_gancho: Vector2 = Vector2.ZERO
var distancia_corda: float = 0.0

# Âncora presa a um objeto/plataforma móvel: o ponto acompanha o alvo
var alvo_gancho: Node2D = null
var ancora_local: Vector2 = Vector2.ZERO
var ancora_segue: bool = false
var ancora_leve: bool = false   # true: a âncora é um objeto leve (o impulso o lança até a personagem)

@onready var efeitos: OpheliaEfeitosLenco = $Efeitos   # Efeitos especiais do ataque e da defesa (rastro de luz, faíscas, explosão)

# Lido pelo script do jogador: true quando a corda está tensa (balanço)
var corda_esticada: bool = false

# Nós do jogador guardados uma vez só
@onready var sprite_jogador: AnimatedSprite2D = %SpritePersonagem
@onready var ponto_gola: Marker2D = $OrigemLenco

# Acompanhamento da origem (evita "dobra" nos primeiros pontos da fita)
var origem_anterior: Vector2 = Vector2.ZERO
var origem_inicializada: bool = false
var offset_gola_atual: Vector2 = Vector2.ZERO
var offset_tras_atual: Vector2 = Vector2.ZERO    # Origem extra da fita de trás (suavizada)
var offset_frente_atual: Vector2 = Vector2.ZERO  # Origem extra da fita da frente (suavizada)
var frontal: float = 0.0                         # 0 = de lado | 1 = de frente (uma ponta para cada lado)
var frente_defesa: float = 1.0                   # Lado para onde ela olhava ao começar a defesa (+1 direita | -1 esquerda)
var vertices_redoma: Array[Vector2] = []         # Contorno circular neste quadro (mundo)
var impulso_propulsor_pendente: bool = false     # O impulso sai só quando a animação chega ao auge
var modo_distancia: bool = false                 # Shift: false = golpe curto | true = ponta lançada
var ataque_a_distancia: bool = false             # Modo travado no instante em que o ataque começou
var alvos_atingidos: Array[int] = []
var projeteis: Array[OpheliaProjetilLenco] = []         # Cada projétil ocupa uma das duas cargas
var projetil_lancado: bool = false               # O ataque atual já lançou a ponta?
var usos_propulsor: int = 0                      # Usos do propulsor neste salto

# Transições de estado (formação do ataque/defesa e retorno ao repouso)
var estado_anterior: EstadoLenco = EstadoLenco.REPOUSO
var tempo_estado: float = 0.0
var tempo_retorno: float = 999.0
var pontos_inicio_tras: Array[Vector2] = []
var pontos_inicio_frente: Array[Vector2] = []

# Ação rápida (Q/E)
var dir_acao: Vector2 = Vector2.RIGHT              # Direção travada no mouse no momento do aperto
var tempo_recarga: float = 0.0
var acao_pendente: EstadoLenco = EstadoLenco.REPOUSO # Aperto guardado por um instante (REPOUSO = nenhum)
var tempo_acao_pendente: float = 0.0

# Indicador de alcance
var origem_alcance: Vector2 = Vector2.ZERO
var tempo_aviso_alcance: float = 0.0
var alcance_visivel: float = 0.0     # 0 a 1 (fade)
var alcance_alternado: bool = false
var pulso_alcance: float = 1.0       # 0 a 1: anel que se expande ao aparecer (1 = parado)
var tempo_visual_alcance: float = 0.0
var mostrando_alcance_antes: bool = false


const Visual = preload("res://Ophelia/Lenco/VisualLenco.gd")
const Combate = preload("res://Ophelia/Lenco/CombateLenco.gd")
const Gancho = preload("res://Ophelia/Lenco/GanchoLenco.gd")
const CenaProjetil = preload("res://Ophelia/Projeteis/ProjetilLenco.tscn")
var visual = Visual.new()
var combate = Combate.new()
var gancho = Gancho.new()
var impulso_gancho_pendente: bool = false
var _alvo_comando: Vector2 = Vector2.ZERO

func _ready() -> void:
	set_physics_process(false)
	for componente in [visual, combate, gancho]:
		componente.configurar(self)
	for i in range(pontos_por_fita):
		pontos_tras.append(global_position)
		pontos_frente.append(global_position)
		pontos_inicio_tras.append(global_position)
		pontos_inicio_frente.append(global_position)
	area_ataque.get_node("FormaAtaque").shape.size = Vector2(alcance_ataque * 0.6, 36.0)
	area_ataque.collision_mask = mascara_dano
	area_ataque.set_meta("dano", dano_ataque_normal)
	area_ataque.body_entered.connect(_ao_ataque_normal_atingir)
	area_ataque.area_entered.connect(_ao_ataque_normal_atingir)
	_desativar_colisores()
	efeitos.configurar_cor(_cor_do_lenco())
	raio_alcance.add_exception(jogador)

func pode_receber_acao() -> bool:
	return acao_pendente == EstadoLenco.REPOUSO and not _eh_acao(estado_atual) and tempo_recarga <= 0.0

func solicitar_comando(acao: StringName, mouse: Vector2) -> void:
	_alvo_comando = mouse
	match acao:
		&"ControleAtaqueLenco":
			if _pode_usar(OpheliaHabilidades.ATAQUE_LENCO):
				_pedir_acao(EstadoLenco.ATAQUE)
		&"ControleDefesaLenco":
			if _pode_usar(OpheliaHabilidades.DEFESA_LENCO):
				_pedir_acao(EstadoLenco.DEFESA)
		&"ControlePropulsor":
			if _pode_propulsionar():
				_pedir_acao(EstadoLenco.PROPULSOR)
		&"ControleFixarLenco":
			_tentar_disparar_gancho(origem_anterior, mouse)

func soltar_gancho() -> void:
	if estado_atual == EstadoLenco.GANCHO:
		estado_atual = EstadoLenco.REPOUSO
		_limpar_ancora()

func defesa_ativa() -> bool:
	return estado_atual == EstadoLenco.DEFESA and tempo_estado >= duracao_formacao_defesa * 0.6

func atualizar_fisica(delta: float) -> void:
	tempo_recarga = maxf(tempo_recarga - delta, 0.0)
	if jogador.is_on_floor():
		usos_propulsor = 0
	_checar_fim_acao()
	_executar_acao_pendente(origem_anterior, _alvo_comando, delta)
	if estado_atual != estado_anterior:
		_ao_mudar_estado(estado_anterior, estado_atual)
		estado_anterior = estado_atual
	tempo_estado += delta
	corda_esticada = false
	if estado_atual == EstadoLenco.PROPULSOR:
		combate.aplicar_propulsor()
	elif estado_atual == EstadoLenco.GANCHO:
		_atualizar_gancho_pendulo(origem_anterior, delta)
	impulso_gancho_pendente = false

func atualizar_visual(delta: float) -> void:
	var origem: Vector2 = ponto_gola.global_position + _calcular_offset_gola(delta)
	_calcular_offsets_fitas(delta)
	_atualizar_frontal(delta)
	_acompanhar_origem(origem)
	_atualizar_indicador_alcance(origem, delta)
	match estado_atual:
		EstadoLenco.REPOUSO:
			_atualizar_repouso_firme(origem, delta)
		EstadoLenco.ATAQUE:
			_atualizar_ataque(origem, delta)
		EstadoLenco.DEFESA:
			_atualizar_defesa(origem, delta)
		EstadoLenco.PROPULSOR:
			_atualizar_propulsor(origem, delta)
		EstadoLenco.GANCHO:
			gancho.atualizar_visual_corda(origem, delta)
	_atualizar_efeitos(delta)
	_redesenhar_line2d()
	queue_redraw()

func _ao_mudar_estado(anterior: EstadoLenco, novo: EstadoLenco) -> void:
	tempo_estado = 0.0
	if novo == EstadoLenco.DEFESA:
		frente_defesa = -1.0 if _olhando_esquerda() else 1.0   # O círculo não vira se ela virar no meio
	if novo == EstadoLenco.ATAQUE:
		alvos_atingidos.clear()
		projetil_lancado = false
	# Saiu do propulsor antes do auge: o impulso não sai
	if anterior == EstadoLenco.PROPULSOR:
		impulso_propulsor_pendente = false
	# Guarda a pose atual: a formação do ataque/defesa parte dela
	for i in range(pontos_por_fita):
		pontos_inicio_tras[i] = pontos_tras[i]
		pontos_inicio_frente[i] = pontos_frente[i]
	# Saiu do ataque/defesa (por qualquer motivo): desliga as áreas de dano/defesa
	if _eh_acao(anterior):
		_desativar_colisores()
	# Saiu do gancho: esquece o alvo preso (um objeto solto segue com a velocidade que tinha)
	if novo != EstadoLenco.GANCHO:
		_limpar_ancora()
	# Saiu do ataque/defesa para o repouso: inicia o retorno lento
	if _eh_acao(anterior) and novo == EstadoLenco.REPOUSO:
		tempo_retorno = 0.0

func _pedir_acao(novo: EstadoLenco) -> void:
	acao_pendente = novo
	tempo_acao_pendente = 0.2

func _executar_acao_pendente(origem: Vector2, alvo_mouse: Vector2, delta: float) -> void:
	if acao_pendente == EstadoLenco.REPOUSO:
		return

	tempo_acao_pendente -= delta
	if tempo_acao_pendente < 0.0:
		acao_pendente = EstadoLenco.REPOUSO
		return

	# Ainda ocupado (outra ação rolando ou em recarga): espera
	if _eh_acao(estado_atual) or tempo_recarga > 0.0:
		return

	# Trava a direção do mouse neste instante (sem mouse válido, usa para onde o personagem olha)
	var vetor = alvo_mouse - origem
	if vetor.length() > 1.0:
		dir_acao = vetor.normalized()
	else:
		var olhando_esquerda: bool = _olhando_esquerda()
		dir_acao = Vector2.LEFT if olhando_esquerda else Vector2.RIGHT

	# Propulsor: só no ar, com a habilidade e usos sobrando. O uso é gasto agora, mas o impulso só sai
	# quando as fitas completam o golpe na direção do mouse (veja _atualizar_propulsor).
	if acao_pendente == EstadoLenco.PROPULSOR:
		if not _pode_propulsionar():
			acao_pendente = EstadoLenco.REPOUSO
			return
		usos_propulsor += 1
		impulso_propulsor_pendente = true

	# Cada projétil ativo ocupa uma carga; há dois disparos disponíveis.
	if acao_pendente == EstadoLenco.ATAQUE:
		if not _pode_usar(OpheliaHabilidades.ATAQUE_MODIFICADO):
			modo_distancia = false

		if modo_distancia and projeteis.size() >= 2:
			acao_pendente = EstadoLenco.REPOUSO
			return

		ataque_a_distancia = modo_distancia

	estado_atual = acao_pendente
	acao_pendente = EstadoLenco.REPOUSO

func _checar_fim_acao() -> void:
	var total = 0.0
	match estado_atual:
		EstadoLenco.ATAQUE:
			total = duracao_formacao_ataque + tempo_ativo_ataque
		EstadoLenco.PROPULSOR:
			total = duracao_formacao_propulsor + tempo_ativo_propulsor
		EstadoLenco.DEFESA:
			total = duracao_formacao_defesa + tempo_ativo_defesa
		_:
			return

	if tempo_estado >= total:
		estado_atual = EstadoLenco.REPOUSO
		_desativar_colisores()
		tempo_recarga = recarga_acao

func soltar_tudo() -> void:
	estado_atual = EstadoLenco.REPOUSO
	acao_pendente = EstadoLenco.REPOUSO
	tempo_acao_pendente = 0.0
	corda_esticada = false
	origem_inicializada = false   # Os pontos da fita voltam a nascer na gola, sem esticar pelo mapa
	if efeitos:
		efeitos.parar()
	impulso_propulsor_pendente = false
	for p in projeteis:
		if is_instance_valid(p):
			p.queue_free()
	projeteis.clear()
	_limpar_ancora()
	_desativar_colisores()

func _eh_acao(e: EstadoLenco) -> bool:
	return e == EstadoLenco.ATAQUE or e == EstadoLenco.PROPULSOR or e == EstadoLenco.DEFESA

func _pode_propulsionar() -> bool:
	return jogador != null and not jogador.is_on_floor() \
			and usos_propulsor < usos_propulsor_no_ar \
			and _pode_usar(OpheliaHabilidades.PROPULSOR) \
			and jogador.has_method("aplicar_impulso")

func _pode_usar(id: StringName) -> bool:
	return jogador.pode_usar(id)

func _atualizar_efeitos(delta: float) -> void:
	if efeitos == null:
		return
	var tipo = OpheliaEfeitosLenco.Tipo.NENHUM
	var progresso = 1.0
	match estado_atual:
		EstadoLenco.ATAQUE:
			tipo = OpheliaEfeitosLenco.Tipo.ATAQUE
			progresso = clampf(tempo_estado / maxf(duracao_formacao_ataque, 0.01), 0.0, 1.0)
		EstadoLenco.PROPULSOR:
			tipo = OpheliaEfeitosLenco.Tipo.PROPULSOR
			progresso = clampf(tempo_estado / maxf(duracao_formacao_propulsor, 0.01), 0.0, 1.0)
		EstadoLenco.DEFESA:
			tipo = OpheliaEfeitosLenco.Tipo.DEFESA
			progresso = clampf(tempo_estado / maxf(duracao_formacao_defesa, 0.01), 0.0, 1.0)
	efeitos.ataque_a_distancia = ataque_a_distancia
	var direcao_visual = dir_acao
	efeitos.atualizar(delta, tipo, direcao_visual, progresso, origem_anterior,
			pontos_tras[pontos_por_fita - 1], pontos_frente[pontos_por_fita - 1],
			_centro_corpo())

func _desativar_colisores() -> void:
	if area_ataque: area_ataque.monitoring = false
	if area_defesa:
		area_defesa.monitoring = false
		area_defesa.monitorable = false

func _calcular_offset_gola(delta: float) -> Vector2:
	return visual._calcular_offset_gola(delta)
func _offset_do_dicionario(dic: Dictionary) -> Vector2:
	return visual._offset_do_dicionario(dic)
func _calcular_offsets_fitas(delta: float) -> void:
	visual._calcular_offsets_fitas(delta)
func _atualizar_frontal(delta: float) -> void:
	visual._atualizar_frontal(delta)
func _olhando_esquerda() -> bool:
	return visual._olhando_esquerda()
func _acompanhar_origem(origem: Vector2) -> void:
	visual._acompanhar_origem(origem)
func _peso_ponto(t: float, taxa_base: float, taxa_ponta: float, delta: float) -> float:
	return visual._peso_ponto(t, taxa_base, taxa_ponta, delta)
func _ondas_repouso(t: float, amp: float, fator_ponta: float) -> Vector2:
	return visual._ondas_repouso(t, amp, fator_ponta)
func _amostrar_caminho(offsets: Array[Vector2], pos: float) -> Vector2:
	return visual._amostrar_caminho(offsets, pos)
func _aplicar_forma(origem: Vector2, dir: Vector2, alcance: float,
		offsets_verde: Array[Vector2], offsets_vermelho: Array[Vector2], delta: float, duracao: float) -> void:
	visual._aplicar_forma(origem, dir, alcance, offsets_verde, offsets_vermelho, delta, duracao)
func _mover_para_figura(final_verde: Array[Vector2], final_vermelho: Array[Vector2], delta: float, duracao: float) -> void:
	visual._mover_para_figura(final_verde, final_vermelho, delta, duracao)
func _suavizar_curva(pts: Array[Vector2]) -> PackedVector2Array:
	return visual._suavizar_curva(pts)
func _atualizar_indicador_alcance(origem: Vector2, delta: float) -> void:
	visual._atualizar_indicador_alcance(origem, delta)
func _desenhar_alcance() -> void:
	visual._desenhar_alcance()
func _atualizar_repouso_firme(origem: Vector2, delta: float) -> void:
	visual._atualizar_repouso_firme(origem, delta)
func _caminho_circular_defesa(origem: Vector2, centro: Vector2, raio: float,
		inicio: float, extra: float, lado_saida: float) -> Array[Vector2]:
	return visual._caminho_circular_defesa(origem, centro, raio, inicio, extra, lado_saida)
func _revelar_caminho_defesa(caminho: Array[Vector2], inicial: Array[Vector2],
		progresso: float, mistura: float) -> Array[Vector2]:
	return visual._revelar_caminho_defesa(caminho, inicial, progresso, mistura)
func _redesenhar_line2d() -> void:
	visual._redesenhar_line2d()
func _draw() -> void:
	visual._draw()
func _desenhar_indicador_modo() -> void:
	visual._desenhar_indicador_modo()
func _desenhar_origens_debug() -> void:
	visual._desenhar_origens_debug()
func _desenhar_ponta_no_ponto(ponto_anterior: Vector2, ponto_final: Vector2) -> void:
	visual._desenhar_ponta_no_ponto(ponto_anterior, ponto_final)
func _centro_corpo() -> Vector2:
	return visual._centro_corpo()
func _cor_do_lenco() -> Color:
	return visual._cor_do_lenco()
func _atualizar_ataque(origem: Vector2, delta: float) -> void:
	combate._atualizar_ataque(origem, delta)
func _atualizar_defesa(origem: Vector2, _delta: float) -> void:
	combate._atualizar_defesa(origem, _delta)
func _atualizar_propulsor(origem: Vector2, delta: float) -> void:
	combate._atualizar_propulsor(origem, delta)
func _lancar_projetil() -> void:
	combate._lancar_projetil()
func _posicao_da_gola() -> Vector2:
	return combate._posicao_da_gola()
func _ao_projetil_acertar(alvo: Node, p: OpheliaProjetilLenco) -> void:
	combate._ao_projetil_acertar(alvo, p)
func _ao_projetil_bater(onde: Vector2) -> void:
	combate._ao_projetil_bater(onde)
func _ao_projetil_voltar(p: OpheliaProjetilLenco) -> void:
	combate._ao_projetil_voltar(p)
func _ao_ataque_normal_atingir(contato: Node) -> void:
	combate._ao_ataque_normal_atingir(contato)
func _tentar_disparar_gancho(origem: Vector2, alvo_mouse: Vector2) -> void:
	gancho._tentar_disparar_gancho(origem, alvo_mouse)
func _atualizar_gancho_pendulo(origem: Vector2, delta: float) -> void:
	gancho._atualizar_gancho_pendulo(origem, delta)
func _atualizar_gancho_leve(origem: Vector2) -> void:
	gancho._atualizar_gancho_leve(origem)
func _forca_necessaria(corpo: Object) -> float:
	return gancho._forca_necessaria(corpo)
func _limpar_ancora() -> void:
	gancho._limpar_ancora()
func _buscar_projetil_apoio(origem: Vector2, mouse: Vector2, limite: float) -> OpheliaProjetilLenco:
	return gancho._buscar_projetil_apoio(origem, mouse, limite)
func _soltar_apoio_projetil(p: OpheliaProjetilLenco) -> void:
	gancho._soltar_apoio_projetil(p)
