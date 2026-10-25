from pathlib import Path
import re,sys
root=Path(sys.argv[1] if len(sys.argv)>1 else '.').resolve()
scene=Path(__file__).resolve().parents[1]/'OPHELIA.tscn'
missing=[]
for relative in sorted(set(re.findall(r'path="(res://assets/[^"]+)"',scene.read_text(encoding="utf-8")))):
    if not (root/relative.removeprefix('res://')).is_file():missing.append(relative)
if missing:
    print('As seguintes artes da cena original não estão nesse caminho:')
    print('\n'.join(missing))
    raise SystemExit(1)
print('Todas as artes referenciadas de Ophelia foram encontradas.')
