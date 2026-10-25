"""Configura o projeto uma única vez, fora do jogo; conserva as outras seções e faz backup."""
from pathlib import Path
import re,shutil,sys,datetime
project=Path(sys.argv[1] if len(sys.argv)>1 else 'project.godot').resolve()
if not project.is_file():raise SystemExit('Arquivo project.godot não encontrado. Execute na pasta do projeto ou informe seu caminho.')
source=Path(__file__).with_name('InputMap_Ophelia.cfg').read_text(encoding="utf-8")
old=project.read_text(encoding="utf-8");stamp=datetime.datetime.now().strftime('%Y%m%d_%H%M%S_%f')
backup=project.with_name('project.godot.antes_ophelia_'+stamp+'.bak');shutil.copy2(project,backup)
section=re.search(r'^\[input\]\s*\n([\s\S]*?)(?=^\[|\Z)',old,re.M)
if section:
    existing=section.group(1)
    names=re.findall(r'^(\w+)=\{',source,re.M)
    # Preserve unrelated actions; replace this character's action definitions.
    for name in names:
        existing=re.sub(r'^'+re.escape(name)+r'=\{[\s\S]*?^\}\s*\n?','',existing,flags=re.M)
    new=old[:section.start()]+'[input]\n\n'+existing.strip()+'\n\n'+source.split('\n',1)[1].strip()+'\n\n'+old[section.end():]
else:new=old.rstrip()+'\n\n'+source
layers='''[layer_names]
2d_physics/layer_1="Cenario"
2d_physics/layer_2="Personagem"
2d_physics/layer_3="Alvos"
2d_physics/layer_5="ProjeteisHostis"
2d_physics/layer_7="Interacoes"
2d_physics/layer_8="Escudo"
'''
# Existing layer names are left intact to avoid changing the rest of the game.
if '[layer_names]' not in new:new+='\n'+layers
project.write_text(new, encoding="utf-8")
print('InputMap atualizado. Backup:',backup.name)
