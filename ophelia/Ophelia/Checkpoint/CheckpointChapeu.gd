extends Node2D
## R coloca o chapéu no chão; R novamente chama o ícone até a Ophelia.
## Sem chapéu na cabeça, morrer usa o marcador; com chapéu, usa início da fase.
const CENA_MARCADOR = preload("res://Ophelia/Checkpoint/MarcadorChapeu.tscn")
const PARTICULAS_CHAPEU = preload("res://Ophelia/Checkpoint/ParticulasChapeu.gd")
@export_group("Chapéu / Checkpoint")
@export var acao_checkpoint: StringName = &"ControleCheckpoint"
@export_flags_2d_physics var mascara_chao: int = 1
@export_range(20.0, 200.0, 1.0) var alcance_achar_chao: float = 135.0
@export_range(0.4, 4.0, 0.05) var tempo_materializacao: float = 1.55
@export var som_chamada: AudioStream = preload("res://Ophelia/Checkpoint/SomChamadaChapeu.wav")
@export var volume_chamada_db: float = 0.0
var _corpo: CharacterBody2D
var _marcador: Node2D
var _posicao_checkpoint: Vector2
var _usou_checkpoint: bool = false
var _reconstruindo: float = -1.0
var _colocar_pendente: bool = false
@export_group("Partículas como as flores")
@export_range(100, 4000, 25) var quantidade_particulas_materializacao: int = 3200
@export_range(10.0, 220.0, 5.0) var velocidade_dispersao: float = 95.0
@export_range(0.05, 1.0, 0.05) var tempo_desaparecer: float = 0.65
@export_range(0.03, 0.5, 0.01) var escala_chapeu: float = 0.105
const TEXTURA_CHAPEU_LATERAL = preload("res://Ophelia/Checkpoint/ChapeuLateral.svg")
const TEXTURA_CHAPEU_FRONTAL = preload("res://Ophelia/Checkpoint/ChapeuFrontal.svg")
var _efeito_materializacao: Node2D
var _id_materializacao: int = 0

func _ready() -> void:
	_corpo = get_parent() as CharacterBody2D
	call_deferred("_iniciar_com_chapeu")

func _iniciar_com_chapeu() -> void:
	if is_instance_valid(_corpo) and _corpo.has_method("definir_chapeu"):
		_corpo.call("definir_chapeu", true)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return
	if not InputMap.has_action(acao_checkpoint) or not event.is_action_pressed(acao_checkpoint):
		return
	if not is_instance_valid(_corpo) or _corpo.process_mode == Node.PROCESS_MODE_DISABLED:
		return
	var vida := _corpo.get_node_or_null("Vitalidade")
	if vida != null and vida.has_method("esta_viva") and not vida.call("esta_viva"):
		return
	if is_instance_valid(_marcador):
		if not _marcador.call("esta_retornando"):
			chamar_chapeu()
			get_viewport().set_input_as_handled()
	elif _corpo.is_on_floor() and bool(_corpo.get("usando_chapeu")):
		_colocar_pendente = true
		get_viewport().set_input_as_handled()

func _physics_process(_delta: float) -> void:
	# A consulta física do chão deve acontecer dentro do passo de física.
	if _colocar_pendente:
		_colocar_pendente = false
		colocar_checkpoint()

func _achar_chao() -> Dictionary:
	var origem := _corpo.global_position - Vector2(0, 8)
	var destino := origem + Vector2(0, alcance_achar_chao)
	var consulta := PhysicsRayQueryParameters2D.create(origem, destino, mascara_chao, [_corpo.get_rid()])
	return _corpo.get_world_2d().direct_space_state.intersect_ray(consulta)

func colocar_checkpoint() -> bool:
	if not is_instance_valid(_corpo) or not _corpo.is_on_floor() or is_instance_valid(_marcador):
		return false
	var chao := _achar_chao()
	if chao.is_empty():
		return false
	var normal: Vector2 = chao["normal"]
	if normal.y > -0.55:
		return false
	var mundo := get_tree().current_scene
	if mundo == null:
		return false
	_posicao_checkpoint = _corpo.global_position
	_marcador = CENA_MARCADOR.instantiate()
	mundo.add_child(_marcador)
	_marcador.global_position = chao["position"]
	# O chapéu e seus círculos são desenhados acima da personagem.
	_marcador.z_as_relative = false
	_marcador.z_index = mini(_corpo.z_index + 10, 4096)
	_marcador.call("configurar", _corpo.global_position + Vector2(0, -40), bool(_corpo.get("olhando_esquerda")))
	_marcador.connect("recolhido", _ao_recolher)
	_iniciar_particulas(false)
	_corpo.call("definir_chapeu", false)
	_avisar_save()
	return true

func chamar_chapeu() -> void:
	if is_instance_valid(_marcador):
		_marcador.call("iniciar_retorno", _corpo)
		if som_chamada != null:
			var audio := AudioStreamPlayer2D.new()
			audio.stream = som_chamada
			audio.volume_db = volume_chamada_db
			add_child(audio)
			audio.finished.connect(audio.queue_free)
			audio.play()

func _ao_recolher() -> void:
	# Capturar a posição real e a escala do mini chapéu ANTES de retirá-lo.
	# A formação começa exatamente nesse ponto, evitando saltos visuais.
	var posicao_icone := _corpo.global_position + Vector2(0, -40)
	var escala_icone: float = 0.25
	var espelhado: bool = false
	if is_instance_valid(_marcador):
		var visual := _marcador.get_node_or_null("Sprite2D") as Sprite2D
		if is_instance_valid(visual):
			posicao_icone = visual.global_position
			escala_icone = absf(visual.global_scale.x)
			espelhado = visual.flip_h
		_marcador.queue_free()
		_marcador = null
	_reconstruindo = 0.0
	_iniciar_particulas(true, posicao_icone, escala_icone, espelhado)
	_avisar_save()

