extends RefCounted
## Componente especializado; o coordenador fornece o estado e as referências.
var lenco

# Configurar o componente
# ---------------------
# Guarda a referência do coordenador usada por este componente.
func configurar(coordenador) -> void:

	lenco = coordenador

# Tentar disparar gancho
# ---------------------
# Processa tentar disparar gancho.
func _tentar_disparar_gancho(origem: Vector2, alvo_mouse: Vector2) -> void:

	if not lenco.raio_alcance or not lenco.jogador:

		return

	lenco.raio_alcance.global_position = origem
	lenco.raio_alcance.target_position = lenco.raio_alcance.to_local(origem + (alvo_mouse - origem).normalized() * lenco.alcance_gancho)
	lenco.raio_alcance.force_raycast_update()
	# Testa os projéteis parados antes do primeiro obstáculo do cenário.
	var limite = lenco.alcance_gancho

	if lenco.raio_alcance.is_colliding():

		limite = minf(limite, origem.distance_to(lenco.raio_alcance.get_collision_point()))

	var apoio = lenco._buscar_projetil_apoio(origem, alvo_mouse, limite)

	if apoio != null:

		lenco._limpar_ancora()
		lenco.alvo_gancho = apoio
		lenco.ancora_segue = true
		lenco.ancora_local = Vector2.ZERO
		lenco.ponto_ancora_gancho = apoio.global_position
		var distancia = lenco.jogador.global_position.distance_to(lenco.ponto_ancora_gancho)
		lenco.distancia_corda = maxf(lenco.alcance_gancho, distancia) if lenco.jogador.is_on_floor() else distancia
		lenco.estado_atual = lenco.EstadoLenco.GANCHO
		return

	if not lenco.raio_alcance.is_colliding():

		# Nada para prender: mostra o círculo de alcance
		lenco.tempo_aviso_alcance = lenco.duracao_aviso_alcance
		return

	var colisor = lenco.raio_alcance.get_collider()
	var ponto = lenco.raio_alcance.get_collision_point()
	# Objeto móvel (empurrável pela física): leve ou pesado, conforme o limite de força
	var leve = false

	if colisor is RigidBody2D:

		leve = lenco._forca_necessaria(colisor) <= lenco.limite_forca_lenco
		# Um objeto leve só prende o lenço depois de aprender AgarrarObjeto

		if leve and lenco.leves_exigem_habilidade and not lenco._pode_usar(OpheliaHabilidades.AGARRAR_OBJETO):

			lenco.tempo_aviso_alcance = lenco.duracao_aviso_alcance
			return
	# O mouse esquerdo prende em tudo. O que o impulso (botão direito) faz depende do alvo:
	#   parede, chão ou objeto pesado -> a personagem vai até o ponto
	#   objeto leve                   -> o objeto é lançado até a personagem

	lenco._limpar_ancora()
	lenco.ponto_ancora_gancho = ponto

	if colisor is RigidBody2D or colisor is AnimatableBody2D:

		# O ponto acompanha o objeto/plataforma se ele se mover
		lenco.alvo_gancho = colisor as Node2D
		lenco.ancora_local = lenco.alvo_gancho.to_local(ponto)
		lenco.ancora_segue = true

	lenco.ancora_leve = leve
	var dist = lenco.jogador.global_position.distance_to(lenco.ponto_ancora_gancho)
	# No chão: corda com todo o alcance (anda e pula livremente).
	# No ar: balança com a distância atual.
	lenco.distancia_corda = maxf(lenco.alcance_gancho, dist) if lenco.jogador.is_on_floor() else dist
	lenco.estado_atual = lenco.EstadoLenco.GANCHO

