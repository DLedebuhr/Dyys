class_name OpheliaProjetilLenco
extends Node2D
# Projétil independente: voa, espera no impacto/alcance e retorna à gola.
# A personagem pode antecipar o retorno tocando no projétil parado.

signal acertou(alvo: Node)               # Bateu em um alvo
signal bateu_no_cenario(onde: Vector2)   # Bateu em parede, chão ou objeto
signal apoio_desativado()
signal voltou()                          # Chegou de volta na gola

enum Fase { IDA, ESPERA, VOLTA }

var dano: int = 5
var mascara_dano: int = 1
var _dano_aplicado: bool = false

var tempo_espera: float = 5.0
var _tempo_parado: float = 0.0
var _coleta: Area2D = null

var velocidade_ida: float = 700.0
var velocidade_volta: float = 950.0
var alcance: float = 420.0
var raio: float = 10.0
var cor: Color = Color(0.7, 0.7, 1.0)
var textura_ponta: Texture2D = null
var tamanho_ponta: Vector2 = Vector2(24, 24)
var destino_volta: Callable = Callable()   # Devolve a posição da gola (no mundo)
var mascara_cenario: int = 1
var excluir: Array[RID] = []               # Corpos que o raio do cenário ignora (a personagem)
var ignorar: Node = null                   # Não conta como acerto

var _lancado: bool = false
var _fase: int = Fase.IDA
var _dir: Vector2 = Vector2.RIGHT
var _angulo: float = 0.0
var _percorrido: float = 0.0
var _t: float = 0.0
var _t_volta: float = 0.0
var _trilha: Array[Vector2] = []
var _area: Area2D = null
var _brilho: Node2D = null       # Camada de luz (soma luz em vez de cobrir)
var _faiscas: CPUParticles2D = null
var _mat: CanvasItemMaterial = null
var _tex: Texture2D = null

func _ready() -> void:
	# Um nó presente na cena fica inativo até receber lancar().
	hide()
	set_physics_process(false)
	_mat = OpheliaEfeitosComuns.material_aditivo()
	_tex = _criar_textura()

	_brilho = Node2D.new()
	_brilho.material = _criar_material_eco()
	_brilho.draw.connect(_desenhar_brilho)
	add_child(_brilho)

	_faiscas = _criar_faiscas()
	add_child(_faiscas)
	_criar_area()
	_criar_coleta()

# Chame depois de adicionar à cena
func lancar(origem: Vector2, direcao: Vector2) -> void:
	global_position = origem
	_lancado = true
	_fase = Fase.IDA
	_percorrido = 0.0
	_tempo_parado = 0.0
	_t_volta = 0.0
	_dano_aplicado = false
	show()
	set_physics_process(true)
	_area.set_deferred("monitoring", true)
	_area.set_deferred("monitorable", true)
	_coleta.set_deferred("monitoring", true)
	_faiscas.emitting = true
	_dir = direcao.normalized() if direcao.length() > 0.01 else Vector2.RIGHT
	_angulo = _dir.angle()
	_trilha.clear()
	_trilha.append(origem)

func _physics_process(delta: float) -> void:
	if not _lancado:
		return
	_t += delta
	if _fase == Fase.IDA:
		_passo_ida(delta)
	elif _fase == Fase.ESPERA:
		_tempo_parado += delta
		if _personagem_encostou() or _tempo_parado >= tempo_espera:
			_comecar_volta()
	else:
		_passo_volta(delta)

	_trilha.append(global_position)
	while _trilha.size() > 14:
		_trilha.pop_front()

func _process(_delta: float) -> void:
	if not _lancado:
		return
	queue_redraw()
	if _brilho:
		_brilho.queue_redraw()

