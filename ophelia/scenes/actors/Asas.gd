extends AnimatedSprite2D

@export var jogador: CharacterBody2D                # Se vazio, usa o pai
@export var sprite_principal: AnimatedSprite2D      # Sprite do Player (se vazio, procura sozinho)
@export var posicao_local: Vector2 = Vector2.ZERO   # Deslocamento em relação ao sprite do Player (arte virada para a direita)
@export var igualar_escala_ao_principal: bool = false
@export var origem_pixels: Vector2 = Vector2.ZERO   # Ponto da imagem onde as asas nascem (relativo ao centro dela)
@export var alcance_px: float = 0.0                 # Distância da origem até a ponta. 0 = calcula sozinho
@export var animacao: StringName = &"planar"

@export_group("Aparecer / sumir")
@export var duracao_aparecer: float = 0.7
@export var duracao_sumir: float = 0.4
@export var suavidade: float = 0.3                  # Maciez da borda da revelação (0.05 a 0.5)
@export var angulo_fechada: float = 30.0            # Graus: quanto a asa começa fechada (negativo inverte o giro)
@export var escala_inicial: float = 0.6             # Tamanho no começo da abertura

@export_group("Brilho")
@export var cor_brilho: Color = Color(1.0, 0.9, 0.6)
@export var intensidade_brilho: float = 2.5         # Brilho na frente da revelação
@export var brilho_vivo: float = 0.3                # Brilho que percorre as asas enquanto planam (0 = desliga)
@export var brilhos_por_segundo: float = 120.0      # Faíscas durante a transição
@export var tamanho_brilho: float = 2.0             # Tamanho das faíscas (pixels)
@export var vida_brilho: float = 0.8                # Duração das faíscas (s)

@export_group("Movimento natural")
@export var balanco_graus: float = 3.0              # Quanto as asas balançam (0 = parado)
@export var movimento_velocidade: float = 1.0
@export var dobra_ponta_px: float = 3.5             # Quanto a ponta ondula (0 = desliga)

@export_group("Teste")
@export var testar_visivel: bool = false            # Mostra as asas sempre e repete o brilho a cada 1,5 s
@export var debug: bool = true

const SHADER := """
shader_type canvas_item;

uniform float progresso = 0.0;
uniform vec2 origem = vec2(0.0);
uniform float alcance = 40.0;
uniform float suavidade : hint_range(0.01, 1.0) = 0.3;
uniform vec4 cor_brilho : source_color = vec4(1.0, 0.9, 0.6, 1.0);
uniform float intensidade_brilho = 2.5;
uniform float brilho_geral = 0.0;
uniform float brilho_vivo = 0.3;
uniform float dobra_px = 3.5;
uniform float movimento_vel = 1.0;

varying vec2 pos_local;

void vertex() {
	pos_local = VERTEX;
}

void fragment() {
	float d = distance(pos_local, origem) / max(alcance, 0.001);

	// Dobra natural: a base fica firme e a ponta acompanha com atraso
	float peso = smoothstep(0.1, 1.0, d);
	float desloc_y = sin(TIME * movimento_vel * 2.0 - d * 3.5) * dobra_px * peso;
	vec4 base = texture(TEXTURE, UV - vec2(0.0, desloc_y) * TEXTURE_PIXEL_SIZE) * COLOR;

	// Revelação de dentro para fora
	float p = progresso * (1.0 + suavidade);
	float visivel = 1.0 - smoothstep(p - suavidade, p, d);

	// Brilho na frente da revelação
	float frente = 1.0 - smoothstep(0.0, suavidade, abs(d - (p - suavidade * 0.5)));
	float brilho = frente * sin(clamp(progresso, 0.0, 1.0) * PI);

	// Clarão depois de abrir + brilho que percorre as asas
	float onda = fract(TIME * 0.4);
	float vivo = (1.0 - smoothstep(0.0, 0.18, abs(d - onda * 1.3))) * brilho_vivo;
	float extra = (brilho_geral + vivo) * visivel;

	COLOR.rgb = base.rgb + cor_brilho.rgb * (brilho * intensidade_brilho + extra);
	COLOR.a = base.a * clamp(visivel + brilho, 0.0, 1.0);
}
"""

