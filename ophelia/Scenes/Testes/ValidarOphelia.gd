extends SceneTree
## Testes de comportamento em uma cena isolada. Nenhum dado do Player antigo é modificado.
class AlvoSemRetorno extends Node:
	func receber_dano(_quantidade: int) -> void:
		pass

var corpo
var mundo: Node2D
var falhas: Array[String] = []
var acertos: int = 0
var alvo
var acoes_antes: Array[StringName] = []

func _initialize() -> void:
	call_deferred("_executar")

func verificar(condicao: bool, descricao: String) -> void:
	if condicao:
		acertos += 1
		print("OK: ", descricao)
	else:
		falhas.append(descricao)
		push_error("FALHOU: " + descricao)

func quadros(quantidade: int) -> void:
	for i in range(quantidade):
		await physics_frame
	await process_frame

func apertar(acao: StringName) -> void:
	var evento := InputEventAction.new()
	evento.action = acao
	evento.pressed = true
	Input.parse_input_event(evento)
	await process_frame

func soltar(acao: StringName) -> void:
	var evento := InputEventAction.new()
	evento.action = acao
	evento.pressed = false
	Input.parse_input_event(evento)
	await process_frame

func pedido(acao: StringName, mouse: Vector2) -> void:
	corpo.entrada._pedidos.append({"acao": acao, "mouse": mouse})

func reiniciar() -> void:
	if is_instance_valid(mundo):
		mundo.queue_free()
		await process_frame
	mundo = Node2D.new()
	root.add_child(mundo)
	current_scene = mundo
	var chao := StaticBody2D.new()
	chao.position = Vector2(0, 220)
	var forma := CollisionShape2D.new()
	var retangulo := RectangleShape2D.new()
	retangulo.size = Vector2(3000, 40)
	forma.shape = retangulo
	chao.add_child(forma)
	mundo.add_child(chao)
	var cena: PackedScene = load("res://Ophelia/OPHELIA.tscn")
	corpo = cena.instantiate()
	mundo.add_child(corpo)
	corpo.habilidades.imprimir_eventos = false
	corpo.imprimir_reacoes = false
	corpo.habilidades.definir_modo_debug(true)
	await quadros(90)

