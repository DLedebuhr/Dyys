extends SceneTree
class Alvo extends StaticBody2D:

	var vida: int = 100

	# Receber dano
	# ---------------------
	# Recebe dano.
	func receber_dano(dano: int) -> bool:

		vida -= dano
		return true

var total: int = 0
var falhas: int = 0
var mundo: Node2D

# Iniciar a execução
# ---------------------
# Prepara a execução desta ferramenta.
func _initialize() -> void:

	call_deferred("executar")

# Conferir
# ---------------------
# Processa conferir.
func conferir(valor: bool, texto: String) -> void:

	total += 1

	if not valor:

		falhas += 1
		push_error(texto)

	else:

		print("OK: ", texto)

# Quadros
# ---------------------
# Processa quadros.
func quadros() -> void:

	await physics_frame
	await physics_frame
	await process_frame

# Criar alvo
# ---------------------
# Cria alvo.
func criar_alvo(posicao: Vector2, tamanho: Vector2, camada: int) -> Alvo:

	var alvo := Alvo.new()
	alvo.collision_layer = camada
	alvo.collision_mask = 0
	alvo.position = posicao
	var colisao := CollisionShape2D.new()
	var forma := RectangleShape2D.new()
	forma.size = tamanho
	colisao.shape = forma
	alvo.add_child(colisao)
	mundo.add_child(alvo)
	return alvo

# Projétil
# ---------------------
# Processa projétil.
func projetil(origem: Vector2) -> OpheliaProjetilLenco:

	var p := OpheliaProjetilLenco.new()
	p.velocidade_ida = 20000
	p.alcance = 400
	p.tempo_espera = 5
	mundo.add_child(p)
	p.lancar(origem, Vector2.RIGHT)
	p.set_physics_process(false)
	return p

# Executar
# ---------------------
# Executa a rotina deste componente.
func executar() -> void:

	mundo = Node2D.new()
	root.add_child(mundo)
	var parede := criar_alvo(Vector2(150, 100), Vector2(2, 160), CamadasFisica.CENARIO_SOLIDO | CamadasFisica.RECEBE_DANO)
	await quadros()
	var p := projetil(Vector2(50, 100))
	p._passo_ida(0.1)
	conferir(p._fase == p.Fase.ESPERA, "Projétil rápido para em parede de 2 pixels")
	conferir(p.global_position.x + 15.6 <= 149.1, "Volume do projétil permanece antes da superfície")
	conferir(parede.vida == 95, "Impacto aplica exatamente 5 de dano")
	p._aplicar_dano(parede)
	conferir(parede.vida == 95, "Projétil não duplica dano")
	conferir(p.pode_servir_de_apoio(), "Projétil parado continua servindo de apoio")
	p.queue_free()
	var ar := projetil(Vector2(50, 300))
	ar._passo_ida(0.002)
	var parada: Vector2 = ar.global_position
	conferir(ar.parar_no_ar(), "Segundo comando para projétil antes do alcance máximo")
	ar._physics_process(1.0)
	conferir(ar.global_position == parada and is_equal_approx(ar._tempo_parado, 1.0), "Parada inicia a espera de 5 segundos sem deslocamento")
	ar._physics_process(4.1)
	conferir(ar._fase == ar.Fase.VOLTA, "Projétil parado manualmente retorna ao terminar os 5 segundos")
	ar.queue_free()
	var limite := projetil(Vector2(50, 400))
	limite._passo_ida(0.1)
	conferir(is_equal_approx(limite.global_position.x, 450.0) and limite._fase == limite.Fase.ESPERA, "Alcance máximo permanece funcionando")
	limite.queue_free()
	var spawn := OpheliaProjetilLenco.new()
	mundo.add_child(spawn)
	spawn.lancar(Vector2(250, 100), Vector2.RIGHT, Vector2(50, 100))
	spawn.set_physics_process(false)
	conferir(spawn.global_position.x < 149 and spawn._fase == spawn.Fase.ESPERA, "Lançamento não nasce atrás de obstáculo próximo")
	spawn.queue_free()
	var corpo: CharacterBody2D = load("res://Ophelia/OPHELIA.tscn").instantiate()
	mundo.add_child(corpo)
	corpo.set_physics_process(false)
	corpo.global_position = Vector2(50, 80)
	corpo.habilidades.definir_modo_debug(true)
	var lenco: Node2D = corpo.lenco
	lenco.origem_anterior = Vector2(50, 100)
	lenco.dir_acao = Vector2.RIGHT
	lenco.estado_atual = lenco.EstadoLenco.ATAQUE
	lenco.ataque_a_distancia = false
	lenco.tempo_estado = lenco.duracao_formacao_ataque

	for i in range(lenco.pontos_por_fita):

		lenco.pontos_tras[i] = lenco.origem_anterior
		lenco.pontos_frente[i] = lenco.origem_anterior
		lenco.pontos_inicio_tras[i] = lenco.origem_anterior
		lenco.pontos_inicio_frente[i] = lenco.origem_anterior

	await quadros()

	for i in range(20):

		lenco.combate._atualizar_ataque(lenco.origem_anterior, 0.016)

	conferir(lenco.alcance_ataque_atual < lenco.alcance_ataque, "Golpe encurta ao encontrar obstáculo próximo")
	conferir(lenco.pontos_frente[-1].x + lenco.tamanho_ponta.x * 0.5 <= 149.1, "Ponta do golpe respeita o limite da parede")
	conferir(parede.vida == 80, "Golpe normal aplica 10 de dano uma única vez")
	var atras := criar_alvo(Vector2(200, 100), Vector2(10, 40), CamadasFisica.RECEBE_DANO)
	await quadros()
	lenco.combate._ao_ataque_normal_atingir(atras)
	conferir(atras.vida == 100, "Ataque não aplica dano a alvo atrás da parede")
	var voo := projetil(Vector2(50, 500))
	lenco.projeteis.append(voo)
	corpo._pedidos.append({"acao": &"ControleAtaqueLenco", "mouse": Vector2(300, 500)})
	corpo._executar_pedidos()
	conferir(voo._fase == voo.Fase.ESPERA and corpo._pedidos.is_empty(), "Comando de parada funciona com o lenço ocupado e é consumido")
	var p2 := projetil(Vector2(50, 600))
	var p3 := projetil(Vector2(80, 600))
	lenco.projeteis.append(p2)
	lenco.projeteis.append(p3)
	conferir(lenco.parar_projeteis_em_voo() and p2._fase == p2.Fase.ESPERA and p3._fase == p3.Fase.ESPERA, "Mesmo comando interrompe os dois disparos ainda em voo")
	var dentro := projetil(Vector2(150, 100))
	dentro._passo_ida(0.1)
	conferir(dentro._fase == dentro.Fase.ESPERA, "Sobreposição inicial não permite atravessar a parede")
	var area := Area2D.new()
	area.position = Vector2(150, 700)
	area.collision_layer = CamadasFisica.RECEBE_DANO
	area.collision_mask = 0
	var forma_area := CollisionShape2D.new()
	var retangulo_area := RectangleShape2D.new()
	retangulo_area.size = Vector2(2, 60)
	forma_area.shape = retangulo_area
	area.add_child(forma_area)
	mundo.add_child(area)
	await quadros()
	var rapido := projetil(Vector2(50, 700))
	rapido._passo_ida(0.1)
	conferir(rapido._fase == rapido.Fase.ESPERA and rapido.global_position.x < 149, "Varredura também detecta áreas de dano finas")
	print("RESULTADO: ", total - falhas, "/", total, " verificações passaram")
	mundo.queue_free()
	await process_frame
	quit(1 if falhas > 0 else 0)
