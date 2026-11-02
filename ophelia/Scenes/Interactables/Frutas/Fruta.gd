class_name FrutaOphelia
extends RigidBody2D

signal coletada(estacao: StringName)
signal regenerada()

enum Estado { PRESA, CAIDA, COLETADA }

@export_group("Sons")
@export var som_coleta: AudioStream
@export var som_impacto: AudioStream
@export var volume_sfx_db: float = -6.0
@export var barramento_sfx: StringName = &"SFX"
@export_range(0.0, 300.0, 1.0) var velocidade_minima_som: float = 25.0

@export_group("Rastro de queda")
@export var usar_cor_catalogo: bool = true
@export var cor_rastro: Color = Color(1, 1, 1, 0.35)
@export_range(2, 20, 1) var pontos_rastro: int = 16
@export_range(1.0, 12.0, 0.5) var largura_rastro: float = 6.0

@export_group("Fruta")
@export var ativa: bool = true
@export var estacao: CatalogoFrutasOphelia.Estacao = CatalogoFrutasOphelia.Estacao.PRIMAVERA
@export var catalogo: CatalogoFrutasOphelia = preload("CatalogoFrutas.tres")
@export var textura_personalizada: Texture2D
@export var tamanho_imagem: Vector2 = Vector2(24, 24)
@export_group("Colisão da fruta")
@export var ajustar_colisao_imagem: bool = true
@export_range(0.0, 4.0, 0.25) var margem_colisao: float = 0.0
@export_group("Coleta e regeneração")
@export_range(1.0, 600.0, 1.0) var segundos_regeneracao: float = 10.0 # Produção: 180.
@export var acao_interagir: StringName = &"ControleInteragir"
@export_range(10.0, 160.0, 1.0) var distancia_coleta: float = 65.0

@onready var imagem: Sprite2D = $Imagem
@onready var proximidade: Area2D = $Proximidade

var _coleta_em_andamento: bool = false
var estado: Estado = Estado.PRESA
var _jogador: CharacterBody2D
var _suporte: Node2D
var _transformacao_inicial: Transform2D
var _galho: Node2D
var _restante: float = -1.0
var _regeneracao_pendente: bool = false
var _tempo_impacto: float = 0.0
var _velocidade_antes_impacto: float = 0.0
var _tempo_rastro: float = 0.0
var _pontos_rastro := PackedVector2Array()
@onready var _rastro: Line2D = get_node_or_null("Rastro") as Line2D

# Preparar a fruta
# ---------------------
# Guarda a posição de nascimento e configura a proximidade e a imagem.
func _ready() -> void:

	continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	contact_monitor = true
	max_contacts_reported = 4
	body_entered.connect(_ao_bater_no_chao)
	add_to_group("coletaveis_ophelia")
	_suporte = get_parent() as Node2D
	_transformacao_inicial = transform
	freeze = true
	collision_layer = CamadasFisica.COLETAVEIS
	collision_mask = 0
	proximidade.collision_layer = 0
	proximidade.collision_mask = CamadasFisica.JOGADOR
	(proximidade.get_node("Forma").shape as CircleShape2D).radius = distancia_coleta
	proximidade.body_entered.connect(_ao_aproximar)
	proximidade.body_exited.connect(_ao_afastar)
	set_process(false)
	set_physics_process(false)
	_atualizar_imagem()
	_configurar_rastro()

	if not ativa:

		estado = Estado.COLETADA
		collision_layer = 0
		proximidade.set_deferred("monitoring", false)
		hide()
		set_process(false)

# Vincular a fruta ao galho
# ---------------------
# Aplica a estação e o catálogo escolhidos na instância da planta.
func vincular(galho: Node2D, nova_estacao: int, novo_catalogo: CatalogoFrutasOphelia) -> void:

	_galho = galho
	estacao = nova_estacao as CatalogoFrutasOphelia.Estacao
	catalogo = novo_catalogo
	_atualizar_imagem()
	_configurar_rastro()