class Brilho:
	var pos: Vector2
	var vel: Vector2
	var vida: float
	var vida_max: float
	var tam: float
	var fase: float

var _mat: ShaderMaterial
var _progresso: float = 0.0
var _tween: Tween
var _tween_pulso: Tween
var _alvo_visivel: bool = false
var _transicionando: bool = false
var _escala_base: Vector2 = Vector2.ONE
var _alcance: float = 100.0
var _tempo: float = 0.0
var _tempo_teste: float = 0.0

var _brilhos: Node2D
var _lista: Array = []
var _pontos: Array[Vector2] = []
var _distancias: Array[float] = []
var _acumulo: float = 0.0

func _ready() -> void:
	if jogador == null:
		jogador = get_parent() as CharacterBody2D
	if jogador == null:
		push_warning("Asas: precisa ser filha direta do Player (CharacterBody2D).")
	elif not ("planando" in jogador):
		push_warning("Asas: o Player não tem a variável 'planando'.")

	if sprite_principal == null and jogador:
		sprite_principal = jogador.find_child("AnimatedSprite2D", true, false) as AnimatedSprite2D

	_escala_base = scale
	if igualar_escala_ao_principal and sprite_principal:
		_escala_base = sprite_principal.scale
	_escala_base.x = absf(_escala_base.x)

	show_behind_parent = false
	if sprite_principal:
		centered = sprite_principal.centered
		offset = sprite_principal.offset

	if sprite_frames == null:
		push_warning("Asas: sem SpriteFrames. Crie um no Inspetor e coloque a imagem.")
	elif not sprite_frames.has_animation(animacao):
		push_warning("Asas: não existe a animação '%s'. Renomeie a 'default' ou mude o campo 'animacao'." % animacao)

	_alcance = alcance_px if alcance_px > 0.0 else _calcular_alcance()

	_mat = ShaderMaterial.new()
	_mat.shader = Shader.new()
	_mat.shader.code = SHADER
	_mat.set_shader_parameter("origem", origem_pixels)
	_mat.set_shader_parameter("alcance", _alcance)
	_mat.set_shader_parameter("suavidade", suavidade)
	_mat.set_shader_parameter("cor_brilho", cor_brilho)
	_mat.set_shader_parameter("intensidade_brilho", intensidade_brilho)
	_mat.set_shader_parameter("brilho_vivo", brilho_vivo)
	_mat.set_shader_parameter("dobra_px", dobra_ponta_px)
	_mat.set_shader_parameter("movimento_vel", movimento_velocidade)
	_mat.set_shader_parameter("brilho_geral", 0.0)
	material = _mat

	# Camada onde as faíscas são desenhadas (soma de luz por cima das asas)
	_brilhos = Node2D.new()
	var mat_add := CanvasItemMaterial.new()
	mat_add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_brilhos.material = mat_add
	_brilhos.draw.connect(_desenhar_brilhos)
	add_child(_brilhos)

	_preparar_pontos()

	if debug:
		print("Asas: alcance=", _alcance, " origem=", origem_pixels, " escala=", _escala_base)

	if testar_visivel:
		visible = true
		_definir_progresso(1.0)
		if sprite_frames and sprite_frames.has_animation(animacao):
			play(animacao)
	else:
		_definir_progresso(0.0)
		visible = false

func _process(delta: float) -> void:
	if jogador == null:
		return

	_tempo += delta
	_atualizar_transform()
	_atualizar_brilhos(delta)

	if testar_visivel:
		_tempo_teste -= delta
		if _tempo_teste <= 0.0:
			_tempo_teste = 1.5
			_explosao_brilhos(20)
			_pulso_brilho()
		return

	# Começou ou terminou de planar
	var planando: bool = jogador.planando
	if planando != _alvo_visivel:
		_alvo_visivel = planando
		if debug:
			print("Asas: ", "aparecendo" if planando else "sumindo")
		_animar(planando)

	# Só esconde de vez quando as faíscas acabarem
	if visible and not _alvo_visivel and not _transicionando and _lista.is_empty():
		visible = false
		stop()

