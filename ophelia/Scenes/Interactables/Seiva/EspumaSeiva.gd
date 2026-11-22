@tool
extends Sprite2D
## Espuma feita por formas vivas. Somente as formas desenhadas pelo script
## aparecem. O Sprite2D original e as camadas SVG continuam intactos
## no projeto, mas sao ocultados enquanto este efeito esta ativo.
##
## Basta usar este arquivo no lugar do antigo EspumaSeiva.gd.
## Funciona nos tres nos Bacia1/Bacia2/Bacia3 ja existentes.

# Mantida para nao invalidar configuracoes salvas em versoes anteriores.
@export var quadros: Array[Texture2D] = []

@export_group("Espuma viva")
@export_range(0.0, 5.0, 0.05, "or_greater") var velocidade: float = 1.65
@export_range(0.0, 180.0, 1.0, "or_greater") var altura_onda: float = 78.0
@export_range(0.0, 140.0, 1.0, "or_greater") var deslizamento_lateral: float = 48.0
@export_range(0.0, 3.0, 0.05, "or_greater") var agitacao: float = 1.10
@export_range(0.0, 1.0, 0.01) var pulsacao: float = 0.14
@export_range(0.0, 1.0, 0.01) var opacidade: float = 0.94
@export var fase: float = 0.0

# As formas foram extraidas das curvas SVG Frames 44-46.
# Nao movemos, deformamos nem reimportamos os SVGs: as formas sao
# poligonos criados em tempo de execucao, com a base presa em y=162.
const ALTURA_SVG: float = 162.0
const ORIGEM_SVG: Vector2 = Vector2(-520.0, -148.0)

