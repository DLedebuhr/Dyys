extends Area2D
## Contração -> viagem -> absorção -> luz nas fitas em repouso -> ecos -> ajuda.
signal habilidade_habilitada(id: StringName)
@export_group("Habilidade")
@export_enum("AtaqueLenco", "AtaqueModificado", "DefesaLenco", "Planar", "AgarrarObjeto", "Propulsor") var habilidade: String = "AtaqueLenco"
@export var caminho_habilidades: NodePath = ^"Habilidades"
@export var acao_interagir: StringName = &"ControleInteragir"
@export_group("Conteúdo da ajuda")
@export var ajuda_personalizada: OpheliaDadosAjudaHabilidade # Vazio = usa o cadastro da cena base.
@export_group("Símbolo e brilho")
@export var textura_simbolo: Texture2D
@export_range(8.0, 256.0, 1.0) var tamanho_simbolo: float = 100.0
@export var cor_luz: Color = Color(0.486, 0.498, 0.741, 1.0)
@export_range(0.0, 30.0, 0.5) var altura_flutuacao: float = 6.0
@export_range(0.1, 6.0, 0.1) var velocidade_flutuacao: float = 2.0
@export_group("Brilho por proximidade")
@export_range(50.0, 1500.0, 10.0) var distancia_brilho: float = 400.0
@export_range(0.0, 3.0, 0.05) var brilho_distante: float = 0.3
@export_range(0.5, 6.0, 0.1) var brilho_proximo: float = 2.4
@export_group("Etapas do aprendizado")
@export_range(0.1, 3.0, 0.05) var duracao_contracao: float = 0.6
@export_range(0.1, 3.0, 0.05) var duracao_viagem: float = 0.65
@export_range(0.1, 2.0, 0.05) var duracao_absorcao: float = 0.25
@export_range(0.2, 4.0, 0.05) var duracao_luz_lenco: float = 0.9
@export_range(0.2, 3.0, 0.05) var duracao_ecos: float = 0.65
@export_range(2.0, 30.0, 0.5) var tamanho_bolinha: float = 7.0
@onready var visual: Node2D = $Visual
@onready var simbolo: Sprite2D = $Visual/Simbolo
@onready var ajuda: CanvasLayer = $TelaHelpHabilidade
var _jogador: CharacterBody2D
var _gestor: Node
var _efeito_lenco := OpheliaAprendizadoLenco.new()
var _tempo: float = 0.0
var _tempo_etapa: float = 0.0
var _etapa: int = 0 # 0 contração, 1 viagem, 2 absorção, 3 fitas, 4 ecos, 5 ajuda.
var _brilho_atual: float = 0.3
var _executando: bool = false
var _consumido: bool = false
var _pausa_propria: bool = false
var _modo_anterior: Node.ProcessMode
var _ponto_inicial: Vector2
var _ponto_luz: Vector2
var _escala_inicial: Vector2 = Vector2.ONE
var _material_luz: ShaderMaterial
var _observador: Node2D

# Preparar o nó
# ---------------------
# Configura referências, sinais e estado inicial.
func _ready() -> void:

	add_to_group("coletaveis_ophelia")
	body_entered.connect(_ao_entrar)
	body_exited.connect(_ao_sair)
	ajuda.fechada.connect(_ao_fechar_ajuda)
	simbolo.texture = textura_simbolo

	if textura_simbolo != null:

		var maior: float = maxf(textura_simbolo.get_width(), textura_simbolo.get_height())
		simbolo.scale = Vector2.ONE * tamanho_simbolo / maxf(maior, 1.0)

	_material_luz = ShaderMaterial.new()
	_material_luz.shader = preload("res://Scenes/Interactables/BrilhoInterativo.gdshader")
	_material_luz.set_shader_parameter("cor", cor_luz)
	simbolo.material = _material_luz
	simbolo.scale *= 1.5

# Ao entrar
# ---------------------
# Trata o evento: entrar.
func _ao_entrar(body: Node2D) -> void:

	if body is CharacterBody2D and body.is_in_group("jogador"):

		_jogador = body

# Ao sair
# ---------------------
# Trata o evento: sair.
func _ao_sair(body: Node2D) -> void:

	if body == _jogador and not _executando:

		_jogador = null


