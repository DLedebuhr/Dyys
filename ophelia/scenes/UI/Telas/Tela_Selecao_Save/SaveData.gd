class_name SaveData
extends Resource

@export var slot_index: int = 0
@export var progresso_fase: int = 0 # Varia de 0 a 6 (para as 7 texturas)
@export var mundo_atual: int = 1

func existe_save() -> bool:
	return progresso_fase > 0 or mundo_atual > 1
