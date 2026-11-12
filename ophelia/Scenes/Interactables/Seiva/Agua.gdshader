shader_type canvas_item;
render_mode unshaded;
uniform vec4 tom : source_color = vec4(0.65,0.84,0.88,1.0);
uniform float opacidade = 0.52;
uniform float velocidade = 0.45;
uniform float comprimento = 250.0;
uniform float suavidade_inicio = 220.0;
uniform float atraso_detalhes=150.0;
uniform float tempo_caminho=250.0;
varying float distancia_real;
// Preparar as distâncias
// ---------------------
// Transporta a posição ao longo do caminho até o fragmento.
void vertex(){ distancia_real=COLOR.r*comprimento; }
uniform float clareza_final=0.65;
uniform float extensao_clara=120.0;
uniform float inicio_opacidade_final=0.78;
uniform float opacidade_final=0.65;
uniform float distancia_borda=0.0;
uniform float relogio = 0.0;
// Distância periódica contínua: a volta não cria corte horizontal de luz.
// Calcular o período contínuo
// ---------------------
// Evita um corte de luz na repetição do fluxo.
float periodo(float p){ return abs(fract(p+0.5)-0.5); }
// Desenhar a água
// ---------------------
// Mantém as cores, as faixas e a transparência da versão enviada.
void fragment(){
 float x=UV.x;
 float y=UV.y*tempo_caminho/250.0;
 float t=relogio*velocidade;
 // Bordas de camadas em U largos e desencontrados. Movimento para jusante.
 float arco1=0.13*cos(x*6.283185)+0.055*cos(x*12.56637+1.0);
 float arco2=0.12*cos(x*6.283185+2.1)+0.04*sin(x*18.84956);
 float faixa1=1.0-smoothstep(0.105,0.115,periodo(y*1.8-t*0.55-arco1));
 float faixa2=1.0-smoothstep(0.085,0.095,periodo(y*1.8-t*0.55+0.38-arco2));
 // Só os detalhes desaparecem no início; a água de base permanece visível.
 float surgimento=smoothstep(atraso_detalhes,atraso_detalhes+max(suavidade_inicio,0.01),distancia_real);
 faixa1*=surgimento;
 faixa2*=surgimento;
 vec3 base=mix(vec3(0.61,0.78,0.84),tom.rgb,0.55);
 vec3 cor=mix(base,vec3(0.96,0.95,1.0),faixa1*0.83);
 cor=mix(cor,vec3(0.81,0.80,0.90),faixa2*0.62);
 // Reflexo largo discreto, sem o padrão de fios da versão anterior.
 float reflexo=exp(-pow((x-0.28)/0.12,2.0));
 cor=mix(cor,vec3(0.96,1.0,1.0),reflexo*0.12*surgimento);
 float luz_final=(1.0-smoothstep(0.0,max(extensao_clara,1.0),comprimento-distancia_real))*clareza_final;
 cor=mix(cor,vec3(0.91,1.0,0.94),luz_final);
 float borda=smoothstep(0.0,0.025,x)*smoothstep(0.0,0.025,1.0-x);
 float progresso_queda=clamp((distancia_real-distancia_borda)/max(comprimento-distancia_borda,0.01),0.0,1.0);
 float transicao=smoothstep(min(inicio_opacidade_final,0.999),1.0,progresso_queda);
 float alfa=mix(clamp(opacidade+faixa1*0.13,0.0,1.0),opacidade_final,transicao);
 COLOR=vec4(cor,borda*alfa);
}