# Verificar o aprendizado disponível
# ---------------------
# Só oferece a interação para uma habilidade válida e ainda não aprendida.
func pode_interagir(jogador: CharacterBody2D) -> bool:

	if _consumido or _executando or get_tree().paused or not is_instance_valid(jogador) or jogador != _jogador:

		return false

	var vida: Node = jogador.get_node_or_null("Vitalidade")

	if vida != null and not bool(vida.call("esta_viva")):

		return false

	var gestor: Node = jogador.get_node_or_null(caminho_habilidades)

	if gestor == null or not gestor.has_method("esta_desbloqueada") or not gestor.has_method("solicitar_desbloqueio"):

		return false

	if bool(gestor.call("esta_desbloqueada", StringName(habilidade))):

		return false

	return habilidade != "AtaqueModificado" or bool(gestor.call("esta_desbloqueada", &"AtaqueLenco"))

# Interagir
# ---------------------
# Processa interagir.
func interagir(jogador: CharacterBody2D) -> bool:

	if not pode_interagir(jogador):

		return false

	_gestor = jogador.get_node_or_null(caminho_habilidades)

	if _gestor == null or not _gestor.has_method("solicitar_desbloqueio") or not _gestor.has_method("esta_desbloqueada"):

		push_warning("HabilitarHabilidade: confira Caminho Habilidades no Inspetor.")
		return false

	if bool(_gestor.call("esta_desbloqueada", StringName(habilidade))):

		return false

	if habilidade == "AtaqueModificado" and not bool(_gestor.call("esta_desbloqueada", &"AtaqueLenco")):

		return false

	if not ajuda.has_method("configurar_habilidade"):

		push_warning("Atualize o script TelaHelpHabilidade.gd para selecionar o conteúdo da habilidade.")
		return false

	if not bool(ajuda.call("configurar_habilidade", StringName(habilidade), ajuda_personalizada)):

		return false

	if not _efeito_lenco.preparar(jogador):

		push_warning("HabilitarHabilidade: o lenço precisa estar em repouso, com os nós Lenco/OrigemLenco e Lenco/Efeitos.")
		return false

	_jogador = jogador
	_executando = true
	_etapa = 0
	_tempo_etapa = 0.0
	_ponto_inicial = visual.global_position
	_ponto_luz = _ponto_inicial
	_escala_inicial = visual.scale
	_modo_anterior = process_mode
	process_mode = Node.PROCESS_MODE_ALWAYS
	_pausa_propria = true
	get_tree().paused = true
	_efeito_lenco.iniciar()

	if jogador.has_method("limpar_comandos"):

		jogador.call("limpar_comandos")

	return true

# Atualizar a cada quadro
# ---------------------
# Atualiza os temporizadores, a interface ou os efeitos deste nó.
func _process(delta: float) -> void:

	_tempo += delta

	if not _executando:

		if not _consumido:

			visual.position.y = sin(_tempo * velocidade_flutuacao) * altura_flutuacao
			var menor: float = distancia_brilho

			if not is_instance_valid(_observador):

				_observador = get_tree().get_first_node_in_group("jogador") as Node2D

			if is_instance_valid(_observador):

				menor = minf(menor, global_position.distance_to(_observador.global_position))

			var fator: float = 1.0 - smoothstep(0.0, maxf(distancia_brilho, 1.0), menor)
			_brilho_atual = lerpf(_brilho_atual, lerpf(brilho_distante, brilho_proximo, fator), 1.0 - exp(-6.0 * delta))
			_material_luz.set_shader_parameter("intensidade", _brilho_atual)
			queue_redraw()

		return

	if _etapa == 5:

		return

	if not is_instance_valid(_jogador) or not is_instance_valid(_gestor) or not _efeito_lenco.valido():

		_cancelar()
		return

	_tempo_etapa += delta
	var duracoes: Array[float] = [duracao_contracao, duracao_viagem, duracao_absorcao, duracao_luz_lenco, duracao_ecos]
	var p: float = clampf(_tempo_etapa / maxf(duracoes[_etapa], 0.01), 0.0, 1.0)
	var progresso_fitas: float = -1.0

	if _etapa == 3:

		progresso_fitas = p

	elif _etapa == 4:

		progresso_fitas = 1.0

	_efeito_lenco.atualizar(delta, progresso_fitas)

	match _etapa:

		0:

			var contracao: float = smoothstep(0.0, 1.0, p)
			visual.scale = _escala_inicial * lerpf(1.0, 0.05, contracao)
			visual.modulate.a = 1.0 - smoothstep(0.65, 1.0, p)
			_material_luz.set_shader_parameter("intensidade", _brilho_atual * lerpf(1.0, 2.0, contracao))

		1:

			var destino: Vector2 = _efeito_lenco.posicao_gola()
			var t: float = smoothstep(0.0, 1.0, p)
			_ponto_luz = _ponto_inicial.lerp(destino, t)

		2:

			_ponto_luz = _efeito_lenco.posicao_gola()

	queue_redraw()

	if p >= 1.0:

		_etapa += 1
		_tempo_etapa = 0.0

		if _etapa == 1:

			visual.hide()

		if _etapa == 5:

			_terminar_animacao()