func _passo_ida(delta: float) -> void:
	var passo := minf(velocidade_ida * delta, alcance - _percorrido)
	var de := global_position
	var para := de + _dir * (passo + raio)   # Olha um pouco à frente do brilho
	var consulta := PhysicsRayQueryParameters2D.create(de, para, mascara_cenario)
	consulta.exclude = excluir
	var r := get_world_2d().direct_space_state.intersect_ray(consulta)
	if not r.is_empty():
		global_position = r["position"] - _dir * minf(raio * 0.5, passo)
		_comecar_espera()
		var alvo = r["collider"]
		_aplicar_dano(alvo)
		if alvo is CharacterBody2D or alvo is RigidBody2D:
			if alvo != ignorar:
				acertou.emit(alvo)     # Personagem ou objeto móvel
		else:
			bateu_no_cenario.emit(global_position)   # Parede, chão, plataforma
		return

	global_position += _dir * passo
	_percorrido += passo
	if _percorrido >= alcance - 0.01:
		_comecar_espera()

func _passo_volta(delta: float) -> void:
	var alvo := global_position
	if destino_volta.is_valid():
		alvo = destino_volta.call()
	_t_volta += delta
	var v := alvo - global_position
	var d := v.length()
	# Sai devagar do ponto de virada e acelera
	var passo := velocidade_volta * lerpf(0.35, 1.0, clampf(_t_volta / 0.18, 0.0, 1.0)) * delta
	_angulo = lerp_angle(_angulo, v.angle(), 0.35)
	if d <= passo + 10.0:
		voltou.emit()
		queue_free()
		return
	global_position += v / d * passo

func _criar_coleta() -> void:
	_coleta = Area2D.new()
	_coleta.name = "AreaColeta"
	_coleta.collision_layer = 0
	_coleta.collision_mask = ignorar.collision_layer if ignorar is CollisionObject2D else 0
	_coleta.monitoring = false
	_coleta.monitorable = false
	var forma := CollisionShape2D.new()
	var circulo := CircleShape2D.new()
	circulo.radius = raio * 1.5
	forma.shape = circulo
	_coleta.add_child(forma)
	add_child(_coleta)

func _personagem_encostou() -> bool:
	return is_instance_valid(ignorar) and _coleta != null and _coleta.overlaps_body(ignorar)

func _comecar_espera() -> void:
	if _fase != Fase.IDA:
		return
	_fase = Fase.ESPERA
	_tempo_parado = 0.0
	# O projétil parado não continua causando dano.
	if _area:
		_area.set_deferred("monitoring", false)
		_area.set_deferred("monitorable", false)

func _comecar_volta() -> void:
	if _fase == Fase.VOLTA:
		return
	_fase = Fase.VOLTA
	apoio_desativado.emit()
	_t_volta = 0.0
	if _area:
		_area.set_deferred("monitoring", false)
		_area.set_deferred("monitorable", false)

func _ao_entrar(alvo: Node) -> void:
	if _fase != Fase.IDA or alvo == ignorar or (is_instance_valid(ignorar) and ignorar.is_ancestor_of(alvo)):
		return
	_comecar_espera()
	_aplicar_dano(alvo)
	acertou.emit(alvo)

# Área de dano independente do ataque normal.
func _criar_area() -> void:
	_area = Area2D.new()
	_area.name = "AreaProjetil"
	_area.collision_layer = 0
	_area.collision_mask = mascara_dano
	_area.set_meta("dano", dano)
	var forma := CollisionShape2D.new()
	var circulo := CircleShape2D.new()
	circulo.radius = raio * 1.5
	forma.shape = circulo
	_area.add_child(forma)
	_area.monitoring = false
	_area.monitorable = false
	add_child(_area)
	_area.body_entered.connect(_ao_entrar)
	_area.area_entered.connect(_ao_entrar)

# --- DESENHO ---
# A ponta (textura da fita) por cima; o brilho e o rastro somam luz na camada de cima
func _draw() -> void:
	if textura_ponta == null:
		var forma := PackedVector2Array([Vector2(13, 0), Vector2(0, -5), Vector2(-9, 0), Vector2(0, 5)])
		var girada := PackedVector2Array()
		for p in forma:
			girada.append(p.rotated(_angulo))
		draw_colored_polygon(girada, cor)
		return
	var tam := tamanho_ponta * 1.3
	draw_set_transform(Vector2.ZERO, _angulo)
	draw_texture_rect(textura_ponta, Rect2(-tam * 0.5, tam), false)
	draw_set_transform(Vector2.ZERO, 0.0)