const CONTORNOS: Array = [
	[
		674.91, 108.09, 683.53, 98.69, 693, 90.7, 703.16, 84.18, 713.85, 79.21, 724.92, 75.85, 736.23, 74.18,
		747.62, 74.27, 758.91, 76.16, 769.93, 79.77, 780.54, 85.01, 790.59, 91.79, 799.94, 100, 808.45, 109.56,
		815.98, 120.36, 826.62, 108.7, 838.48, 99.11, 851.3, 91.74, 864.79, 86.71, 878.68, 84.18, 892.69, 84.28,
		906.55, 87.15, 919.08, 92.35, 930.9, 99.73, 941.83, 109.1, 951.68, 120.22, 960.28, 132.89, 967.44, 146.88,
		973, 162, 66, 162, 71.56, 146.88, 78.72, 132.89, 87.32, 120.22, 97.17, 109.1, 108.1, 99.73,
		119.92, 92.35, 132.45, 87.15, 146.31, 84.28, 160.32, 84.18, 174.21, 86.71, 187.7, 91.74, 200.52, 99.11,
		212.38, 108.7, 223.02, 120.36, 230.55, 109.56, 239.06, 100, 248.41, 91.79, 258.46, 85.01, 269.07, 79.77,
		280.09, 76.16, 291.38, 74.27, 302.77, 74.18, 314.08, 75.85, 325.15, 79.21, 335.84, 84.18, 346, 90.7,
		355.47, 98.69, 364.09, 108.09, 368.09, 103.57, 372.53, 99.78, 377.33, 96.76, 382.41, 94.54, 387.66, 93.18,
		393.01, 92.71, 398.36, 93.16, 403.77, 94.48, 409.21, 96.58, 414.52, 99.42, 419.53, 103, 424.05, 107.29,
		427.92, 112.27, 430.95, 117.91, 443.84, 113.85, 457.04, 112.18, 470.3, 112.82, 483.4, 115.67, 496.13, 120.63,
		508.23, 127.6, 519.5, 136.5, 530.77, 127.6, 542.87, 120.63, 555.6, 115.67, 568.7, 112.82, 581.96, 112.18,
		595.16, 113.85, 608.05, 117.91, 611.08, 112.27, 614.95, 107.29, 619.47, 103, 624.48, 99.42, 629.79, 96.58,
		635.23, 94.48, 640.64, 93.16, 645.99, 92.71, 651.34, 93.18, 656.59, 94.54, 661.67, 96.76, 666.47, 99.78,
		670.91, 103.57, 674.91, 108.09,
	],
	[
		696.82, 94.21, 706.63, 94.14, 716.37, 95.43, 725.92, 98.03, 735.13, 101.87, 743.88, 106.9, 752.03, 113.08,
		759.46, 120.34, 762.9, 116.85, 766.73, 113.92, 770.87, 111.58, 775.24, 109.88, 779.77, 108.82, 784.37, 108.46,
		788.99, 108.81, 793.64, 109.83, 798.33, 111.44, 802.91, 113.64, 807.22, 116.41, 811.11, 119.72, 814.44, 123.57,
		817.05, 127.93, 831.68, 124.2, 846.63, 123.61, 861.48, 126, 875.79, 131.2, 889.1, 139.04, 900.99, 149.37,
		911, 162, 129, 162, 139.01, 149.37, 150.9, 139.04, 164.21, 131.2, 178.52, 126, 193.37, 123.61,
		208.32, 124.2, 222.94, 127.93, 225.56, 123.57, 228.89, 119.72, 232.78, 116.41, 237.09, 113.64, 241.67, 111.44,
		246.36, 109.83, 251.01, 108.81, 255.63, 108.46, 260.23, 108.82, 264.76, 109.88, 269.13, 111.58, 273.27, 113.92,
		277.1, 116.85, 280.54, 120.34, 287.97, 113.08, 296.12, 106.9, 304.87, 101.87, 314.08, 98.03, 323.63, 95.43,
		333.37, 94.14, 343.18, 94.21, 352.9, 95.67, 362.4, 98.46, 371.53, 102.51, 380.19, 107.75, 388.25, 114.09,
		395.58, 121.48, 402.06, 129.83, 411.23, 120.81, 421.45, 113.4, 432.49, 107.71, 444.11, 103.83, 456.08, 101.87,
		468.15, 101.95, 480.09, 104.16, 486.53, 106.32, 492.77, 109.09, 498.79, 112.43, 504.56, 116.33, 510.04, 120.73,
		515.19, 125.61, 520, 130.93, 524.81, 125.61, 529.96, 120.73, 535.44, 116.33, 541.21, 112.43, 547.23, 109.09,
		553.47, 106.32, 559.91, 104.16, 571.85, 101.95, 583.92, 101.87, 595.89, 103.83, 607.51, 107.71, 618.55, 113.4,
		628.77, 120.81, 637.93, 129.83, 644.42, 121.48, 651.75, 114.09, 659.81, 107.75, 668.47, 102.51, 677.6, 98.46,
		687.1, 95.67, 696.82, 94.21,
	],
	[
		658.84, 119.13, 665.86, 119.09, 672.82, 119.9, 679.65, 121.54, 686.23, 123.97, 692.49, 127.16, 698.32, 131.07,
		703.64, 135.66, 706.1, 133.45, 708.83, 131.59, 711.79, 130.12, 714.92, 129.04, 718.16, 128.37, 721.45, 128.14,
		724.75, 128.36, 728.08, 129.01, 731.43, 130.03, 734.7, 131.42, 737.79, 133.17, 740.57, 135.27, 742.95, 137.7,
		744.82, 140.46, 755.27, 138.1, 765.97, 137.72, 776.59, 139.23, 786.82, 142.52, 796.34, 147.48, 804.84, 154.01,
		812, 162, 520, 162, 523.42, 154.61, 527.84, 147.77, 533.13, 141.58, 539.2, 136.15, 545.93, 131.57,
		553.21, 127.96, 560.94, 125.42, 569.48, 124.02, 578.11, 123.98, 586.66, 125.21, 594.97, 127.67, 602.87, 131.27,
		610.18, 135.95, 616.73, 141.65, 621.37, 136.38, 626.61, 131.71, 632.37, 127.69, 638.56, 124.38, 645.1, 121.82,
		651.89, 120.05, 658.84, 119.13,
	],
	[
		336.36, 135.66, 341.68, 131.07, 347.51, 127.16, 353.77, 123.97, 360.35, 121.54, 367.18, 119.9, 374.14, 119.09,
		381.16, 119.13, 388.11, 120.05, 394.9, 121.82, 401.44, 124.38, 407.63, 127.69, 413.39, 131.71, 418.63, 136.38,
		423.27, 141.65, 429.82, 135.95, 437.13, 131.27, 445.03, 127.67, 453.34, 125.21, 461.89, 123.98, 470.52, 124.02,
		479.06, 125.42, 486.79, 127.96, 494.07, 131.57, 500.8, 136.15, 506.87, 141.58, 512.16, 147.77, 516.58, 154.61,
		520, 162, 228, 162, 235.16, 154.01, 243.66, 147.48, 253.18, 142.52, 263.41, 139.23, 274.03, 137.72,
		284.73, 138.1, 295.18, 140.46, 297.05, 137.7, 299.43, 135.27, 302.21, 133.17, 305.3, 131.42, 308.57, 130.03,
		311.92, 129.01, 315.25, 128.36, 318.55, 128.14, 321.84, 128.37, 325.08, 129.04, 328.21, 130.12, 331.17, 131.59,
		333.9, 133.45, 336.36, 135.66,
	],
]


