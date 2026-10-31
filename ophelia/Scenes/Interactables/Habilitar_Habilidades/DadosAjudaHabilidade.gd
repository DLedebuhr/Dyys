class_name OpheliaDadosAjudaHabilidade
extends Resource
## Um recurso por habilidade; pode ser salvo em .tres e reutilizado.
@export_enum("AtaqueLenco", "AtaqueModificado", "DefesaLenco", "Planar", "AgarrarObjeto", "Propulsor") var habilidade: String = "AtaqueLenco"
@export var elementos: Texture2D # Imagem completa com título, desenhos e explicação.
@export var video: VideoStream # .ogv; prioridade sobre a demonstração em textura.
@export var demonstracao: Texture2D # Opcional: imagem fixa ou AnimatedTexture.
