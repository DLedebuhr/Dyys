class_name CatalogoItensOphelia
extends Resource

@export var itens: Array[DadosItemOphelia] = []

# Encontrar a definição de um item
# ---------------------
# Centraliza nomes, imagens e regras sem depender do texto exibido na interface.
func obter(id: StringName) -> DadosItemOphelia:

	for item in itens:

		if item != null and item.id == id:

			return item

	return null

# Carregar os ícones da pasta escolhida
# ---------------------
# Preserva ícones manuais e procura os nomes InventarioFlor, InventarioCapsulaFlor e demais variantes.
func carregar_icones(pasta: String) -> void:

	if not DirAccess.dir_exists_absolute(pasta):

		return

	var arquivos: Dictionary = {}

	for arquivo in DirAccess.get_files_at(pasta):

		if arquivo.get_extension().to_lower() in ["png", "webp", "svg", "jpg", "jpeg"]:

			arquivos[arquivo.get_basename()] = pasta.path_join(arquivo)

	for item in itens:

		if item != null and item.icone == null and arquivos.has(item.arquivo_icone):

			item.icone = load(arquivos[item.arquivo_icone]) as Texture2D
