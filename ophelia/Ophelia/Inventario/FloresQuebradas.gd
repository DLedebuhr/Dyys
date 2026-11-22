extends Node2D
## Pétalas efêmeras das flores comuns perdidas na morte.

var quantidade: int = 0
var _tempo: float = 0.0
var _petalas: Array[Dictionary] = []

func configurar(total: int) -> void:
    quantidade = total
    var n: int = mini(72, maxi(8, total * 12))
    for i in range(n):
        var angulo: float = randf() * TAU
        var velocidade := Vector2(cos(angulo) * randf_range(22, 92), -randf_range(60, 155))
        var cor := Color(0.81, 0.87, 1.0)
        if i % 3 == 1:
            cor = Color(0.90, 0.70, 0.84)
        elif i % 3 == 2:
            cor = Color(0.65, 0.94, 0.82)
        _petalas.append({"inicio": Vector2(randf_range(-16, 16), randf_range(-35, 20)), "vel": velocidade, "cor": cor, "fase": randf() * TAU})

func _ready() -> void:
    z_index = 8

func _process(delta: float) -> void:
    _tempo += delta
    queue_redraw()
    if _tempo > 1.55:
        queue_free()

func _draw() -> void:
    var alpha: float = clampf((1.55 - _tempo) / 0.75, 0.0, 1.0)
    for p in _petalas:
        var vel: Vector2 = p["vel"]
        var pos: Vector2 = p["inicio"] + vel * _tempo + Vector2(sin(_tempo * 10.0 + float(p["fase"])) * 5.0, 90.0 * _tempo * _tempo)
        var cor: Color = p["cor"]
        cor.a = alpha
        draw_colored_polygon(PackedVector2Array([pos + Vector2(0, -4), pos + Vector2(3, 0), pos + Vector2(0, 4), pos + Vector2(-2, 0)]), cor)