# --- POSIÇÃO, ESCALA E MOVIMENTO NATURAL ---
func _atualizar_transform() -> void:
	var lado := -1.0 if (sprite_principal and sprite_principal.flip_h) else 1.0
	var k := lerpf(escala_inicial, 1.0, _progresso)
	var esc := Vector2(_escala_base.x * lado * k, _escala_base.y * k)

	# Balanço lento + tremor leve, mais a abertura (asa fechada -> aberta)
	var t := _tempo * movimento_velocidade
	var balanco := sin(t * PI) * 0.7 + sin(t * 3.7 + 1.3) * 0.3
	var ang := deg_to_rad(balanco_graus) * balanco + deg_to_rad(angulo_fechada) * (1.0 - _progresso)

	scale = esc
	rotation = ang * lado

	# Gira e escala em torno da origem das asas (ela fica parada no corpo)
	var base_pos := sprite_principal.position if sprite_principal else Vector2.ZERO
	var pos0 := base_pos + Vector2(posicao_local.x * lado, posicao_local.y)
	var fixo := pos0 + Vector2(origem_pixels.x * _escala_base.x * lado, origem_pixels.y * _escala_base.y)
	var pivo := Vector2(origem_pixels.x * esc.x, origem_pixels.y * esc.y)
	position = fixo - pivo.rotated(rotation)

# --- APARECER / SUMIR ---
func _animar(aparecer: bool) -> void:
	if _tween:
		_tween.kill()
	if _tween_pulso:
		_tween_pulso.kill()
	_mat.set_shader_parameter("brilho_geral", 0.0)
	_transicionando = true

	var alvo := 1.0 if aparecer else 0.0
	var dur := (duracao_aparecer if aparecer else duracao_sumir) * maxf(absf(alvo - minf(_progresso, 1.0)), 0.15)

	if aparecer:
		visible = true
		if sprite_frames and sprite_frames.has_animation(animacao):
			play(animacao)

	_tween = create_tween()
	if aparecer:
		_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)   # Abre com um leve "estouro"
	else:
		_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_tween.tween_method(_definir_progresso, _progresso, alvo, dur)
	_tween.tween_callback(_ao_terminar.bind(aparecer))

func _definir_progresso(valor: float) -> void:
	_progresso = valor
	_mat.set_shader_parameter("progresso", valor)

func _ao_terminar(apareceu: bool) -> void:
	_transicionando = false
	if apareceu:
		_explosao_brilhos(20)
		_pulso_brilho()

func _pulso_brilho() -> void:
	if _tween_pulso:
		_tween_pulso.kill()
	_tween_pulso = create_tween()
	_tween_pulso.tween_method(_definir_brilho_geral, 1.0, 0.0, 0.7)

func _definir_brilho_geral(valor: float) -> void:
	_mat.set_shader_parameter("brilho_geral", valor)

# --- FAÍSCAS ---
# Guarda pontos sobre os pixels visíveis da imagem, para as faíscas nascerem em cima das asas
func _preparar_pontos() -> void:
	_pontos.clear()
	_distancias.clear()
	if sprite_frames == null:
		return
	var nome: StringName = animacao if sprite_frames.has_animation(animacao) else animation
	if not sprite_frames.has_animation(nome) or sprite_frames.get_frame_count(nome) == 0:
		return
	var tex := sprite_frames.get_frame_texture(nome, 0)
	if tex == null:
		return
	var img := tex.get_image()
	if img == null:
		return
	if img.is_compressed():
		img.decompress()

	var tam := img.get_size()
	var canto := offset - Vector2(tam) * 0.5 if centered else offset
	var passo := maxi(1, int(maxf(tam.x, tam.y) / 48.0))
	for y in range(0, tam.y, passo):
		for x in range(0, tam.x, passo):
			if img.get_pixel(x, y).a > 0.3:
				var p := canto + Vector2(x, y)
				_pontos.append(p)
				_distancias.append(p.distance_to(origem_pixels))
	if debug:
		print("Asas: pontos de brilho=", _pontos.size())

