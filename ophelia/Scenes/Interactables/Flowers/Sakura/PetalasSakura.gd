extends Node2D

@export_group("Pétalas caindo")
@export var ativo: bool = true
@export var textura_petala: Texture2D
@export var cor_petala: Color = Color("f599b4")
@export_range(0.0, 15.0, 0.5) var petalas_por_segundo: float = 2.5
@export_range(1, 100, 1) var limite_petalas: int = 40
@export_range(1.0, 20.0, 0.5) var duracao: float = 100.0
@export_range(1.0, 20.0, 0.5) var tamanho: float = 4.0
@export_range(1.0, 60.0, 1.0) var velocidade_queda: float = 16.0
@export_range(-40.0, 40.0, 1.0) var vento_horizontal: float = 6.0
@export_range(0.0, 20.0, 0.5) var amplitude_oscilar: float = 5.0
@export var pontos_emissao: PackedVector2Array

var _petalas: Array[Dictionary] = []
var _acumulado: float = 0.0
var _aleatorio: RandomNumberGenerator = RandomNumberGenerator.new()
var _formato: PackedVector2Array = PackedVector2Array([
	Vector2(0.0, -0.65), Vector2(0.29, -0.4),
	Vector2(0.4, -0.05), Vector2(0.31, 0.29),
	Vector2(0.0, 0.5), Vector2(-0.31, 0.29),
	Vector2(-0.4, -0.05), Vector2(-0.29, -0.4)
])


# Preparar as pétalas
# ---------------------
# Suspende a atualização enquanto o galho estiver fora da tela.
func _ready() -> void:

	_aleatorio.randomize()
	$Visibilidade.screen_entered.connect(_ao_entrar_na_tela)
	$Visibilidade.screen_exited.connect(_ao_sair_da_tela)
	set_process(false)


# Entrar na tela
# ---------------------
# Retoma a queda quando o galho fica visível.
func _ao_entrar_na_tela() -> void:

	set_process(true)


# Sair da tela
# ---------------------
# Interrompe a simulação e limpa as pétalas que já saíram de vista.
func _ao_sair_da_tela() -> void:

	set_process(false)
	_petalas.clear()
	_acumulado = 0.0
	queue_redraw()


# Criar uma pétala
# ---------------------
# Escolhe uma flor fixa como origem da queda decorativa.
func _emitir_petala() -> void:

	if pontos_emissao.is_empty() or _petalas.size() >= limite_petalas:

		return

	var indice: int = _aleatorio.randi_range(0, pontos_emissao.size() - 1)
	var origem: Vector2 = pontos_emissao[indice] + Vector2(
		_aleatorio.randf_range(-6.0, 6.0),
		_aleatorio.randf_range(-3.0, 3.0)
	)

	_petalas.append({
		"origem": origem,
		"idade": 0.0,
		"duracao": maxf(0.1, duracao * _aleatorio.randf_range(0.8, 1.2)),
		"fase": _aleatorio.randf_range(0.0, TAU),
		"angulo": _aleatorio.randf_range(0.0, TAU),
		"giro": _aleatorio.randf_range(-0.8, 0.8),
		"escala": _aleatorio.randf_range(0.7, 1.2),
		"velocidade": _aleatorio.randf_range(0.8, 1.2)
	})


# Atualizar a queda
# ---------------------
# Emite aos poucos e remove cada pétala ao terminar sua duração.
func _process(delta: float) -> void:

	if ativo and petalas_por_segundo > 0.0:

		_acumulado = minf(_acumulado + delta * petalas_por_segundo, float(limite_petalas))

		while _acumulado >= 1.0:

			_acumulado -= 1.0
			_emitir_petala()

	for i in range(_petalas.size() - 1, -1, -1):

		_petalas[i]["idade"] = float(_petalas[i]["idade"]) + delta

		if float(_petalas[i]["idade"]) >= float(_petalas[i]["duracao"]):

			_petalas.remove_at(i)

	queue_redraw()


# Desenhar as pétalas
# ---------------------
# Combina queda, oscilação, giro e desaparecimento suave.
func _draw() -> void:

	for petala in _petalas:

		var idade: float = float(petala["idade"])
		var tempo: float = idade / float(petala["duracao"])
		var fase: float = float(petala["fase"])
		var origem: Vector2 = petala["origem"]
		var deslocamento: Vector2 = Vector2(
			vento_horizontal * idade + (sin(idade * 1.6 + fase) - sin(fase)) * amplitude_oscilar,
			velocidade_queda * idade * float(petala["velocidade"])
		)
		var cor: Color = cor_petala
		cor.a *= smoothstep(0.0, 0.08, tempo) * (1.0 - smoothstep(0.65, 1.0, tempo))
		var escala: float = tamanho * float(petala["escala"])
		var largura: float = 0.55 + absf(sin(idade * 1.3 + fase)) * 0.45

		draw_set_transform(
			origem + deslocamento,
			float(petala["angulo"]) + idade * float(petala["giro"]),
			Vector2(escala * largura, escala)
		)

		if textura_petala != null:

			var dimensoes: Vector2 = textura_petala.get_size()
			var proporcao: Vector2 = dimensoes / maxf(dimensoes.x, dimensoes.y)
			draw_texture_rect(textura_petala, Rect2(-proporcao * 0.5, proporcao), false, cor)

		else:

			draw_colored_polygon(_formato, cor)

	draw_set_transform(Vector2.ZERO)
