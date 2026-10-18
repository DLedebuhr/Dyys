extends Camera2D

func _ready() -> void:
	make_current()
	process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS   # Evita tremida, o Player move na física
	position_smoothing_enabled = true
	position_smoothing_speed = 10.0
	limit_smoothed = true

	# Procura o sprite de fundo do level pelo grupo "fundo"
	var fundo := get_tree().get_first_node_in_group("fundo") as Sprite2D
	if fundo == null:
		push_warning("Camera: nenhum Sprite2D no grupo 'fundo'. Sem limites neste level.")
		return
	if fundo.texture == null:
		push_warning("Camera: o sprite '%s' não tem textura." % fundo.name)
		return

	var ret := fundo.get_rect()
	var a := fundo.to_global(ret.position)
	var b := fundo.to_global(ret.end)
	limit_left = int(minf(a.x, b.x))
	limit_right = int(maxf(a.x, b.x))
	limit_top = int(minf(a.y, b.y))
	limit_bottom = int(maxf(a.y, b.y))
