extends StaticBody2D
var vida: int = 100

# Receber dano
# ---------------------
# Recebe dano.
func receber_dano(quantidade: int) -> bool:

	vida -= quantidade
	return true
