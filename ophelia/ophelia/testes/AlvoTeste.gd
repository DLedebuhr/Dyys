extends StaticBody2D
var vida: int = 100
func receber_dano(quantidade: int) -> bool:
	vida -= quantidade
	return true