# Atualizar a imagem
# ---------------------
# Mantém a proporção da textura e permite uma variante por fruta.
func _atualizar_imagem() -> void:

	if imagem == null:

		return

	imagem.texture = textura_personalizada if textura_personalizada != null else (catalogo.obter_textura(estacao) if catalogo != null else null)

	# A imagem permanece original; os círculos são desenhados atrás dela.
	imagem.material = null

	if imagem.texture != null:

		var tamanho: Vector2 = imagem.texture.get_size()
		imagem.scale = Vector2.ONE * minf(tamanho_imagem.x / maxf(tamanho.x, 1), tamanho_imagem.y / maxf(tamanho.y, 1))

	_ajustar_colisao()


# Reconhecer o jogador próximo
# ---------------------
# Libera a indicação de coleta somente para Ophelia.
func _ao_aproximar(corpo: Node2D) -> void:

	if corpo is CharacterBody2D and corpo.is_in_group("jogador"):

		_jogador = corpo

# Encerrar a proximidade
# ---------------------
# Oculta a indicação ao deixar a área da fruta.
func _ao_afastar(corpo: Node2D) -> void:

	if corpo == _jogador:

		_jogador = null


# Verificar a coleta
# ---------------------
# Exige fruta disponível, jogador vivo e distância de interação.
func pode_interagir(jogador: CharacterBody2D) -> bool:

	if _coleta_em_andamento or not ativa or estado == Estado.COLETADA or not is_instance_valid(jogador) or jogador != _jogador:

		return false

	var vitalidade: Node = jogador.get_node_or_null("Vitalidade")
	return vitalidade != null and bool(vitalidade.call("esta_viva")) and global_position.distance_to(jogador.global_position) <= distancia_coleta + 30.0


# Coletar a fruta
# ---------------------
# Empilha no estoque da estação sem curar nem consumir a fruta.
func interagir(jogador: CharacterBody2D) -> bool:

	if not pode_interagir(jogador):

		return false

	if estado == Estado.CAIDA:

		if not jogador.has_method("animar_coleta_chao"):

			return false

		_coleta_em_andamento = true

		if not bool(jogador.call("animar_coleta_chao", _confirmar_coleta.bind(jogador))):

			_coleta_em_andamento = false
			return false

		return true

	return _guardar_fruta(jogador)

# Confirmar no frame de contato
# ---------------------
# Só concede a fruta e toca o som quando a animação chega ao terceiro frame.
func _confirmar_coleta(confirmada: bool, jogador: CharacterBody2D) -> void:

	_coleta_em_andamento = false

	if confirmada and is_instance_valid(jogador) and pode_interagir(jogador):

		_guardar_fruta(jogador)

# Guardar a fruta no estoque
# ---------------------
# Finaliza a coleta real; frutas presas ao galho usam este caminho imediatamente.
func _guardar_fruta(jogador: CharacterBody2D) -> bool:

	var vitalidade: Node = jogador.get_node_or_null("Vitalidade")
	var id: StringName = CatalogoFrutasOphelia.identificar(estacao)

	if vitalidade == null or not vitalidade.has_method("adicionar_fruta") or not bool(vitalidade.call("adicionar_fruta", id, 1)):

		return false

	estado = Estado.COLETADA
	$Sombra.ocultar()
	set_physics_process(false)
	_tocar_som("SomColeta", som_coleta)
	_limpar_rastro()
	_iniciar_contagem()
	hide()
	set_deferred("freeze", true)
	set_deferred("collision_mask", 0)
	set_deferred("collision_layer", 0)
	coletada.emit(id)
	return true