const CORES: Array[Color] = [
	Color(0.93, 0.93, 0.93, 0.65),
	Color(0.93, 0.93, 0.93, 0.83),
	Color(1.0, 1.0, 1.0, 0.98),
	Color(1.0, 1.0, 1.0, 0.98),
]
const FATORES: Array[float] = [1.0, 0.92, 1.20, 1.15]

var _tempo: float = 0.0
var _formas: Array[Polygon2D] = []
var _originais: Array[PackedVector2Array] = []
var _alfa_inicial: float = -1.0
var _sobreposicao: CanvasItem
var _sobreposicao_visivel: bool = true


func _ready() -> void:
	_tempo = fase
	# O script so desenha as formas movendo-se: nenhuma imagem estatica
	# fica visivel. self_modulate nao afeta os filhos Polygon2D.
	_alfa_inicial = self_modulate.a
	self_modulate.a = 0.0

	_sobreposicao = get_node_or_null("Sobreposicao") as CanvasItem
	if _sobreposicao != null:
		_sobreposicao_visivel = _sobreposicao.visible
		_sobreposicao.visible = false

	_criar_formas()
	set_process(true)


func _criar_formas() -> void:
	_formas.clear()
	_originais.clear()
	for i in range(CONTORNOS.size()):
		var nums: Array = CONTORNOS[i]
		var pontos := PackedVector2Array()
		for j in range(0, nums.size(), 2):
			pontos.append(Vector2(float(nums[j]), float(nums[j + 1])) + ORIGEM_SVG)

		# Reutiliza formas ja existentes se o script recarregar no editor.
		var nome: String = "EspumaViva_%d" % (i + 1)
		var forma: Polygon2D = get_node_or_null(nome) as Polygon2D
		if forma == null:
			forma = Polygon2D.new()
			forma.name = nome
			add_child(forma, false, Node.INTERNAL_MODE_FRONT)
		# Sem owner: formas temporarias, nao salvas na cena.
		forma.polygon = pontos
		forma.color = CORES[i]
		_formas.append(forma)
		_originais.append(pontos)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return

	_tempo += delta * velocidade
	for i in range(_formas.size()):
		var forma: Polygon2D = _formas[i]
		if not is_instance_valid(forma):
			continue

		var originais: PackedVector2Array = _originais[i]
		var atualizados := PackedVector2Array()
		var defasagem: float = float(i) * 1.73 + fase

		for ponto in originais:
			var x: float = ponto.x - ORIGEM_SVG.x
			var y: float = ponto.y - ORIGEM_SVG.y
			var distancia_base: float = maxf(0.0, ALTURA_SVG - y)

			# Parte de baixo (y=162) fica completamente fixa; o topo
			# tem movimento forte, como a ponta de um galho flexivel.
			var peso: float = clampf(distancia_base / 88.0, 0.0, 1.0)
			peso = peso * peso * (3.0 - 2.0 * peso)

			# Tres movimentos em frequencias distintas tornam as curvas
			# vivas, sem arrastar uma imagem pronta de um lado a outro.
			var onda: float = (
				0.49 * sin(x * 0.013 - _tempo * 1.75 + defasagem)
				+ 0.31 * sin(x * 0.023 + _tempo * 1.12 + defasagem * 0.71)
				+ 0.20 * sin(_tempo * 0.82 + defasagem * 1.22)
			)
			var dy: float = altura_onda * agitacao * FATORES[i] * peso * onda
			# A onda pode subir livremente, mas nao atravessa a base.
			if dy > 0.0:
				dy = minf(dy, distancia_base * 0.55)

			var curva_lateral: float = (
				0.68 * sin(x * 0.008 + _tempo * 1.35 + defasagem)
				+ 0.32 * sin(x * 0.018 - _tempo * 0.91 + defasagem * 0.81)
			)
			var dx: float = deslizamento_lateral * agitacao * peso * curva_lateral
			atualizados.append(ponto + Vector2(dx, dy))

		forma.polygon = atualizados
		var cor: Color = CORES[i]
		cor.a = clampf(
			cor.a * opacidade * (1.0 - pulsacao * 0.5 +
			sin(_tempo * 1.28 + defasagem) * pulsacao * 0.5),
			0.0, 1.0
		)
		forma.color = cor


func _exit_tree() -> void:
	# Restaura as propriedades originais no editor ao descarregar o script.
	if _alfa_inicial >= 0.0:
		self_modulate.a = _alfa_inicial
	if is_instance_valid(_sobreposicao):
		_sobreposicao.visible = _sobreposicao_visivel
	for forma in _formas:
		if is_instance_valid(forma):
			forma.queue_free()
