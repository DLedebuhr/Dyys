shader_type canvas_item;
render_mode blend_add, unshaded;
uniform float intensidade = 1.0;
uniform vec4 cor : source_color = vec4(0.7, 1.0, 0.85, 1.0);
void fragment() {
 vec2 uv = UV * 1.5 - vec2(0.25);
 float a = 0.0;
 if (uv.x >= 0.0 && uv.y >= 0.0 && uv.x <= 1.0 && uv.y <= 1.0) a = texture(TEXTURE, uv).a;
 float halo = 0.0;
 for (int i = 0; i < 16; i++) {
  float t = float(i) * 6.2831853 / 16.0;
  vec2 p = uv + vec2(cos(t), sin(t)) * 0.045;
  if (p.x >= 0.0 && p.y >= 0.0 && p.x <= 1.0 && p.y <= 1.0) halo += texture(TEXTURE, p).a / 16.0;
 }
 COLOR = vec4(cor.rgb * intensidade, clamp(a + halo * 0.65, 0.0, 1.0) * cor.a);
}
