@tool
class_name CatalogoFrutasOphelia
extends Resource

enum Estacao { PRIMAVERA, VERAO, OUTONO, INVERNO }

@export var primavera: Texture2D
@export var verao: Texture2D
@export var outono: Texture2D
@export var inverno: Texture2D

@export_group("Cor do rastro de queda")
@export var cor_primavera: Color = Color("6d0952ff")
@export var cor_verao: Color = Color("c00034ff")
@export var cor_outono: Color = Color("c63e0dff")
@export var cor_inverno: Color = Color("121222ff")

# Obter a textura da estação
# ---------------------
# Retorna a imagem compartilhada da fruta selecionada.
func obter_textura(estacao: int) -> Texture2D:

	match estacao:

		Estacao.PRIMAVERA:

			return primavera

		Estacao.VERAO:

			return verao

		Estacao.OUTONO:

			return outono

		Estacao.INVERNO:

			return inverno

	return null

# Identificar a estação
# ---------------------
# Usa os mesmos identificadores que o estoque de Vitalidade.
static func identificar(estacao: int) -> StringName:

	var nomes: Array[StringName] = [&"Primavera", &"Verao", &"Outono", &"Inverno"]
	return nomes[clampi(estacao, 0, nomes.size() - 1)]

# Obter a cor do rastro
# ---------------------
# Usa a cor configurada para a fruta da estação.
func obter_cor(estacao: int) -> Color:

	var cores: Array[Color] = [cor_primavera, cor_verao, cor_outono, cor_inverno]
	return cores[clampi(estacao, 0, 3)]