# Desenhar o efeito
# ---------------------
# Desenha os elementos visuais com o estado atual.
func _draw() -> void:

	if _consumido:

		return

	if not _executando or _etapa == 0:

		var centro: Vector2 = visual.position
		var contracao: float = 0.0

		if _executando:

			contracao = smoothstep(0.0, 1.0, clampf(_tempo_etapa / maxf(duracao_contracao, 0.01), 0.0, 1.0))

		var raio_original: float = tamanho_simbolo * 0.5 * (1.0 + _brilho_atual * 0.25)
		var raio: float = lerpf(raio_original, tamanho_bolinha, contracao)

		for i in range(5, 0, -1):

			draw_circle(centro, raio * float(i) / 2.0, Color(cor_luz, _brilho_atual * lerpf(0.015, 0.06, contracao)))

		if textura_simbolo == null:

			var r: float = tamanho_simbolo * 0.35 * lerpf(1.0, 0.05, contracao)
			draw_polyline(PackedVector2Array([centro + Vector2(0, -r), centro + Vector2(r * 0.6, 0), centro + Vector2(0, r), centro + Vector2(-r * 0.6, 0), centro + Vector2(0, -r)]), cor_luz, 2.0, true)

		if _executando:

			_desenhar_bolinha(centro, tamanho_bolinha * contracao)

	elif _etapa == 1:

		_desenhar_bolinha(to_local(_ponto_luz), tamanho_bolinha)

	elif _etapa == 2:

		var p: float = clampf(_tempo_etapa / maxf(duracao_absorcao, 0.01), 0.0, 1.0)
		_desenhar_bolinha(to_local(_ponto_luz), tamanho_bolinha * (1.0 - smoothstep(0, 1, p)))

# Desenhar bolinha
# ---------------------
# Desenha bolinha.
func _desenhar_bolinha(posicao: Vector2, raio: float) -> void:

	if raio <= 0.01:

		return

	for i in range(5, 0, -1):

		draw_circle(posicao, raio * float(i) / 2.0, Color(cor_luz, 0.07))

	draw_circle(posicao, raio * 0.3, cor_luz.lightened(0.6))

# Terminar animação
# ---------------------
# Finaliza animação.
func _terminar_animacao() -> void:

	_efeito_lenco.finalizar()

	if not bool(_gestor.call("solicitar_desbloqueio", StringName(habilidade))):

		_cancelar()
		return

	_consumido = true
	habilidade_habilitada.emit(StringName(habilidade))
	queue_redraw()

	if not bool(ajuda.call("abrir", false)):

		_ao_fechar_ajuda()

# Ao fechar ajuda
# ---------------------
# Trata o evento: fechar ajuda.
func _ao_fechar_ajuda() -> void:

	if not _executando:

		return

	_executando = false

	if is_instance_valid(_jogador) and _jogador.has_method("limpar_comandos"):

		_jogador.call("limpar_comandos")

	_restaurar_pausa()
	set_process(false)

# Cancelar
# ---------------------
# Cancela a rotina deste componente.
func _cancelar() -> void:

	_efeito_lenco.finalizar()
	_executando = false
	visual.scale = _escala_inicial
	visual.modulate.a = 1.0
	visual.show()
	_restaurar_pausa()
	queue_redraw()

# Restaurar pausa
# ---------------------
# Restaura pausa.
func _restaurar_pausa() -> void:

	if _pausa_propria:

		get_tree().paused = false
		_pausa_propria = false

	process_mode = _modo_anterior

# Finalizar o nó
# ---------------------
# Libera ou restaura o estado ao sair da cena.
func _exit_tree() -> void:

	_efeito_lenco.finalizar()

	if _pausa_propria:

		get_tree().paused = false
