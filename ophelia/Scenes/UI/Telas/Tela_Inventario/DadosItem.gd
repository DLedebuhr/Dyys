class_name DadosItemOphelia
extends Resource

enum Tipo { FRUTA, RAMO, CAPSULA, CAPSULA_SEIVA, FLOR, FLOR_ENCAPSULADA }

@export var id: StringName
@export var nome: String
@export var icone: Texture2D
@export var imagem_informacao: Texture2D
@export var arquivo_icone: String
@export var subtitulo: String
@export_multiline var descricao: String
@export var tipo: Tipo = Tipo.FRUTA
@export var estacao: StringName
@export var especie: StringName
@export_range(0, 9999, 1) var limite_pilha: int = 0 # Zero: sem limite para itens empilháveis.

# Identificar o empilhamento
# ---------------------
# Frutas, ramos e flores da mesma espécie empilham; cápsulas e flores preservadas não.
func pode_empilhar() -> bool:

	return tipo in [Tipo.FRUTA, Tipo.RAMO, Tipo.FLOR]

# Obter a capacidade da pilha
# ---------------------
# Mantém itens individuais separados e permite configurar limites para os demais.
func capacidade_pilha() -> int:

	if not pode_empilhar():

		return 1

	return limite_pilha if limite_pilha > 0 else 2147483647
