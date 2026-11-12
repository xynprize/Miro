"""Place exposed turret bases against a nearby clear vertical stone face."""
def mount_turrets(data):
    tiles = {tuple(t[:2]) for t in data.get('tiles', [])}
    if not tiles:
        return
    size = data.get('tile_size', 28)
    if isinstance(size, list):size = size[0]
    def solid(x, y):
        return (int(x // size), int(y // size)) in tiles
    ladders = [a for a in data.get('interactables', []) if a.get('kind') == 'ladder']
    occupied = []
    for hazard in data.get('features', {}).get('hazards', []):
        if hazard['kind'] != 'turret':
            continue
        origin = hazard.get('legacy_position', hazard['position'])[:]
        y0 = origin[1] - (48 if origin[1] % size == 0 else 0)
        options = []
        for dy in (0, -28, 28, -56, -84):
            y = y0 + dy
            for tx, ty in tiles:
                if not ty * size <= y < (ty + 1) * size:
                    continue
                for x, direction in ((tx * size, -1), ((tx + 1) * size, 1)):
                    if not all(solid(x - direction, y + h) for h in (-14, 0, 14)):
                        continue
                    if any(solid(x + direction * w, y + h) for w in (2, 17, 34) for h in (-16, 0, 16)):
                        continue
                    if any(abs(x-a['position'][0]) < 60 and abs(y-a['position'][1]) < a.get('size',[18,196])[1]/2+30 for a in ladders):
                        continue
                    rect = (min(x,x+direction*50)-4,y-22,max(x,x+direction*50)+4,y+22)
                    blocked = False
                    for area in data.get('interactables', []):
                        if area.get('kind') not in ('exit','door','sigil'):
                            continue
                        ax,ay = area['position']
                        if rect[0] < ax+32 and rect[2] > ax-32 and rect[1] < ay+30 and rect[3] > ay-58:
                            blocked = True
                    if blocked:
                        continue
                    if any(abs(x-p[0])<48 and abs(y-p[1])<55 for p in occupied):
                        continue
                    options.append((abs(x-origin[0])+abs(dy)*3, x, y, direction))
        if options:
            _, x, y, direction = min(options)
            hazard['legacy_position'] = origin
            hazard['position'] = [x, y]
            hazard['mount'] = 'right' if direction == 1 else 'left'
            occupied.append((x,y))