func _desenhar_brilho() -> void:
	var claro := cor.lerp(Color.WHITE, 0.5)
	var pulso := 0.85 + 0.15 * sin(_t * 30.0)
	if _trilha.size() >= 2:
		var pontos := PackedVector2Array()
		var cores_halo := PackedColorArray()
		var cores_miolo := PackedColorArray()
		for i in _trilha.size():
			var f := float(i) / float(_trilha.size() - 1)
			pontos.append(to_local(_trilha[i]))
			cores_halo.append(Color(cor, 0.5 * f))
			cores_miolo.append(Color(claro, 0.9 * f))
		_brilho.draw_polyline_colors(pontos, cores_halo, raio * 1.8, true)
		_brilho.draw_polyline_colors(pontos, cores_miolo, raio * 0.6, true)
	_brilho.draw_set_transform(Vector2.ZERO, _angulo)
	# Cópias luminosas da própria ponta: proporção, recortes e rotação iguais.
	for i in range(3):
		var fase: float = fposmod(_t * 1.8 + float(i) / 3.0, 1.0)
		var escala: float = lerpf(1.08, 1.75, fase) * pulso
		var alfa: float = pow(1.0 - fase, 2.0) * 0.28
		_desenhar_eco_ponta(escala, Color(cor, alfa))
	_desenhar_eco_ponta(1.04, Color(claro, 0.45 * pulso))
	_brilho.draw_set_transform(Vector2.ZERO, 0.0)

func _desenhar_eco_ponta(escala: float, tinta: Color) -> void:
	if textura_ponta != null:
		var tamanho: Vector2 = tamanho_ponta * 1.3 * escala
		_brilho.draw_texture_rect(textura_ponta, Rect2(-tamanho * 0.5, tamanho), false, tinta)
	else:
		var forma := PackedVector2Array([Vector2(13, 0), Vector2(0, -5), Vector2(-9, 0), Vector2(0, 5)])
		for i in range(forma.size()):
			forma[i] *= escala
		_brilho.draw_colored_polygon(forma, tinta)

func _criar_material_eco() -> ShaderMaterial:
	# Usa só o alpha da textura, para iluminar a silhueta sem repetir sua cor escura.
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
render_mode blend_add, unshaded;
varying vec4 tinta;
void vertex() { tinta = COLOR; }
void fragment() {
 COLOR = vec4(tinta.rgb, texture(TEXTURE, UV).a * tinta.a);
}"""
	var material_eco := ShaderMaterial.new()
	material_eco.shader = shader
	return material_eco

func _criar_faiscas() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	OpheliaEfeitosComuns.configurar_emissor(p)
	p.texture = OpheliaEfeitosComuns.textura_cintilo()
	p.local_coords = false             # As faíscas ficam no mundo e formam a trilha
	p.emitting = false
	p.amount = 28
	p.lifetime = 0.35
	p.explosiveness = 0.0
	p.spread = 180.0
	p.initial_velocity_min = 10.0
	p.initial_velocity_max = 60.0
	p.gravity = Vector2.ZERO
	p.damping_min = 20.0
	p.damping_max = 50.0
	p.scale_amount_min = 0.3
	p.scale_amount_max = 0.8
	p.scale_amount_curve = OpheliaEfeitosComuns.curva_encolher()
	p.color = OpheliaEfeitosComuns.cor_particula()
	p.material = _mat
	return p

# Mancha redonda e macia: centro forte, borda transparente
func _criar_textura() -> Texture2D:
	return OpheliaEfeitosComuns.textura_radial(16)

func pode_servir_de_apoio() -> bool:
	return _lancado and _fase == Fase.ESPERA and not is_queued_for_deletion()


func _aplicar_dano(contato: Node) -> void:
	if _dano_aplicado:
		return
	var alvo: Node = OpheliaDano.encontrar_receptor(contato, ignorar)
	if alvo != null:
		_dano_aplicado = true
		OpheliaDano.aplicar(alvo, dano)