func consumir_checkpoint(posicao_padrao: Vector2) -> Vector2:
	_usou_checkpoint = false
	if not is_instance_valid(_marcador):
		return posicao_padrao
	_usou_checkpoint = true
	var destino := _posicao_checkpoint
	_marcador.queue_free()
	_marcador = null
	return destino

func restaurar_chapeu() -> void:
	if not is_instance_valid(_corpo):
		return
	if _usou_checkpoint:
		_corpo.call("definir_chapeu", false)
		_iniciar_particulas(false)
		_reconstruindo = -1.0
		_usou_checkpoint = false
	else:
		_corpo.call("definir_chapeu", true)
	_avisar_save()

func exportar_estado_save() -> Dictionary:
	var estado := {"posto": bool(_corpo.get("usando_chapeu")) if is_instance_valid(_corpo) else true,
					"ativo": is_instance_valid(_marcador)}
	if is_instance_valid(_marcador):
		estado["checkpoint"] = [_posicao_checkpoint.x, _posicao_checkpoint.y]
		estado["marcador"] = [_marcador.global_position.x, _marcador.global_position.y]
		estado["espelhado"] = bool(_marcador.get("_espelhado"))
	return estado

func importar_estado_save(dados: Dictionary) -> void:
	if is_instance_valid(_marcador):
		_marcador.queue_free()
		_marcador = null
	if not is_instance_valid(_corpo):
		return
	var pos: Array = dados.get("checkpoint", [])
	var marca: Array = dados.get("marcador", [])
	if bool(dados.get("ativo", false)) and pos.size() == 2 and marca.size() == 2:
		_posicao_checkpoint = Vector2(float(pos[0]), float(pos[1]))
		var mundo := get_tree().current_scene
		if mundo != null:
			_marcador = CENA_MARCADOR.instantiate()
			mundo.add_child(_marcador)
			_marcador.global_position = Vector2(float(marca[0]), float(marca[1]))
			# O chapéu e seus círculos são desenhados acima da personagem.
			_marcador.z_as_relative = false
			_marcador.z_index = mini(_corpo.z_index + 10, 4096)
			_marcador.call("ativar_instantaneo", bool(dados.get("espelhado", false)))
			_marcador.connect("recolhido", _ao_recolher)
			_corpo.call("definir_chapeu", false)
			return
	_corpo.call("definir_chapeu", true)

func _avisar_save() -> void:
	var controle := _corpo.get_node_or_null("PersistenciaOphelia") if is_instance_valid(_corpo) else null
	if controle != null and controle.has_method("_solicitar_salvar"):
		controle.call("_solicitar_salvar")

# Reprodução da silhueta correta: frente usa o SVG frontal, laterais usam
# o SVG de perfil espelhado quando necessário. A referência é o sprite real,
# e não uma posição fixa em relação ao corpo.
func _chapeu_frontal() -> bool:
	if not is_instance_valid(_corpo) or not is_instance_valid(_corpo.sprite):
		return false
	var animacao: String = String(_corpo.sprite.animation)
	for prefixo in ["Irritada", "Agradecer", "Esperar", "Transicao"]:
		if animacao.begins_with(prefixo):
			return true
	return false

func _iniciar_particulas(formando: bool, posicao_icone: Vector2 = Vector2.INF, escala_icone: float = 0.25, espelhado_icone: bool = false) -> void:
	if not is_instance_valid(_corpo) or not is_instance_valid(_corpo.sprite):
		return
	_id_materializacao += 1
	var id_atual: int = _id_materializacao
	if is_instance_valid(_efeito_materializacao):
		_efeito_materializacao.queue_free()
	var efeito: Node2D = PARTICULAS_CHAPEU.new() as Node2D
	var mundo := get_tree().current_scene
	if mundo == null:
		return
	mundo.add_child(efeito)
	# Partículas da reconstrução também devem aparecer à frente da Ophelia.
	efeito.z_as_relative = false
	efeito.z_index = mini(_corpo.z_index + 11, 4096)
	var frontal: bool = _chapeu_frontal()
	var textura: Texture2D = TEXTURA_CHAPEU_FRONTAL if frontal else TEXTURA_CHAPEU_LATERAL
	var sprite: AnimatedSprite2D = _corpo.sprite
	# SVGs de referência de 600x600, iguais às sprites de Ophelia.
	# A posição e a escala são as mesmas de SpritePersonagem.
	efeito.call("iniciar", textura, sprite.global_position, absf(sprite.global_scale.x),
		bool(_corpo.get("olhando_esquerda")) and not frontal, formando,
		tempo_materializacao if formando else tempo_desaparecer,
		velocidade_dispersao, quantidade_particulas_materializacao,
		sprite if formando else null,
		preload("res://Ophelia/Checkpoint/ChapeuIcone.svg") if formando else null,
		posicao_icone if formando and posicao_icone != Vector2.INF else sprite.global_position,
		escala_icone, espelhado_icone)
	_efeito_materializacao = efeito
	if formando:
		efeito.connect("concluido", Callable(self, "_ao_materializacao_concluida").bind(id_atual))

func _ao_materializacao_concluida(id_atual: int) -> void:
	if id_atual != _id_materializacao or _reconstruindo < 0.0:
		return
	_reconstruindo = -1.0
	if is_instance_valid(_corpo):
		_corpo.call("definir_chapeu", true)
	_avisar_save()
