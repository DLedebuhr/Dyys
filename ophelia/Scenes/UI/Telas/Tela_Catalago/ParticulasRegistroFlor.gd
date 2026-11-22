extends Control
## Mesmo princípio de FlorEmParticulas.gd: cada partícula deriva da cor e da
## posição de um pixel visível. Suporta dispersão e reconstrução no UI.
signal terminou()

var _pontos: PackedVector2Array = PackedVector2Array()
var _cores: PackedColorArray = PackedColorArray()
var _partidas: PackedVector2Array = PackedVector2Array()
var _tamanhos: PackedFloat32Array = PackedFloat32Array()
var _tempo: float = 0.0
var _duracao: float = 0.95
var _formando: bool = false
var _acabou: bool = false
var _textura_final: Texture2D
var _retangulo_final: Rect2

func iniciar(textura: Texture2D, centro: Vector2, tamanho: Vector2, formando: bool, duracao: float, limite: int = 1400) -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    process_mode = Node.PROCESS_MODE_ALWAYS
    z_index = 80
    set_anchors_preset(Control.PRESET_FULL_RECT)
    _formando = formando
    _duracao = maxf(0.15, duracao)
    _tempo = 0.0
    _acabou = false
    if textura == null:
        call_deferred("_finalizar")
        return
    _textura_final = textura if formando else null
    # Equivale ao STRETCH_KEEP_ASPECT_CENTERED dos slots do catálogo.
    var dimensoes_textura: Vector2 = textura.get_size()
    var fator: float = minf(tamanho.x / maxf(dimensoes_textura.x, 1.0), tamanho.y / maxf(dimensoes_textura.y, 1.0))
    var tamanho_ajustado: Vector2 = dimensoes_textura * fator
    _retangulo_final = Rect2(centro - tamanho_ajustado * 0.5, tamanho_ajustado)
    var imagem: Image = textura.get_image()
    if imagem == null or imagem.is_empty():
        call_deferred("_finalizar")
        return
    if imagem.is_compressed() and imagem.decompress() != OK:
        call_deferred("_finalizar")
        return
    var dim: Vector2i = imagem.get_size()
    var passo: int = maxi(1, int(ceilf(sqrt(float(dim.x * dim.y) / float(maxi(1, limite))))))
    var escala: Vector2 = _retangulo_final.size / Vector2(dim)
    var rng := RandomNumberGenerator.new()
    rng.randomize()
    for y in range(0, dim.y, passo):
        for x in range(0, dim.x, passo):
            var cor: Color = imagem.get_pixel(x, y)
            if cor.a < 0.15:
                continue
            var pos: Vector2 = centro + (Vector2(x + 0.5, y + 0.5) - Vector2(dim) * 0.5) * escala
            _pontos.append(pos)
            _cores.append(cor)
            var radial: Vector2 = (pos - centro).normalized()
            var velocidade: Vector2 = radial.rotated(rng.randf_range(-0.4, 0.4)) * rng.randf_range(18.0, 58.0)
            _partidas.append(pos + velocidade)
            _tamanhos.append(maxf(float(passo) * minf(escala.x, escala.y), 0.65))
    set_process(true)
    queue_redraw()

func _process(delta: float) -> void:
    _tempo += delta
    queue_redraw()
    if _tempo >= _duracao:
        _finalizar()

func _finalizar() -> void:
    if _acabou:
        return
    _acabou = true
    terminou.emit()
    queue_free()

func _draw() -> void:
    if _duracao <= 0.0:
        return
    var t: float = clampf(_tempo / _duracao, 0.0, 1.0)
    var suave: float = t * t * (3.0 - 2.0 * t)
    for i in range(_pontos.size()):
        var pos: Vector2
        var alfa: float
        var escala: float
        if _formando:
            pos = _partidas[i].lerp(_pontos[i], suave)
            # As partículas se apagam à medida que a arte final aparece.
            alfa = smoothstep(0.0, 0.65, t) * (1.0 - smoothstep(0.76, 1.0, t))
            escala = lerpf(0.2, 1.0, suave)
        else:
            pos = _pontos[i].lerp(_partidas[i], suave)
            alfa = 1.0 - smoothstep(0.35, 1.0, t)
            escala = lerpf(1.0, 0.12, suave)
        var lado: float = _tamanhos[i] * escala
        var cor: Color = _cores[i]
        cor.a *= alfa
        draw_rect(Rect2(pos - Vector2.ONE * lado * 0.5, Vector2.ONE * lado), cor)

    # A arte final entra sobre as partículas antes que elas sumam.
    # No último quadro, ela já é idêntica à TextureRect que será revelada.
    if _formando and _textura_final != null:
        var alfa_final: float = smoothstep(0.76, 1.0, t)
        if alfa_final > 0.0:
            draw_texture_rect(_textura_final, _retangulo_final, false, Color(1.0, 1.0, 1.0, alfa_final))
