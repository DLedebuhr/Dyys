# ===== BRILHOS TEMPORÁRIOS DA BONECA (resquícios do voo) =====
# É adicionado POR CÓDIGO na cena Player durante o teaser. Não altera a cena original:
# o nó só existe enquanto o teaser está rodando.
class_name TeaserBrilhos
extends Node

var duracao: float = 7.0
var cor: Color = Color(1.0, 0.92, 0.65)

var corpo: CharacterBody2D = null
var rastro: CPUParticles2D = null
var explosao: CPUParticles2D = null
var intensidade: float = 1.0
var escala_min: float = 1.0
var escala_max: float = 1.0

# Chame depois de adicionar este nó como filho do personagem
func iniciar(cor_brilho: Color, duracao_s: float) -> void:
	cor = cor_brilho
	duracao = duracao_s
	corpo = get_parent() as CharacterBody2D
	if corpo == null:
		set_physics_process(false)
		return

	var pes: Vector2 = TeaserUtil.posicao_pes(corpo)
	var centro: Vector2 = TeaserUtil.posicao_centro(corpo)

	# Rastro: nasce dos pés enquanto ela anda ou está no ar, e vai diminuindo
	rastro = TeaserUtil.criar_particulas_brilho("TeaserRastro", cor, 22, 1.1,
			4.0, 22.0, 0.12, 0.35, 5.0, Vector2(0.0, -14.0))
	rastro.position = pes
	rastro.emitting = false
	corpo.add_child(rastro)
	escala_min = rastro.scale_amount_min
	escala_max = rastro.scale_amount_max

	# Explosão de faíscas no momento da transformação
	explosao = TeaserUtil.criar_particulas_brilho("TeaserExplosao", cor, 48, 1.2,
			40.0, 140.0, 0.15, 0.5, 6.0, Vector2(0.0, -30.0))
	explosao.one_shot = true
	explosao.explosiveness = 1.0
	explosao.position = centro
	explosao.emitting = false
	corpo.add_child(explosao)

func explodir() -> void:
	if explosao == null:
		return
	explosao.restart()
	explosao.emitting = true

func _physics_process(delta: float) -> void:
	if corpo == null or rastro == null:
		return
	intensidade = maxf(intensidade - delta / maxf(duracao, 0.1), 0.0)

	var movendo: bool = absf(corpo.velocity.x) > 12.0
	var no_ar: bool = not corpo.is_on_floor()
	rastro.emitting = (movendo or no_ar) and intensidade > 0.02
	# As faíscas ficam menores conforme o tempo passa
	rastro.scale_amount_min = escala_min * intensidade
	rastro.scale_amount_max = escala_max * intensidade
