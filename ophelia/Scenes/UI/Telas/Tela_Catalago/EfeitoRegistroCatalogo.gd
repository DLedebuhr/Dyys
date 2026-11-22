extends Control
## Mini celebração de registro: ícone da flor encapsulada e cintilos ao redor.
## É apenas visual. A tela do catálogo controla a ordem e a confirmação no save.
signal terminou()

var _tempo: float = 0.0
var _duracao: float = 1.45
var _icone: TextureRect
var _brilhos: Array[Dictionary] = []
var _centro: Vector2 = Vector2(110, 110)

func iniciar(textura: Texture2D, ponto_central: Vector2, duracao: float = 1.45) -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    z_index = 70
    size = Vector2(220, 220)
    position = ponto_central - size * 0.5
    _duracao = maxf(0.6, duracao)
    _tempo = 0.0
    _brilhos.clear()
    for i in range(22):
        _brilhos.append({
            "angulo": (TAU * float(i) / 22.0) + sin(float(i) * 2.7) * 0.18,
            "raio": 47.0 + float(i % 5) * 7.0,
            "tamanho": 1.8 + float(i % 4) * 0.85,
            "inicio": float(i % 6) * 0.023,
        })
    _icone = TextureRect.new()
    _icone.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _icone.texture = textura
    _icone.size = Vector2(102, 102)
    _icone.pivot_offset = _icone.size * 0.5
    _icone.position = _centro - _icone.size * 0.5
    _icone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    _icone.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    add_child(_icone)
    set_process(true)
    queue_redraw()

func _process(delta: float) -> void:
    _tempo += delta
    var t: float = clampf(_tempo / _duracao, 0.0, 1.0)
    if is_instance_valid(_icone):
        var pulso: float = 0.72 + 0.33 * minf(1.0, t * 5.0) + sin(t * 20.0) * 0.035 * (1.0 - t)
        _icone.scale = Vector2.ONE * pulso
        _icone.modulate.a = clampf((_duracao - _tempo) / 0.35, 0.0, 1.0)
    queue_redraw()
    if _tempo >= _duracao:
        set_process(false)
        terminou.emit()
        queue_free()

func _draw() -> void:
    var t: float = clampf(_tempo / _duracao, 0.0, 1.0)
    var pulso: float = clampf(t * 5.0, 0.0, 1.0) * (1.0 - t)
    if pulso > 0.0:
        draw_arc(_centro, 30.0 + t * 47.0, 0, TAU, 40, Color(1.0, 0.77, 0.37, pulso * 0.50), 1.8, true)
    for brilho in _brilhos:
        var inicio: float = float(brilho["inicio"])
        var p: float = clampf((t - inicio) / (0.90 - inicio), 0.0, 1.0)
        if p <= 0.0 or p >= 1.0:
            continue
        var angulo: float = float(brilho["angulo"])
        var raio: float = lerpf(17.0, float(brilho["raio"]), pow(p, 0.72))
        var deslocamento: Vector2 = Vector2.RIGHT.rotated(angulo) * raio
        var c: Vector2 = _centro + deslocamento
        var alfa: float = pow(1.0 - p, 0.85)
        var tamanho: float = float(brilho["tamanho"]) * (0.7 + 0.4 * sin(p * PI))
        var cor: Color = Color(1.0, 0.91 if int(angulo * 10.0) % 2 == 0 else 0.68, 0.52, alfa)
        draw_circle(c, tamanho * 0.53, cor)
        draw_line(c + Vector2(-tamanho * 1.65, 0), c + Vector2(tamanho * 1.65, 0), cor, 1.15, true)
        draw_line(c + Vector2(0, -tamanho * 1.65), c + Vector2(0, tamanho * 1.65), cor, 1.15, true)
