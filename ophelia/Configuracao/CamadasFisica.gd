class_name CamadasFisica
extends RefCounted
const CENARIO_SOLIDO: int = 1 << 0
const JOGADOR: int = 1 << 1
const OBJETOS_MOVEIS: int = 1 << 2
const INIMIGOS: int = 1 << 3
const RECEBE_DANO: int = 1 << 4
const PERIGOS: int = 1 << 5
const INTERAGIVEIS: int = 1 << 6
const COLETAVEIS: int = 1 << 7
const APOIOS_LENCO: int = 1 << 8
const ATAQUES_JOGADOR: int = 1 << 9
const DEFESA_JOGADOR: int = 1 << 10
const PROJETEIS_HOSTIS: int = 1 << 11
const SOLIDOS: int = CENARIO_SOLIDO | OBJETOS_MOVEIS | INIMIGOS
const GANCHO: int = CENARIO_SOLIDO | OBJETOS_MOVEIS | APOIOS_LENCO
const NOMES: PackedStringArray = ["CenarioSolido", "Jogador", "ObjetosMoveis", "Inimigos", "RecebeDano", "Perigos", "Interagiveis", "Coletaveis", "ApoiosLenco", "AtaquesJogador", "DefesaJogador", "ProjeteisHostis"]