func _executar() -> void:
	var legado := AlvoSemRetorno.new()
	verificar(OpheliaDano.aplicar(legado, 5), "Interface de dano aceita alvo antigo sem retorno")
	legado.free()
	acoes_antes = InputMap.get_actions()
	await reiniciar()
	verificar(corpo.is_on_floor(), "Cena carrega e personagem pousa no chão")
	verificar(corpo.lenco._centro_corpo() == corpo.colisor_corpo.global_position, "Defesa usa a referência explícita da colisão renomeada")
	verificar(InputMap.get_actions() == acoes_antes, "Cena não cria ações no InputMap")
	verificar(corpo.lenco.get_node("Efeitos") != null, "Uma instância explícita de efeitos")
	verificar(corpo.lenco.projeteis.is_empty(), "Sem projétil visível/ativo ao iniciar")
	await apertar(&"ControleAndarDireita")
	await quadros(12)
	verificar(corpo.velocity.x > 0.0, "Direita acelera a personagem")
	await soltar(&"ControleAndarDireita")
	await quadros(20)
	verificar(absf(corpo.velocity.x) < 1.0, "Soltar direção aplica frenagem")
	await apertar(&"ControlePular")
	await quadros(2)
	verificar(corpo.velocity.y < 0.0, "Pulo usa evento de aperto")
	await soltar(&"ControlePular")
	await quadros(90)

	corpo.duracao_irritada = 0.12
	corpo.duracao_transicao_pose = 0.1
	corpo.olhando_esquerda = true
	corpo.tocar_reacao(corpo.REACAO_IRRITADA)
	await quadros(2)
	verificar(corpo.estado_pose == corpo.EstadoPose.Entrando and corpo.sprite.flip_h, "Entrada frontal espelha para a esquerda")
	await quadros(25)
	verificar(corpo.estado_pose == corpo.EstadoPose.EsperarMovimento, "Reação termina em EsperarMovimento")
	corpo.lenco.tempo_ativo_ataque = 0.5
	await apertar(&"ControleAtaqueLenco")
	await soltar(&"ControleAtaqueLenco")
	await quadros(22)
	verificar(corpo.lenco.estado_atual == corpo.lenco.EstadoLenco.ATAQUE, "Ataque apertado e solto na espera executa após a transição")
	await quadros(60)
	verificar(corpo.estado_pose == corpo.EstadoPose.Normal, "Saída volta à pose normal")

	await reiniciar()
	var antes: int = corpo.vitalidade.vida_atual
	verificar(corpo.receber_dano(10), "Receber dano fora da defesa reduz vida")
	verificar(corpo.vitalidade.vida_atual == antes - 10, "Quantidade de dano recebida é exata")
	pedido(&"ControleDefesaLenco", corpo.global_position + Vector2.RIGHT * 100)
	await quadros(20)
	verificar(corpo.lenco.defesa_ativa(), "Escudo entra em sua janela ativa")
	var vida_defendendo: int = corpo.vitalidade.vida_atual
	verificar(not corpo.receber_dano(30), "Escudo bloqueia receber_dano")
	verificar(corpo.vitalidade.vida_atual == vida_defendendo, "Defesa preserva a vida")
	var hostil = load("res://Scenes/Testes/ProjetilHostilTeste.gd").new()
	hostil.position = corpo.global_position + Vector2(110, 25)
	mundo.add_child(hostil)
	await quadros(12)
	verificar(not is_instance_valid(hostil) or hostil.is_queued_for_deletion(), "Área do escudo intercepta projétil hostil")
	await quadros(60)
	verificar(not corpo.lenco.defesa_ativa(), "Defesa termina ao esgotar a duração")
	verificar(corpo.receber_dano(5), "Dano volta a funcionar depois da defesa")

	await reiniciar()
	var lenco = corpo.lenco
	lenco.alcance_projetil = 30.0
	lenco.dir_acao = Vector2.RIGHT
	lenco._lancar_projetil()
	lenco._lancar_projetil()
	lenco._lancar_projetil()
	verificar(lenco.projeteis.size() == 2, "Máximo de dois projéteis ativos")
	await quadros(20)
	verificar(lenco.projeteis.size() == 2, "Projéteis permanecem parados antes da recarga")
	await quadros(320)
	verificar(lenco.projeteis.is_empty(), "Projéteis retornam e recuperam as cargas após cinco segundos")

	await reiniciar()
	lenco = corpo.lenco
	lenco.dir_acao = Vector2.RIGHT
	lenco._lancar_projetil()
	var projetil = lenco.projeteis[0]
	projetil.global_position = corpo.global_position + Vector2(160, -120)
	projetil._comecar_espera()
	verificar(projetil.pode_servir_de_apoio(), "Projétil parado disponibiliza apoio")
	lenco._tentar_disparar_gancho(lenco.origem_anterior, projetil.global_position)
	verificar(lenco.alvo_gancho == projetil, "Gancho prende no projétil parado")
	projetil._comecar_volta()
	verificar(lenco.alvo_gancho == null, "Retorno do projétil solta o gancho")
	lenco.soltar_tudo()
	await quadros(2)
	lenco._lancar_projetil()
	projetil = lenco.projeteis[0]
	projetil.global_position = corpo.global_position + Vector2(0, 25)
	projetil._comecar_espera()
	await quadros(30)
	verificar(lenco.projeteis.is_empty(), "Contato com a personagem antecipa a recuperação")

	await reiniciar()
	alvo = load("res://Scenes/Testes/AlvoTeste.gd").new()
	alvo.collision_layer = 4
	alvo.collision_mask = 0
	alvo.position = corpo.global_position + Vector2(140, 21)
	var forma := CollisionShape2D.new()
	var retangulo := RectangleShape2D.new()
	retangulo.size = Vector2(35, 80)
	forma.shape = retangulo
	alvo.add_child(forma)
	mundo.add_child(alvo)
	pedido(&"ControleAtaqueLenco", alvo.global_position)
	await quadros(24)
	verificar(alvo.vida == 90, "Ataque normal aplica dez de dano uma única vez")
	await quadros(30)
	corpo.lenco.dir_acao = Vector2.RIGHT
	corpo.lenco._lancar_projetil()
	await quadros(30)
	verificar(alvo.vida == 85, "Projétil aplica cinco de dano uma única vez")

	await reiniciar()
	corpo.velocity.y = -100.0
	corpo.position.y -= 30.0
	await quadros(2)
	pedido(&"ControlePropulsor", corpo.global_position + Vector2.RIGHT * 200)
	await quadros(10)
	verificar(corpo.velocity.x < -300.0, "Propulsor impulsiona no sentido contrário ao mouse")
	verificar(corpo.lenco.pontos_frente[-1].x > corpo.lenco.origem_anterior.x, "Golpe do lenço aponta para o mouse")
	verificar(corpo.lenco.usos_propulsor == 1, "Propulsor consome um uso aéreo")
	await quadros(150)
	verificar(corpo.lenco.usos_propulsor == 0, "Pouso restaura o propulsor")

	await reiniciar()
	var tecla_s := InputEventKey.new()
	tecla_s.physical_keycode = KEY_S
	tecla_s.pressed = true
	Input.parse_input_event(tecla_s)
	await quadros(2)
	verificar(corpo.esta_sentada and corpo.lenco.usos_propulsor == 0, "S no chão senta e não aciona o propulsor")
	tecla_s = InputEventKey.new()
	tecla_s.physical_keycode = KEY_S
	tecla_s.pressed = false
	Input.parse_input_event(tecla_s)
	await quadros(2)
	await apertar(&"ControleSentarLevantar")
	await soltar(&"ControleSentarLevantar")
	await quadros(60)
	verificar(not corpo.esta_sentada, "Novo aperto levanta a personagem")
	await apertar(&"ControlePular")
	await soltar(&"ControlePular")
	await quadros(12)
	await apertar(&"ControlePular")
	await quadros(3)
	verificar(corpo.planando, "Novo aperto de W no ar inicia planagem")
	verificar(corpo.get_node("Visual/Asas").visible, "Asas acompanham o início da planagem")
	await soltar(&"ControlePular")
	await quadros(3)
	verificar(not corpo.planando, "Soltar W encerra a planagem no modo segurar")

	await reiniciar()
	corpo.duracao_agradecer = 0.15
	corpo.duracao_transicao_pose = 0.12
	corpo.agradecer_ajuda()
	await quadros(3)
	corpo.definir_chapeu(true)
	await quadros(22)
	verificar(corpo.estado_pose == corpo.EstadoPose.EsperarMovimento and corpo.sprite.animation == &"EsperarChapeu", "Troca de chapéu preserva reação e espera frontal")
	await apertar(&"ControleAndarEsquerda")
	await quadros(2)
	verificar(corpo.estado_pose == corpo.EstadoPose.Saindo and corpo.sprite.flip_h, "Saída frontal espelha para o lado escolhido")
	await quadros(15)
	verificar(corpo.velocity.x < 0.0, "Movimento começa depois da transição de saída")
	await soltar(&"ControleAndarEsquerda")

	await reiniciar()
	corpo.lenco.tempo_ativo_ataque = 1.0
	pedido(&"ControleAtaqueLenco", corpo.global_position + Vector2.RIGHT * 200)
	await quadros(3)
	pedido(&"ControleAtaqueLenco", corpo.global_position + Vector2.RIGHT * 200)
	await apertar(&"ControlePular")
	await quadros(2)
	verificar(corpo.velocity.y < 0.0, "Ataque aguardando recarga não bloqueia um pulo")
	await soltar(&"ControlePular")

	await reiniciar()
	var voo = corpo.get_node("Ferramentas/VooDebug")
	await apertar(&"ControleVooDebug")
	await soltar(&"ControleVooDebug")
	await quadros(60)
	verificar(voo.forma == voo.Forma.VOANDO and not corpo.is_physics_processing(), "Voo debug pausa o coordenador normal")
	verificar(not corpo.entrada.habilitada, "Voo debug não acumula comandos de combate enquanto a personagem está oculta")
	await apertar(&"ControleVooDebug")
	await soltar(&"ControleVooDebug")
	await quadros(65)
	verificar(voo.forma == voo.Forma.NORMAL and corpo.is_physics_processing(), "Retorno do voo restaura a personagem e o lenço")
	verificar(corpo.lenco.process_mode == Node.PROCESS_MODE_INHERIT, "Lenço volta ao processamento após o voo")
	verificar(corpo.entrada.habilitada, "Entradas normais são restauradas ao encerrar o voo")

	await reiniciar()
	corpo.position = Vector2(200, -300)
	corpo.velocity = Vector2.ZERO
	await quadros(1)
	lenco = corpo.lenco
	lenco.dir_acao = Vector2.UP
	lenco._lancar_projetil()
	projetil = lenco.projeteis[0]
	projetil.global_position = corpo.global_position + Vector2(0, -150)
	projetil._comecar_espera()
	lenco._tentar_disparar_gancho(lenco.origem_anterior, projetil.global_position)
	corpo.velocity = Vector2(160, 0)
	var maior_distancia: float = 0.0
	var inicio_x: float = corpo.position.x
	for i in range(45):
		await quadros(1)
		maior_distancia = maxf(maior_distancia, corpo.global_position.distance_to(lenco.ponto_ancora_gancho))
	verificar(maior_distancia <= lenco.distancia_corda + 2.0, "Restrição do gancho mantém o corpo dentro do comprimento da corda")
	verificar(absf(corpo.position.x - inicio_x) > 10.0, "Gancho permite balanço contínuo, sem travar o movimento")
	print("TECLAS_NUMERICAS: ", KEY_KP_0, " SHIFT: ", KEY_SHIFT)
	print("RESULTADO: ", acertos, " verificações passaram; ", falhas.size(), " falhas.")
	mundo.queue_free()
	await process_frame
	quit(0 if falhas.is_empty() else 1)
