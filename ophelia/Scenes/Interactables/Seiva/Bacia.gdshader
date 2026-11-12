shader_type canvas_item;
render_mode unshaded;
uniform float relogio=0.0;
uniform float opacidade=0.46;
uniform vec4 tom:source_color=vec4(0.51,0.87,0.91,1);
// Desenhar a água
// ---------------------
// Mantém as cores, as faixas e a transparência da versão enviada.
void fragment(){
 float x=UV.x;
 float y=UV.y;
 float t=relogio*0.4;
 vec3 base=mix(vec3(0.61,0.78,0.84),tom.rgb,0.55);
 float curva=0.12*cos(x*6.28318+t*0.4)+0.04*sin(x*12.56637-t*0.6);
 float camada1=1.0-smoothstep(0.26+curva,0.30+curva,y);
 float curva2=0.10*cos(x*6.28318+2.0-t*0.3);
 float camada2=smoothstep(0.46+curva2,0.50+curva2,y)*(1.0-smoothstep(0.73+curva,0.78+curva,y));
 vec3 cor=mix(base,vec3(0.96,0.95,1),camada1*0.35);
 cor=mix(cor,vec3(0.81,0.80,0.90),camada2*0.4);
 COLOR=vec4(cor,opacidade*(1.0-smoothstep(0.93,1.0,y)));
}