# Derrubar a fruta
# ---------------------
# Libera o corpo físico e inicia seu tempo individual de retorno.
func soltar(impulso: Vector2) -> void:

	if estado != Estado.PRESA:

		return

	var posicao: Vector2 = global_position
	top_level = true
	global_position = posicao
	estado = Estado.CAIDA
	$Sombra.ativar()
	set_physics_process(true)
	collision_layer = CamadasFisica.COLETAVEIS
	collision_mask = CamadasFisica.SOLIDOS | CamadasFisica.COLETAVEIS
	freeze = false
	sleeping = false
	linear_velocity = impulso
	angular_velocity = randf_range(-2.0, 2.0)
	_iniciar_contagem()

# Iniciar o retorno individual
# ---------------------
# Coletar uma fruta caída não reinicia o tempo que já estava correndo.
func _iniciar_contagem() -> void:

	if _restante < 0.0:

		_restante = segundos_regeneracao
		set_process(true)

# Atualizar o retorno e a indicação
# ---------------------
# Conta o retorno individual e atualiza o rastro durante a queda.
func _process(delta: float) -> void:

	_tempo_impacto = maxf(0.0, _tempo_impacto - delta)
	_atualizar_rastro(delta)


	if _restante >= 0.0:

		_restante = maxf(0.0, _restante - delta)

		if is_zero_approx(_restante):

			tentar_regenerar()

# Solicitar o renascimento
# ---------------------
# Espera o caule existir para não fazer a fruta flutuar num galho cortado.
func tentar_regenerar() -> void:

	if _coleta_em_andamento or _regeneracao_pendente or _restante < 0.0 or _restante > 0.0:

		return

	_regeneracao_pendente = true

	if is_instance_valid(_galho) and _galho.has_method("solicitar_regeneracao"):

		_galho.call("solicitar_regeneracao", self)

	else:

		call_deferred("_regenerar")

# Recolocar a fruta no nascimento
# ---------------------
# Restaura o mesmo corpo sem duplicar frutas ou perder a posição manual.
func _regenerar() -> void:

	_regeneracao_pendente = false
	$Sombra.ocultar()

	if not is_instance_valid(_suporte):

		queue_free()
		return

	freeze = true
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	collision_mask = 0
	collision_layer = CamadasFisica.COLETAVEIS
	top_level = false
	transform = _transformacao_inicial
	_limpar_rastro()
	estado = Estado.PRESA
	_restante = -1.0
	show()
	set_process(false)
	set_physics_process(false)
	regenerada.emit()

# Guardar a posição escolhida
# ---------------------
# Atualiza o nascimento para preservar o offset configurado nesta instância.
func definir_nascimento(posicao: Vector2) -> void:

	ativa = true
	estado = Estado.PRESA
	freeze = true
	collision_layer = CamadasFisica.COLETAVEIS
	position = posicao
	_transformacao_inicial = transform
	proximidade.set_deferred("monitoring", true)
	show()

# Desativar um slot excedente
# ---------------------
# Oculta frutas além da quantidade escolhida sem criar unidades extras.
func desativar() -> void:

	ativa = false
	$Sombra.ocultar()
	estado = Estado.COLETADA
	freeze = true
	collision_layer = 0
	collision_mask = 0
	proximidade.set_deferred("monitoring", false)
	hide()
	set_process(false)

# Guardar a velocidade da queda
# ---------------------
# Usa a velocidade anterior ao contato para filtrar impactos fracos.
func _physics_process(_delta: float) -> void:

	if estado == Estado.CAIDA:

		_velocidade_antes_impacto = maxf(_velocidade_antes_impacto * 0.8, linear_velocity.length())

# Reproduzir o impacto no chão
# ---------------------
# Toca somente em superfícies sólidas e limita sons repetidos de pequenos saltos.
func _ao_bater_no_chao(corpo: Node) -> void:

	if estado != Estado.CAIDA or _tempo_impacto > 0.0 or _velocidade_antes_impacto < velocidade_minima_som:

		return

	if corpo is CollisionObject2D and (corpo.collision_layer & CamadasFisica.SOLIDOS) != 0:

		_tocar_som("SomImpacto", som_impacto)
		_tempo_impacto = 0.25
		_velocidade_antes_impacto = 0.0

