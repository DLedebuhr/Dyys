@tool
extends Node2D

## Região da textura preservada no galho.
@export var base_preservada: PackedVector2Array = PackedVector2Array()


# Informar a região que fica no galho
# ---------------------
# Permite ao efeito ignorar a base branca do SVG original.
func obter_base_preservada() -> PackedVector2Array:

	return base_preservada


# Separar a base sem incorporar imagens
# ---------------------
# Recorta a região no shader, evitando máscaras binárias na cena.
func _ready() -> void:

	var ponta: Sprite2D = get_node_or_null("Ponta") as Sprite2D

	if ponta == null or ponta.texture == null:

		return

	if base_preservada.is_empty():

		ponta.material = null
		return

	if base_preservada.size() > 32:

		push_warning("PontoFlor: a base preservada aceita até 32 pontos.")
		return

	var shader: Shader = Shader.new()
	shader.code = """shader_type canvas_item;
uniform vec2 pontos[32];
uniform int quantidade = 0;
uniform vec2 tamanho_textura;
varying vec4 cor_no;
void vertex() { cor_no = COLOR; }
void fragment() {
    vec2 p = UV * tamanho_textura;
    bool dentro = false;
    int j = quantidade - 1;
    for (int i = 0; i < quantidade; i++) {
        vec2 a = pontos[i];
        vec2 b = pontos[j];
        if ((a.y > p.y) != (b.y > p.y)) {
            float cruzamento = (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x;
            if (p.x < cruzamento) { dentro = !dentro; }
        }
        j = i;
    }
    COLOR = texture(TEXTURE, UV) * cor_no;
    if (dentro) { COLOR.a = 0.0; }
}
"""

	var pontos: PackedVector2Array = base_preservada.duplicate()
	pontos.resize(32)

	var material_ponta: ShaderMaterial = ShaderMaterial.new()
	material_ponta.shader = shader
	material_ponta.set_shader_parameter("pontos", pontos)
	material_ponta.set_shader_parameter("quantidade", base_preservada.size())
	material_ponta.set_shader_parameter("tamanho_textura", ponta.texture.get_size())
	ponta.material = material_ponta
