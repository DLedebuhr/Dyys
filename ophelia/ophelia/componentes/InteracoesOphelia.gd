extends RefCounted
## Componente especializado; o coordenador fornece o estado e as referências.
var corpo

func configurar(coordenador) -> void:
	corpo = coordenador

func _ao_mudar_frame() -> void:
	if not corpo.brilho_batida_ativo or corpo.reacao_atual != corpo.REACAO_IRRITADA or not corpo.sprite:
		return
	if not String(corpo.sprite.animation).begins_with("Irritada"):
		return
	if corpo.frame_batida_pe < 0 or corpo.sprite.frame == corpo.frame_batida_pe:
		corpo._brilho_nos_pes()

func _posicao_pes_global() -> Vector2:
	var local = Vector2.ZERO
	if corpo.colisor_corpo != null:
		var capsula = corpo.colisor_corpo.shape as CapsuleShape2D
		if capsula != null:
			local = corpo.colisor_corpo.position + Vector2(0.0, capsula.height * 0.5 * corpo.colisor_corpo.scale.y)
	return corpo.to_global(local)

func _brilho_nos_pes() -> void:
	var p = CPUParticles2D.new()
	p.texture = corpo._textura_brilho()
	p.one_shot = true
	p.emitting = false
	p.amount = corpo.quantidade_brilho_batida
	p.lifetime = corpo.duracao_brilho_batida
	p.explosiveness = 1.0                 # Todas saem de uma vez: efeito de explosão
	p.direction = Vector2.UP
	p.spread = corpo.espalhamento_brilho_batida
	p.gravity = Vector2(0, 30)            # Cai bem de leve no final
	p.initial_velocity_min = corpo.alcance_brilho_batida * 0.4
	p.initial_velocity_max = corpo.alcance_brilho_batida
	p.damping_min = 40.0                  # Freia no ar, como faísca
	p.damping_max = 80.0
	p.scale_amount_min = 0.4 * corpo.tamanho_brilho_batida
	p.scale_amount_max = 1.0 * corpo.tamanho_brilho_batida
	p.color = corpo.cor_brilho_batida

	# Encolhe até sumir
	p.scale_amount_curve = OpheliaEfeitosComuns.curva_encolher()

	# Soma luz em vez de cobrir (fica brilhante de verdade)
	var mat = OpheliaEfeitosComuns.material_aditivo()
	p.material = mat

	# Filho do OPHELIA, sem mexer no z_index: fica atrás dos mesmos objetos que ela
	corpo.add_child(p)
	var lado = -1.0 if corpo.sprite.flip_h else 1.0
	p.global_position = corpo._posicao_pes_global() + Vector2(corpo.deslocamento_pe_batida.x * lado, corpo.deslocamento_pe_batida.y)
	p.emitting = true
	corpo.get_tree().create_timer(corpo.duracao_brilho_batida + 0.3).timeout.connect(p.queue_free)

func _textura_brilho() -> Texture2D:
	return OpheliaEfeitosComuns.textura_radial(16)

func _ao_entrar_em_area(area: Area2D) -> void:
	if String(area.name).begins_with("AreaPrePortal") or area.is_in_group("AreaPrePortal"):
		if corpo._deve_ficar_irritada(area):
			corpo.tocar_reacao(corpo.REACAO_IRRITADA)

func _deve_ficar_irritada(_area: Area2D) -> bool:
	return not corpo.catalogo_completo