# Reproduzir um som configurado
# ---------------------
# Mantém os campos opcionais, sem exigir um arquivo de áudio para funcionar.
func _tocar_som(caminho: String, som: AudioStream) -> void:

	var audio: AudioStreamPlayer2D = get_node_or_null(caminho) as AudioStreamPlayer2D

	if audio != null and som != null:

		audio.stream = som
		audio.bus = barramento_sfx if AudioServer.get_bus_index(barramento_sfx) >= 0 else &"Master"
		audio.volume_db = volume_sfx_db
		audio.play()

# Configurar o rastro colorido
# ---------------------
# Escolhe a cor da estação ou uma cor personalizada para esta fruta.
func _configurar_rastro() -> void:

	if _rastro == null:

		return

	_rastro.top_level = true
	_rastro.global_transform = Transform2D.IDENTITY
	_rastro.width = largura_rastro
	var cor: Color = catalogo.obter_cor(estacao) if usar_cor_catalogo and catalogo != null else cor_rastro
	var gradiente := Gradient.new()
	gradiente.colors = PackedColorArray([Color(cor, 0.0), Color(cor, cor.a * 0.3)])
	_rastro.gradient = gradiente
	_rastro.hide()

# Atualizar o rastro da queda
# ---------------------
# Deixa uma trilha curta que se desfaz quando a fruta para.
func _atualizar_rastro(delta: float) -> void:

	if _rastro == null or estado != Estado.CAIDA:

		return

	_tempo_rastro += delta

	if linear_velocity.length() > 8.0:

		if _pontos_rastro.is_empty() or _pontos_rastro[-1].distance_to(global_position) > 1.5:

			_pontos_rastro.append(global_position)

		while _pontos_rastro.size() > pontos_rastro:

			_pontos_rastro.remove_at(0)

	elif _tempo_rastro > 0.04 and not _pontos_rastro.is_empty():

		_pontos_rastro.remove_at(0)

	if _tempo_rastro > 0.04:

		_tempo_rastro = 0.0

	_rastro.points = _pontos_rastro
	_rastro.visible = _pontos_rastro.size() > 1

# Limpar a trilha antiga
# ---------------------
# Impede o rastro de conectar a queda anterior ao novo nascimento.
func _limpar_rastro() -> void:

	_pontos_rastro.clear()

	if _rastro != null:

		_rastro.clear_points()
		_rastro.hide()


# Ajustar o corpo à imagem
# ---------------------
# Mede a parte visível da textura para impedir que a fruta pareça afundada no chão.
func _ajustar_colisao() -> void:

	if not ajustar_colisao_imagem or imagem.texture == null:

		return

	var pixels: Image = imagem.texture.get_image()

	if pixels == null:

		return

	if pixels.is_compressed() and pixels.decompress() != OK:

		return

	var limites: Rect2i = pixels.get_used_rect()

	if limites.size.x <= 0 or limites.size.y <= 0:

		return

	var origem: Vector2 = imagem.offset

	if imagem.centered:

		origem -= imagem.texture.get_size() * 0.5

	var tamanho: Vector2 = Vector2(limites.size) * imagem.scale.abs() + Vector2.ONE * margem_colisao * 2.0
	var capsula := CapsuleShape2D.new()
	capsula.radius = maxf(1.0, minf(tamanho.x, tamanho.y) * 0.5)
	capsula.height = maxf(maxf(tamanho.x, tamanho.y), capsula.radius * 2.0)
	var forma: CollisionShape2D = $FormaCorpo
	forma.position = imagem.position + (origem + Vector2(limites.position) + Vector2(limites.size) * 0.5) * imagem.scale
	forma.rotation = imagem.rotation + (PI * 0.5 if tamanho.x > tamanho.y else 0.0)
	forma.shape = capsula