func _atualizar_brilhos(delta: float) -> void:
	# Emite faíscas na frente da revelação enquanto a transição acontece
	if _transicionando and not _pontos.is_empty():
		_acumulo += brilhos_por_segundo * delta
		var n := int(_acumulo)
		_acumulo -= float(n)
		var frente := (_progresso * (1.0 + suavidade) - suavidade * 0.5) * _alcance
		for i in n:
			_emitir_na_frente(frente)

	var i := _lista.size() - 1
	while i >= 0:
		var b: Brilho = _lista[i]
		b.vida -= delta
		if b.vida <= 0.0:
			_lista.remove_at(i)
		else:
			b.pos += b.vel * delta
		i -= 1

	if visible:
		_brilhos.queue_redraw()

func _emitir_na_frente(frente: float) -> void:
	var banda := maxf(suavidade * _alcance, 4.0)
	for tentativa in 10:
		var idx := randi() % _pontos.size()
		if absf(_distancias[idx] - frente) <= banda:
			_criar_brilho(_pontos[idx])
			return

func _explosao_brilhos(quantidade: int) -> void:
	if _pontos.is_empty():
		return
	for i in quantidade:
		_criar_brilho(_pontos[randi() % _pontos.size()])

func _criar_brilho(pos: Vector2) -> void:
	if _lista.size() > 300:
		return
	var b := Brilho.new()
	b.pos = pos + Vector2(randf_range(-1.5, 1.5), randf_range(-1.5, 1.5))
	b.vel = Vector2(randf_range(-10.0, 10.0), randf_range(-26.0, -6.0))
	b.vida_max = vida_brilho * randf_range(0.6, 1.2)
	b.vida = b.vida_max
	b.tam = tamanho_brilho * randf_range(0.6, 1.4)
	b.fase = randf() * TAU
	_lista.append(b)

func _desenhar_brilhos() -> void:
	for item in _lista:
		var b: Brilho = item
		var f := b.vida / b.vida_max
		var piscar := 0.6 + 0.4 * sin(b.fase + _tempo * 18.0)
		var cor := Color(cor_brilho, clampf(f * 1.4, 0.0, 1.0) * piscar)
		var s := maxf(1.0, b.tam * (0.5 + f * 0.5))
		_brilhos.draw_rect(Rect2(b.pos - Vector2(s, s) * 0.5, Vector2(s, s)), cor)
		if b.tam > tamanho_brilho * 0.9:   # As faíscas maiores ganham uma cruz
			var cor2 := Color(cor, cor.a * 0.7)
			_brilhos.draw_rect(Rect2(b.pos - Vector2(s * 1.5, s * 0.25), Vector2(s * 3.0, s * 0.5)), cor2)
			_brilhos.draw_rect(Rect2(b.pos - Vector2(s * 0.25, s * 1.5), Vector2(s * 0.5, s * 3.0)), cor2)

# Distância da origem até o canto mais distante da imagem
func _calcular_alcance() -> float:
	if sprite_frames == null:
		return 100.0
	var nome: StringName = animacao if sprite_frames.has_animation(animacao) else animation
	if not sprite_frames.has_animation(nome) or sprite_frames.get_frame_count(nome) == 0:
		return 100.0
	var tex := sprite_frames.get_frame_texture(nome, 0)
	if tex == null:
		return 100.0

	var tam := tex.get_size()
	var canto := offset - tam * 0.5 if centered else offset
	var cantos: Array[Vector2] = [
		canto,
		canto + Vector2(tam.x, 0.0),
		canto + Vector2(0.0, tam.y),
		canto + tam,
	]
	var maior := 0.0
	for c in cantos:
		maior = maxf(maior, c.distance_to(origem_pixels))
	return maior
