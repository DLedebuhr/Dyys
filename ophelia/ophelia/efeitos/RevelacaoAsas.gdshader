shader_type canvas_item;

uniform float progresso = 0.0;
uniform vec2 origem = vec2(0.0);
uniform vec2 eixo = vec2(1.0, 0.0);
uniform float mistura_eixo : hint_range(0.0, 1.0) = 0.0;
uniform float alcance = 40.0;
uniform float suavidade : hint_range(0.01, 1.0) = 0.3;
uniform vec4 cor_brilho : source_color = vec4(1.0, 0.9, 0.6, 1.0);
uniform float intensidade_brilho = 2.5;
uniform float brilho_geral = 0.0;
uniform float brilho_vivo = 0.3;
uniform float dobra_px = 3.5;
uniform float movimento_vel = 1.0;

varying vec2 pos_local;

void vertex() {
	pos_local = VERTEX;
}

void fragment() {
	// Distância de revelação: mistura entre um círculo em volta da origem
	// e uma varredura reta ao longo do eixo origem -> ponta
	vec2 v = pos_local - origem;
	float radial = length(v);
	float ao_longo = max(dot(v, eixo), 0.0);
	float d = mix(radial, ao_longo, mistura_eixo) / max(alcance, 0.001);

	// Dobra natural: a base fica firme e a ponta acompanha com atraso
	float peso = smoothstep(0.1, 1.0, d);
	float desloc_y = sin(TIME * movimento_vel * 2.0 - d * 3.5) * dobra_px * peso;
	vec4 base = texture(TEXTURE, UV - vec2(0.0, desloc_y) * TEXTURE_PIXEL_SIZE) * COLOR;

	// Revelação de dentro para fora
	float p = progresso * (1.0 + suavidade);
	float visivel = 1.0 - smoothstep(p - suavidade, p, d);

	// Brilho na frente da revelação
	float frente = 1.0 - smoothstep(0.0, suavidade, abs(d - (p - suavidade * 0.5)));
	float brilho = frente * sin(clamp(progresso, 0.0, 1.0) * PI);

	// Clarão depois de abrir + brilho que percorre as asas
	float onda = fract(TIME * 0.4);
	float vivo = (1.0 - smoothstep(0.0, 0.18, abs(d - onda * 1.3))) * brilho_vivo;
	float extra = (brilho_geral + vivo) * visivel;

	COLOR.rgb = base.rgb + cor_brilho.rgb * (brilho * intensidade_brilho + extra);
	COLOR.a = base.a * clamp(visivel + brilho, 0.0, 1.0);
}