# Atualizar gancho pendulo
# ---------------------
# Atualiza gancho pendulo.
func _atualizar_gancho_pendulo(origem: Vector2, delta: float) -> void:

	lenco.pontos_tras[0] = origem
	lenco.pontos_frente[0] = origem

	if lenco.alvo_gancho is OpheliaProjetilLenco:

		if not lenco.alvo_gancho.pode_servir_de_apoio():

			lenco._soltar_apoio_projetil(lenco.alvo_gancho)
			return
	# Âncora presa a um objeto/plataforma móvel: o ponto acompanha o alvo

	if lenco.ancora_segue:

		if is_instance_valid(lenco.alvo_gancho):

			lenco.ponto_ancora_gancho = lenco.alvo_gancho.to_global(lenco.ancora_local)

		else:

			lenco.estado_atual = lenco.EstadoLenco.REPOUSO
			return

	if not lenco.jogador:

		return
	# Objeto leve: o impulso lança o OBJETO até a personagem (a corda não segura nem puxa a personagem)

	if lenco.ancora_leve:

		lenco.corda_esticada = false
		lenco._atualizar_gancho_leve(origem)
		return
	# BOTÃO DIREITO: impulso da personagem até o ponto firme

	if lenco.impulso_gancho_pendente:

		var dir_puxao = (lenco.ponto_ancora_gancho - origem).normalized()
		lenco.jogador.velocity = dir_puxao * lenco.velocidade_impulso
		lenco.corda_esticada = false
		lenco.estado_atual = lenco.EstadoLenco.REPOUSO
		return
	# Ao pousar, a corda volta a ter o alcance completo

	if lenco.jogador.is_on_floor():

		lenco.distancia_corda = maxf(lenco.distancia_corda, lenco.alcance_gancho)

	# Restrição unilateral de corda: ela só puxa quando esticada.
	# Não aplica impulso artificial em direção à âncora (origem do quique
	# da revisão anterior). A gravidade permanece a cargo do personagem.
	var raio: float = maxf(lenco.distancia_corda, 1.0)
	var posicao: Vector2 = lenco.jogador.global_position
	var radial: Vector2 = posicao - lenco.ponto_ancora_gancho
	var distancia: float = radial.length()
	if distancia <= 0.001:
		lenco.corda_esticada = false
		return

	var normal: Vector2 = radial / distancia
	var velocidade: Vector2 = lenco.jogador.velocity
	var prevista: Vector2 = posicao + velocidade * delta
	var prevista_distancia: float = prevista.distance_to(lenco.ponto_ancora_gancho)
	# Com folga, o lenço não prende o movimento. Uma margem pequena evita
	# alternar entre esticado e solto por erros de ponto flutuante.
	if distancia < raio - lenco.tolerancia_corda and prevista_distancia < raio:
		lenco.corda_esticada = false
		var entrada_livre: float = Input.get_axis("ControleAndarEsquerda", "ControleAndarDireita")
		if not lenco.jogador.is_on_floor() and not is_zero_approx(entrada_livre):
			lenco.jogador.velocity.x += entrada_livre * lenco.forca_embalo_ar * 0.35 * delta
		return

	lenco.corda_esticada = true
	# Direção tangente à circunferência. Preservar esta componente mantém
	# o embalo ao passar pelo ponto mais baixo.
	var tangente: Vector2 = Vector2(-normal.y, normal.x)
	var rapidez_tangencial: float = velocidade.dot(tangente)
	var entrada: float = Input.get_axis("ControleAndarEsquerda", "ControleAndarDireita")
	if not lenco.jogador.is_on_floor():
		rapidez_tangencial += entrada * tangente.x * lenco.forca_embalo_ar * delta
	rapidez_tangencial *= exp(-lenco.amortecimento_pendulo * delta)
	rapidez_tangencial = clampf(rapidez_tangencial, -lenco.limite_velocidade_pendulo, lenco.limite_velocidade_pendulo)

	# Remover SOMENTE velocidade radial para fora. Uma velocidade para
	# dentro é fisicamente válida: a corda pode afrouxar sem empurrar.
	var velocidade_radial: float = minf(velocidade.dot(normal), 0.0)
	lenco.jogador.velocity = tangente * rapidez_tangencial + normal * velocidade_radial

# Corrige o erro de integração depois do move_and_slide(), quando a
# posição realmente mudou. Evita o ciclo 'passou do raio -> velocidade
# negativa -> folga -> caiu -> passou do raio', muito visível em repouso.
func corrigir_restricao_apos_movimento() -> void:
	if not lenco.jogador or lenco.estado_atual != lenco.EstadoLenco.GANCHO or lenco.ancora_leve:
		return
	if lenco.jogador.is_on_floor():
		return
	if lenco.ancora_segue and is_instance_valid(lenco.alvo_gancho):
		lenco.ponto_ancora_gancho = lenco.alvo_gancho.to_global(lenco.ancora_local)
	var raio: float = maxf(lenco.distancia_corda, 1.0)
	var deslocamento: Vector2 = lenco.jogador.global_position - lenco.ponto_ancora_gancho
	var distancia: float = deslocamento.length()
	if distancia <= raio or distancia <= 0.001:
		return
	var normal: Vector2 = deslocamento / distancia
	var excesso: float = distancia - raio
	# Não teletransportar através de paredes: se o ajuste tocar em um
	# obstáculo, a física de colisão terá prioridade.
	var correcao: Vector2 = -normal * excesso
	if not lenco.jogador.test_move(lenco.jogador.global_transform, correcao):
		lenco.jogador.global_position += correcao
	# Mesmo que uma parede impeça o ajuste, não adicionar energia radial.
	var saida: float = lenco.jogador.velocity.dot(normal)
	if saida > 0.0:
		lenco.jogador.velocity -= normal * saida

