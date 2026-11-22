extends RefCounted
## Transição original do Inventário aplicada ao painel COMPLETO.
## Fundo de cor é controlado exclusivamente pelo hub de inventário.
## Nada é animado individualmente: a mesma interpolação move a arte e os elementos juntos.
const DURACAO_ENTRADA: float = 0.45
const DURACAO_SAIDA: float = 0.25
const ESCALA_INICIAL: float = 0.92

var _tween: Tween
var _escala_original: Vector2 = Vector2.ONE
var _alpha_original: float = 1.0
var _raiz_registrada: Control

func _registrar(raiz: Control) -> void:
    if _raiz_registrada != raiz:
        _raiz_registrada = raiz
        _escala_original = raiz.scale
        _alpha_original = raiz.modulate.a

func abrir(raiz: Control, _primeira_abertura: bool = false, concluido: Callable = Callable(), atraso: float = 0.0) -> void:
    cancelar()
    _registrar(raiz)
    raiz.show()
    # Igual ao _centralizar() original do Inventário.
    raiz.pivot_offset = raiz.size * 0.5
    raiz.modulate.a = 0.0
    raiz.scale = _escala_original * ESCALA_INICIAL
    _tween = raiz.create_tween().set_parallel(true)
    _tween.tween_property(raiz, "modulate:a", _alpha_original, DURACAO_ENTRADA).set_delay(atraso).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    _tween.tween_property(raiz, "scale", _escala_original, DURACAO_ENTRADA).set_delay(atraso).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    if concluido.is_valid():
        _tween.finished.connect(concluido)

func fechar(raiz: Control, concluido: Callable = Callable()) -> void:
    cancelar()
    _registrar(raiz)
    _tween = raiz.create_tween().set_parallel(true)
    _tween.tween_property(raiz, "modulate:a", 0.0, DURACAO_SAIDA).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
    _tween.tween_property(raiz, "scale", _escala_original * ESCALA_INICIAL, DURACAO_SAIDA).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
    _tween.finished.connect(func() -> void:
        raiz.hide()
        if concluido.is_valid():
            concluido.call()
    )

func cancelar() -> void:
    if _tween != null and _tween.is_valid():
        _tween.kill()
