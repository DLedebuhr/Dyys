shader_type canvas_item;

// Controla o progresso do traçado (0.0 = invisível, 1.0 = totalmente desenhado)
uniform float progress : hint_range(0.0, 1.0) = 0.0;
// Largura da "ponta do pincel" luminosa
uniform float line_glow_size : hint_range(0.001, 0.2) = 0.08;
// Cor do brilho na ponta onde a linha está sendo desenhada
uniform vec4 glow_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	
	// Cria uma máscara de revelação do centro do símbolo para a base/pontas
	float dist = distance(UV, vec2(0.5, 0.4));
	
	// Revelação baseada na distância radial e vertical
	float reveal_val = dist * 0.6 + UV.y * 0.4;
	
	// Traço principal sendo desenhado
	float draw_mask = smoothstep(progress + line_glow_size, progress, reveal_val);
	
	// Brilho intenso na ponta da linha que está surgindo
	float glow_mask = smoothstep(progress - line_glow_size, progress, reveal_val) * 
	                  smoothstep(progress + line_glow_size, progress, reveal_val);
	
	// Mistura a textura do SVG com o brilho na ponta do traço
	vec3 final_rgb = mix(tex.rgb, glow_color.rgb, glow_mask * 2.0);
	float final_alpha = tex.a * draw_mask;
	
	COLOR = vec4(final_rgb, final_alpha);
}