# Atualizar gancho leve
# ---------------------
# Atualiza gancho leve.
func _atualizar_gancho_leve(origem: Vector2) -> void:

	var objeto = lenco.alvo_gancho as RigidBody2D
	# Perdeu o objeto, a permissão (ex.: modo debug desligado) ou ele foi longe demais: solta

	if not is_instance_valid(objeto) \
			or (lenco.leves_exigem_habilidade and not lenco._pode_usar(OpheliaHabilidades.AGARRAR_OBJETO)) \
			or origem.distance_to(objeto.global_position) > lenco.alcance_gancho * lenco.soltar_alem_do_alcance:

		lenco.estado_atual = lenco.EstadoLenco.REPOUSO
		return

	if lenco.impulso_gancho_pendente:

		var dir = (origem - objeto.global_position).normalized()
		objeto.sleeping = false
		objeto.linear_velocity = dir * lenco.velocidade_impulso_objeto
		lenco.estado_atual = lenco.EstadoLenco.REPOUSO   # O impulso gasta o gancho, como o impulso da personagem

# Forca necessaria
# ---------------------
# Processa forca necessaria.
func _forca_necessaria(corpo: Object) -> float:

	if corpo.has_meta("forca_necessaria"):

		return float(corpo.get_meta("forca_necessaria"))

	var rigido = corpo as RigidBody2D

	if rigido != null:

		return rigido.mass

	return INF

# Limpar ancora
# ---------------------
# Limpa ancora.
func _limpar_ancora() -> void:

	lenco.alvo_gancho = null
	lenco.ancora_segue = false
	lenco.ancora_leve = false

# Buscar projétil apoio
# ---------------------
# Procura projétil apoio.
func _buscar_projetil_apoio(origem: Vector2, mouse: Vector2, limite: float) -> OpheliaProjetilLenco:

	var direcao = origem.direction_to(mouse)

	if direcao == Vector2.ZERO:

		return null

	var escolhido: OpheliaProjetilLenco = null
	var mais_perto = limite

	for p in lenco.projeteis:

		if not is_instance_valid(p) or not p.pode_servir_de_apoio():

			continue

		var relativo = p.global_position - origem
		var projecao = relativo.dot(direcao)
		var lateral_quadrado = maxf(0.0, relativo.length_squared() - projecao * projecao)
		var raio_apoio = maxf(lenco.raio_apoio_projetil, p.raio)

		if lateral_quadrado > raio_apoio * raio_apoio:

			continue

		var margem = sqrt(raio_apoio * raio_apoio - lateral_quadrado)

		if projecao + margem < 0.0:

			continue

		var entrada = maxf(0.0, projecao - margem)
		# O centro também precisa estar ao alcance e antes do obstáculo.

		if relativo.length() <= limite and entrada <= mais_perto:

			escolhido = p
			mais_perto = entrada

	return escolhido

# Soltar apoio projétil
# ---------------------
# Solta apoio projétil.
func _soltar_apoio_projetil(p: OpheliaProjetilLenco) -> void:

	if lenco.alvo_gancho != p:

		return

	lenco.corda_esticada = false
	lenco._limpar_ancora()

	if lenco.estado_atual == lenco.EstadoLenco.GANCHO:

		lenco.estado_atual = lenco.EstadoLenco.REPOUSO

# Atualizar visual corda
# ---------------------
# Atualiza visual corda.
func atualizar_visual_corda(origem: Vector2, delta: float) -> void:

	lenco.pontos_tras[0] = origem
	lenco.pontos_frente[0] = origem

	for i in range(1, lenco.pontos_por_fita):

		var t = float(i) / float(lenco.pontos_por_fita - 1)
		var pos_linha = origem.lerp(lenco.ponto_ancora_gancho, t)
		# Base rápida (45) -> ponta (18): a fita sai reta da gola, sem dobra
		var peso_fita = 1.0 if lenco.corda_esticada else lenco._peso_ponto(t, 45.0, 18.0, delta)
		lenco.pontos_tras[i] = lenco.pontos_tras[i].lerp(pos_linha, peso_fita)
		lenco.pontos_frente[i] = lenco.pontos_frente[i].lerp(pos_linha, peso_fita)
