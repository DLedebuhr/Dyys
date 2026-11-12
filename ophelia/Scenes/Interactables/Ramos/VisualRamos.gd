@tool
class_name VisualRamosOphelia
extends Resource

@export_group("Texturas das folhas")
@export var ramo_1: Texture2D:

	set(valor):

		ramo_1 = valor
		emit_changed()

@export var ramo_2: Texture2D:

	set(valor):

		ramo_2 = valor
		emit_changed()

@export var ramo_3: Texture2D:

	set(valor):

		ramo_3 = valor
		emit_changed()

@export var ramo_4: Texture2D:

	set(valor):

		ramo_4 = valor
		emit_changed()


@export_group("Cor adicional")
@export var cor: Color = Color.WHITE:

	set(valor):

		cor = valor
		emit_changed()



# Obter a variação da folha
# ---------------------
# Mantém cada textura no encaixe correspondente da cena.
func obter_textura(indice: int) -> Texture2D:

	match indice:

		0:

			return ramo_1

		1:

			return ramo_2

		2:

			return ramo_3

		3:

			return ramo_4

	return null
