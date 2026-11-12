"""Authored layouts for Levels 2-4 (Ethan, 7 Nov 2026: longer, deliberate, nothing random).

Each level is two sub-floors, one per song, of three storeys each, laid out as a snake
(east, west, east | west, east, west) so every storey is a route to read and solve.
Run:  python3 tools/level_layouts.py        -> rewrites geometry/positions in data/levels/level_0N.json
                                               and writes an ASCII map to docs/level_maps/level_0N.txt
Then: godot --headless --script res://tools/build_remaining_levels.gd   (rebuilds the scenes)

Story text (stations' lines, opening, closing, sources) stays in the JSON and is never touched here.
Tiles are 28 px. A storey's floor row R has its walkable top at y = R * 28.
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
T = 28
W, H = 60, 48
# Storey floor rows: sub-floor A (song A) then sub-floor B (song B).
ROWS = [9, 16, 23, 31, 38, 45]
SUBFLOOR_B_Y = 24 * T  # landing below this switches to the level's second song


class Grid:
    def __init__(self):
        self.cells = [['.'] * W for _ in range(H)]
        self.things = []
        self.low = []  # crawlspace ceilings: (col, row)
        for row in ROWS:
            self.floor(row, 1, W - 2)
        for row in range(46, H):
            self.floor(row, 0, W - 1)
        for row in range(H):
            self.cells[row][0] = '#'
            self.cells[row][W - 1] = '#'

    def set(self, col, row, char):
        self.cells[row][col] = char

    def floor(self, row, c1, c2):
        for col in range(c1, c2 + 1):
            self.cells[row][col] = '#'

    def block(self, c1, c2, r1, r2):
        for row in range(r1, r2 + 1):
            self.floor(row, c1, c2)

    def hole(self, row, c1, c2):
        for col in range(c1, c2 + 1):
            self.cells[row][col] = '.'

    def wall(self, col, r1, r2, width=1):
        self.block(col, col + width - 1, r1, r2)

    def ladder(self, name, col, top_floor, bottom_floor, width=2):
        """Ladder from standing on top_floor down through a gap to bottom_floor."""
        for row in range(top_floor - 1, bottom_floor):
            for c in range(col, col + width):
                self.cells[row][c] = 'H'
        x = col * T + width * T / 2
        top = (top_floor - 1) * T - 4
        bottom = bottom_floor * T + 2
        self.things.append({'type': 'ladder', 'name': name, 'position': [x, (top + bottom) / 2], 'size': [40, bottom - top]})

    def trapdoor(self, col, row):
        self.cells[row][col] = '='

    def crawl(self, c1, c2, floor_row):
        """A low gap you can only pass crouched (Left Ctrl): 22 px of headroom."""
        for col in range(c1, c2 + 1):
            self.cells[floor_row - 2][col] = '#'
            self.cells[floor_row - 1][col] = '^'
            self.low.append((col, floor_row - 1))

    def put(self, what, col, floor_row, **data):
        self.things.append({'type': what, 'col': col, 'row': floor_row, **data})

    def ascii(self):
        rows = [''.join(r) for r in self.cells]
        rows = [list(r) for r in rows]
        marks = {'spawn': '@', 'exit': 'X', 'station': '*', 'guard': 'G', 'cover': 's', 'hide': 'h',
                 'case': 'a', 'port': 'p', 'camera': 'C', 'talk': 'T', 'gate': '|', 'prop': 'o', 'huddle': 'K'}
        for thing in self.things:
            if 'col' in thing and thing['type'] in marks:
                r = thing['row'] - 1 if thing['type'] != 'camera' else thing['row']
                rows[r][thing['col']] = marks[thing['type']]
        return '\n'.join(''.join(r) for r in rows)


def x_of(col):
    return col * T + T / 2


def top_of(row):
    return row * T


def compile_level(number, grid, extra):
    path = ROOT / f'data/levels/level_{number:02d}.json'
    data = json.loads(path.read_text())
    stations = {s['id']: s for s in data['stations']}
    tiles = []
    for row in range(H):
        for col in range(W):
            char = grid.cells[row][col]
            if char in '#%':
                tiles.append([col, row, 1 if (col * 7 + row * 3) % 11 == 0 else 0])
            elif char == '=':
                tiles.append([col, row, 2])
    solids = [{'name': 'LeftWall', 'position': [14, H * T / 2], 'size': [28, H * T]},
              {'name': 'RightWall', 'position': [W * T - 14, H * T / 2], 'size': [28, H * T]}]
    for index, (col, row) in enumerate(grid.low):
        solids.append({'name': f'Crawl{index}', 'position': [col * T + 14, row * T + 3], 'size': [28, 6]})
    interactables, guards, gates, props, beats = [], [], [], [], []
    features = {'hazards': [], 'cases': [], 'hides': [], 'ports': [], 'cameras': [], 'conversation': None, 'hunted_guard': None, 'huddles': []}
    spawn = None
    cover_index = 0
    for thing in grid.things:
        kind = thing['type']
        if kind == 'ladder':
            interactables.append({'name': thing['name'], 'kind': 'ladder', 'position': thing['position'], 'size': thing['size']})
            continue
        x, top = x_of(thing['col']), top_of(thing['row'])
        if kind == 'spawn':
            spawn = [x, top - 16]
        elif kind == 'exit':
            interactables.append({'name': 'StairGate', 'kind': 'exit', 'position': [x, top - 26], 'size': [46, 60]})
        elif kind == 'cover':
            cover_index += 1
            interactables.append({'name': f'Shadow{cover_index}', 'kind': 'cover', 'position': [x, top - 36], 'size': [64, 72]})
        elif kind == 'station':
            station = stations[thing['id']]
            offset = {'note': -22, 'brother': -26, 'sigil': -25}[station['kind']]
            point = [x, top + offset]
            station['position'] = point
            interactables.append({'name': thing['id'], 'kind': station['kind'], 'position': point, 'size': [40, 54]})
            beats.append({'name': f"{len(beats) + 1:02d}_{thing['id']}", 'position': point, 'purpose': station['objective']})
        elif kind == 'guard':
            guards.append({'name': thing['name'], 'position': [x, top - 16], 'patrol_left': x_of(thing['patrol'][0]),
                           'patrol_right': x_of(thing['patrol'][1]), 'sick': thing.get('sick', False)})
        elif kind == 'gate':
            rows = thing['rows']
            gates.append({'name': thing['name'], 'position': [x, (rows[0] * T + (rows[1] + 1) * T) / 2],
                          'size': [18, (rows[1] - rows[0] + 1) * T], 'unlock_milestone': thing['unlock']})
        elif kind == 'prop':
            props.append({'name': thing['name'], 'kind': thing['prop_kind'], 'position': [x, top - 16]})
        elif kind == 'case':
            features['cases'].append([x, top - 16])
        elif kind == 'hide':
            features['hides'].append({'position': [x, top - 16], 'title': thing.get('title', 'VENT')})
        elif kind == 'port':
            features['ports'].append([x, top - 16])
        elif kind == 'camera':
            features['cameras'].append({'position': [x, top + 14], 'facing': thing.get('facing', 1.57), 'linked': thing.get('linked', False)})
        elif kind in ('spikes', 'turret'):
            mount = thing.get('mount', 'floor')
            if mount == 'ceiling':
                top += T
            elif mount in ('left', 'right'):
                x += T / 2 if mount == 'right' else -T / 2
                top += T / 2
            hazard = {'kind': kind, 'position': [x, top]}
            if mount != 'floor':
                hazard['mount'] = mount
            features['hazards'].append(hazard)
        elif kind == 'talk':
            features['conversation'] = {'guard': thing['guard'], 'position': [x, top - 16]}
        elif kind == 'huddle':
            features['huddles'].append({'scene': thing['scene'], 'position': [x, top - 16]})
        elif kind == 'hunted':
            features['hunted_guard'] = {'position': [x, top - 16], 'patrol': [x_of(thing['patrol'][0]), x_of(thing['patrol'][1])]}
    data.update({
        'world_size': [W * T, H * T],
        'spawn': spawn,
        'floor_rows': [],
        'shelves': [],
        'tiles': tiles,
        'solids': solids,
        'interactables': interactables,
        'guards': guards,
        'gates': gates,
        'beats': beats,
        'features': features,
        'storeys': [top_of(r) for r in ROWS],
        'route': extra['route'],
        'hints': extra['hints'],
    })
    if props:
        data['props'] = props
    data['music_region']['entry'] = {'minimum_y': SUBFLOOR_B_Y, 'requires_landing': True, **extra.get('music_entry', {})}
    from wall_turrets import mount_turrets
    mount_turrets(data)
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + '\n')
    maps = ROOT / 'docs/level_maps'
    maps.mkdir(parents=True, exist_ok=True)
    legend = ('# wall/floor  = trapdoor  H ladder  ^ crawlspace (crouch)  | gate  @ start  X exit\n'
              '* objective  G Keeper  T overheard Keepers  K off-duty huddle  s shadow  h hiding spot  a ammo  p service port  C camera  o prop\n')
    (maps / f'level_{number:02d}.txt').write_text(f"Level {number}: {data['title']}\n{legend}\n{grid.ascii()}\n")
    print(f'level_{number:02d}: {len(tiles)} tiles, {len(guards)} Keepers, {len(interactables)} interactables')


# ---------------------------------------------------------------------------------------------
# Level 2: The Symptoms. A (DOPE 2): the sick corridor. B (Swag): the Keepers' barracks.
# Teaches: patrol timing, shadows, crouch-crawl, the double-jump step, a service port and
# practice camera, trapdoor shortcuts, lockers.
def level_2():
    g = Grid()
    # S1 (row 9, east): cells of the sick; spawn at the stair from Level 1.
    g.put('spawn', 3, 9)
    g.put('station', 9, 9, id='SickPrisoner')
    g.put('prop', 11, 9, name='SymptomaticPrisoner', prop_kind='sick_prisoner')
    g.block(13, 13, 8, 8)                 # a slop bucket crate: hop over
    g.put('cover', 15, 9)
    g.put('guard', 22, 9, name='WardKeeper', patrol=[18, 28], sick=True)
    g.put('cover', 30, 9)
    g.wall(34, 0, 6, width=2)           # the cell block wall; the only way on is the crawl
    g.crawl(34, 35, 9)
    g.put('station', 42, 9, id='BrotherOffer')
    g.put('cover', 39, 9)
    g.ladder('FirstLadder', 47, 9, 16)
    g.block(52, 54, 7, 8)                 # a raised bunk to climb for the ammo case
    g.put('case', 53, 7)
    g.put('huddle', 56, 9, scene='john316')  # three off-duty Keepers over a Bible; climb the bunk behind them
    # S2 (row 16, west): the corridor of beds.
    g.put('guard', 38, 16, name='CorridorKeeper', patrol=[29, 43])
    g.block(44, 45, 14, 15)               # a two-tile step right off the ladder: double jump
    g.put('hide', 33, 16, title='VENT')
    g.put('cover', 25, 16)
    g.put('hide', 27, 16, title='CRATE')   # stand on it, or hide inside [E]
    g.put('port', 21, 16)
    g.block(18, 18, 15, 15)               # an empty bed frame: hop over
    g.put('camera', 15, 10, facing=1.9)
    g.put('cover', 11, 16)
    g.hole(16, 6, 7)                      # a drop into the laundry below (one way)
    # S3 (row 23, east): the laundry and the Keepers' conversation.
    g.put('cover', 12, 23)
    g.put('talk', 22, 23, guard='LaundryKeeper')
    g.put('guard', 22, 23, name='LaundryKeeper', patrol=[20, 30])
    g.put('cover', 33, 23)
    g.crawl(36, 36, 23)                   # a low drying rack: crawl under (or climb on it)
    g.block(40, 41, 21, 22)               # a stack of linen crates: double jump over
    g.put('hide', 45, 23, title='LAUNDRY BIN')
    g.trapdoor(49, 23)                    # optional shortcut down; the ladder is the safe way
    g.ladder('SecondLadder', 54, 23, 31)
    # S4 (row 31, west): the barracks. Song B starts on landing.
    g.put('guard', 44, 31, name='BarracksKeeper', patrol=[36, 50])
    for col in (46, 40, 34, 28):          # top bunks: Keepers walk under; lie up here and they can't see you
        g.block(col, col + 2, 29, 29)
    g.put('cover', 38, 31)
    g.put('guard', 24, 31, name='SleepyKeeper', patrol=[18, 30], sick=True)
    g.put('hide', 16, 31, title='LOCKER')
    g.put('case', 9, 31)
    g.trapdoor(26, 31)
    g.ladder('ThirdLadder', 3, 31, 38)
    # S5 (row 38, east): the quartermaster's office on a raised floor.
    g.block(6, 6, 37, 37)                 # a ration crate: hop over
    g.put('cover', 9, 38)
    g.put('guard', 18, 38, name='StoresKeeper', patrol=[12, 24])
    g.block(27, 36, 36, 37)               # the office dais: two-tile step up
    g.put('station', 31, 36, id='TransferLedger')
    g.put('cover', 34, 36)
    g.put('guard', 45, 38, name='DutyKeeper', patrol=[40, 51])
    g.put('cover', 49, 38)
    g.ladder('FourthLadder', 55, 38, 45)
    # S6 (row 45, west): the lower support and the stairs down.
    g.block(52, 52, 43, 44)               # stacked sacks: double jump
    g.put('cover', 50, 45)
    g.put('guard', 38, 45, name='LowerKeeper', patrol=[30, 46])
    g.put('hunted', 30, 45, patrol=[24, 36])
    g.put('cover', 27, 45)
    g.wall(22, 39, 42)                    # a support pillar: crawl under its brace
    g.crawl(22, 22, 45)
    g.put('station', 16, 45, id='SecondSigil')
    g.put('cover', 9, 45)
    g.put('turret', 29, 16)
    g.put('turret', 43, 38)
    g.put('turret', 35, 6, mount='right')
    g.put('spikes', 12, 31)
    g.put('spikes', 22, 38)
    g.put('spikes', 34, 7, mount='left')
    g.put('spikes', 35, 29, mount='ceiling')
    # Playtest round 2: more shadows past the sick prisoner.
    g.put('cover', 20, 9)
    g.put('cover', 25, 9)
    g.put('guard', 29, 9, name='CellKeeper', patrol=[24, 32])  # added last: keeps roster order
    g.put('guard', 21, 9, name='InfirmaryKeeper', patrol=[19, 23])
    g.put('guard', 32, 9, name='GateKeeper', patrol=[31, 33])
    # Playtest round 3: more Keepers between the beds, laundry, barracks, stores and the vault.
    g.put('guard', 14, 16, name='RoundsKeeper', patrol=[10, 18])
    g.put('guard', 49, 16, name='StairKeeper', patrol=[46, 52])
    g.put('guard', 35, 23, name='LinenKeeper', patrol=[32, 39])
    g.put('guard', 47, 23, name='DryerKeeper', patrol=[44, 51])
    g.put('guard', 12, 31, name='BunkKeeper', patrol=[10, 16])
    g.put('guard', 32, 36, name='OfficeKeeper', patrol=[29, 35])   # on the raised dais
    g.put('guard', 14, 45, name='VaultKeeper', patrol=[11, 19])
    g.put('turret', 0, 14, mount='right')   # a wall turret on the west wall of the beds corridor
    g.put('cover', 33, 9)
    g.put('exit', 3, 45)
    route = [
        {'x': x_of(9)}, {'station': 'SickPrisoner'},
        {'x': x_of(33)}, {'x': x_of(37), 'crouch': True},
        {'x': x_of(42)}, {'station': 'BrotherOffer'},
        {'climb': 'FirstLadder', 'to': top_of(16)},
        {'x': x_of(8)}, {'x': x_of(6.5)}, {'fall': top_of(23)},
        {'x': x_of(35)}, {'x': x_of(37.5), 'crouch': True},
        {'x': x_of(54.5)}, {'climb': 'SecondLadder', 'to': top_of(31)},
        {'x': x_of(37)}, {'x': x_of(33), 'crouch': True},
        {'x': x_of(3.5)}, {'climb': 'ThirdLadder', 'to': top_of(38)},
        {'x': x_of(31)}, {'station': 'TransferLedger'},
        {'x': x_of(55.5)}, {'climb': 'FourthLadder', 'to': top_of(45)},
        {'x': x_of(24)}, {'x': x_of(20), 'crouch': True},
        {'x': x_of(16)}, {'station': 'SecondSigil'},
        {'x': x_of(3)}, {'exit': True},
    ]
    hints = {
        'SickPrisoner': ["Someone is coughing in the first cell. Just look before you run.",
                         "Walk right a few steps from the stairs. The sick prisoner is in the first cell. [E]",
                         "Stand beside the coughing man, just right of where you came in, and press E."],
        'BrotherOffer': ["The wall ahead has a gap at the bottom. Too low to walk through.",
                         "Hold Left Ctrl to crouch and crawl under the cell block wall.",
                         "Crawl under the wall, then follow the voice at the bars on the far side. [E]"],
        'TransferLedger': ["The ledger will be somewhere they keep paperwork. Lower down, in the barracks.",
                           "Ladder down, drop through the gap by the store room, then take the long ladder past the laundry.",
                           "In the barracks, take the ladder at the far left, then climb onto the raised office. The ledger is on the desk. [E]"],
        'SecondSigil': ["The support is on the lowest floor. One more ladder.",
                        "From the office, keep right to the last ladder, then head left along the bottom.",
                        "Crouch under the pillar's brace (Left Ctrl). The support is just past it. [E]"],
        'exit': ["The stairs down are at the far left of the bottom floor.",
                 "Keep going left past the support. [E] at the stair gate.",
                 "Bottom floor, far left wall. Press E at the stairs."],
    }
    compile_level(2, g, {'route': route, 'hints': hints})


# ---------------------------------------------------------------------------------------------
# Level 3: The Order. A (Bobblehead): the approach, overhearing the password, cameras.
# B (Cyberpunk): past the checkpoint, the rank record, Niro's reveal.
def level_3():
    g = Grid()
    # S1 (row 9, east): the records corridor under a camera.
    g.put('spawn', 3, 9)
    g.put('cover', 9, 9)
    g.block(13, 13, 8, 8)                 # a box of files: hop over
    g.put('camera', 16, 1, facing=1.75, linked=True)
    g.put('cover', 20, 9)
    g.put('hide', 22, 9, title='CRATE')
    g.put('guard', 28, 9, name='OfficeKeeper', patrol=[24, 32])
    g.block(36, 37, 7, 8)                 # filing cabinets: double jump
    g.put('cover', 40, 9)
    g.wall(43, 0, 6, width=2)             # the vent under the office wall
    g.crawl(43, 44, 9)
    g.put('hide', 48, 9, title='VENT')
    g.ladder('FirstLadder', 52, 9, 16)
    # S2 (row 16, west): two Keepers at the stairs talk about the terminal.
    g.put('cover', 46, 16)
    g.put('hide', 40, 16, title='CABINET')
    g.put('cover', 35, 16)
    g.put('talk', 30, 16, guard='ListenKeeper')
    g.put('guard', 30, 16, name='ListenKeeper', patrol=[28, 34])
    g.put('cover', 23, 16)
    g.block(25, 25, 15, 15)               # a mail cart: hop over
    g.put('camera', 18, 10, facing=1.35, linked=True)
    g.put('guard', 13, 16, name='StairKeeper', patrol=[9, 19])
    g.ladder('SecondLadder', 3, 16, 23)
    # S3 (row 23, east): the checkpoint itself. The terminal opens the gate to the stairwell.
    g.put('cover', 9, 23)
    g.put('station', 16, 23, id='RemoteTerminal')
    g.put('guard', 27, 23, name='TerminalKeeper', patrol=[22, 33])
    g.put('cover', 36, 23)
    g.block(39, 39, 21, 22)               # a barrier stack at the checkpoint: double jump
    g.put('gate', 44, 23, name='CheckpointGate', rows=[17, 22], unlock='RemoteTerminal')
    g.put('case', 49, 23)
    g.ladder('ThirdLadder', 54, 23, 31)
    # S4 (row 31, west): Cyberpunk. The security office and the rank record.
    g.put('cover', 50, 31)
    g.put('camera', 44, 24, facing=1.45, linked=False)
    g.put('guard', 41, 31, name='CheckKeeper', patrol=[36, 47])
    g.block(26, 33, 29, 30)               # the raised security office
    g.put('station', 30, 29, id='RankRecord')
    g.put('cover', 28, 29)
    g.put('guard', 18, 31, name='ArchiveKeeper', patrol=[12, 23])
    g.put('hide', 9, 31, title='CABINET')
    g.ladder('FourthLadder', 3, 31, 38)
    # S5 (row 38, east): the holding bars; the voice has a face.
    g.block(7, 7, 37, 37)                 # a toppled chair: hop over
    g.put('cover', 10, 38)
    g.wall(17, 32, 35, width=2)           # a low pipe run: crawl under
    g.crawl(17, 18, 38)
    g.put('station', 28, 38, id='BrotherReveal')
    g.put('cover', 33, 38)
    g.put('guard', 42, 38, name='BarsKeeper', patrol=[37, 47])
    g.trapdoor(46, 38)
    g.ladder('FifthLadder', 54, 38, 45)
    # S6 (row 45, west): the support and the stairs.
    g.put('cover', 49, 45)
    g.put('guard', 43, 45, name='LowerKeeper', patrol=[37, 49])
    g.put('hunted', 33, 45, patrol=[29, 38])
    g.put('cover', 30, 45)
    g.put('station', 23, 45, id='ThirdSigil')
    g.block(14, 15, 43, 44)               # crates before the stairs
    g.put('cover', 9, 45)
    g.put('turret', 34, 23)
    g.put('turret', 31, 45)
    g.put('turret', 46, 23, mount='ceiling')
    g.put('spikes', 32, 9)
    g.put('spikes', 35, 38)
    g.put('spikes', 43, 7, mount='left')
    g.put('spikes', 51, 9, mount='ceiling')
    g.put('exit', 3, 45)
    route = [
        {'x': x_of(41)}, {'x': x_of(46), 'crouch': True},
        {'climb': 'FirstLadder', 'to': top_of(16)},
        {'x': x_of(35)}, {'wait_for_password': True},
        {'climb': 'SecondLadder', 'to': top_of(23)},
        {'x': x_of(16)}, {'station': 'RemoteTerminal'},
        {'climb': 'ThirdLadder', 'to': top_of(31)},
        {'x': x_of(30)}, {'station': 'RankRecord'},
        {'climb': 'FourthLadder', 'to': top_of(38)},
        {'x': x_of(16)}, {'x': x_of(20), 'crouch': True},
        {'x': x_of(28)}, {'station': 'BrotherReveal'},
        {'climb': 'FifthLadder', 'to': top_of(45)},
        {'x': x_of(23)}, {'station': 'ThirdSigil'},
        {'x': x_of(3)}, {'exit': True},
    ]
    hints = {
        'RemoteTerminal': ["The terminal wants a password. The Keepers will have it written in their heads.",
                           "Two Keepers stand talking on the floor below the vent. Hide close by and listen.",
                           "Overhear the password on the second floor, then take the left ladder down. The terminal is just past the first shadow. [E]"],
        'RankRecord': ["The gate's open. The checkpoint stairs lead down to the security office.",
                       "Past the gate, take the ladder down, then go left to the raised office.",
                       "Jump onto the raised office (double jump) and read the record on the desk. [E]"],
        'BrotherReveal': ["The voice is close now. Further down.",
                          "Take the ladder at the far left of the office floor, then crouch under the pipes (Left Ctrl).",
                          "Past the pipes, the bars are in the middle of the floor. Stand at them. [E]"],
        'ThirdSigil': ["The support is on the lowest floor.",
                       "Right to the last ladder, then down and left.",
                       "Bottom floor, middle. Plant the sigil at the support. [E]"],
        'exit': ["The stairs are at the far left.", "Over the crates, keep left.", "Bottom floor, far left wall. [E]"],
    }
    compile_level(3, g, {'route': route, 'hints': hints})


# ---------------------------------------------------------------------------------------------
# Level 4: The Ward. A (Plane Drums): the outer ward, records, the seal release.
# B (Sum Crazy Shi): deep containment, the chamber, Niro's warning, the charges.
def level_4():
    g = Grid()
    # S1 (row 9, east): the outer ward's records.
    g.put('spawn', 3, 9)
    g.put('cover', 8, 9)
    g.put('station', 14, 9, id='ExperimentRecords')
    g.block(18, 18, 8, 8)                 # a sharps bin: hop over
    g.put('guard', 25, 9, name='RecordsKeeper', patrol=[20, 31], sick=True)
    g.put('cover', 34, 9)
    g.block(38, 39, 7, 8)                 # a gurney stack: double jump
    g.put('hide', 44, 9, title='SHOWER')
    g.ladder('FirstLadder', 50, 9, 16)
    g.put('spikes', 31, 9)
    # S2 (row 16, west): sealed observation rooms; the release is up on the gantry.
    g.put('cover', 45, 16)
    g.put('guard', 37, 16, name='WatchKeeper', patrol=[30, 44])
    g.put('cover', 27, 16)
    g.wall(22, 10, 13, width=2)           # an observation window frame: crawl under its sill
    g.crawl(22, 23, 16)
    g.block(9, 15, 14, 15)                # the release gantry
    g.put('station', 12, 14, id='WardRelease')
    g.put('case', 14, 14)
    g.ladder('SecondLadder', 3, 16, 23)
    # S3 (row 23, east): the sealed ward doors.
    g.put('cover', 9, 23)
    g.put('guard', 16, 23, name='DoorKeeper', patrol=[12, 22])
    g.put('cover', 25, 23)
    g.put('hide', 27, 23, title='CRATE')
    g.put('gate', 30, 23, name='WardSeal', rows=[17, 22], unlock='WardRelease')
    g.block(34, 34, 22, 22)               # a linen trolley: hop over
    g.put('hide', 38, 23, title='SHOWER')
    g.put('guard', 45, 23, name='SealKeeper', patrol=[40, 50], sick=True)
    g.ladder('ThirdLadder', 54, 23, 31)
    g.put('spikes', 11, 23)
    # S4 (row 31, west): deep containment and the isolation chamber.
    g.put('cover', 50, 31)
    g.put('guard', 46, 31, name='ChamberKeeper', patrol=[42, 51])
    g.put('station', 38, 31, id='ContainmentEvidence')
    g.block(34, 34, 29, 30)               # a stacked oxygen cage: double jump
    g.put('prop', 31, 31, name='IsolationChamber', prop_kind='ward_chamber')
    g.put('cover', 25, 31)
    g.put('guard', 18, 31, name='TankKeeper', patrol=[12, 23])
    g.put('hide', 8, 31, title='CABINET')
    g.ladder('FourthLadder', 3, 31, 38)
    g.put('turret', 44, 31)
    # S5 (row 38, east): the ward support and Niro at the glass.
    g.put('cover', 9, 38)
    g.put('station', 16, 38, id='BrotherWarning')
    g.put('station', 22, 38, id='WardChargeWest')
    g.block(27, 28, 36, 37)               # a fallen cabinet
    g.put('guard', 37, 38, name='WardKeeper', patrol=[32, 43])
    g.put('cover', 46, 38)
    g.trapdoor(49, 38)
    g.ladder('FifthLadder', 54, 38, 45)
    # S6 (row 45, west): the lower support, the sigil, the stairs.
    g.put('cover', 50, 45)
    g.put('station', 44, 45, id='WardChargeLower')
    g.block(47, 47, 44, 44)               # a dropped tray cart: hop over
    g.put('guard', 36, 45, name='LowerKeeper', patrol=[30, 41])
    g.put('hunted', 22, 45, patrol=[18, 27])
    g.wall(26, 39, 42)
    g.crawl(26, 26, 45)
    g.put('station', 14, 45, id='FourthSigil')
    g.put('cover', 9, 45)
    g.put('turret', 32, 16)
    g.put('turret', 42, 38)
    g.put('turret', 23, 12, mount='right')
    g.put('spikes', 20, 23)
    g.put('spikes', 33, 45)
    g.put('spikes', 23, 13, mount='right')
    g.put('spikes', 49, 9, mount='ceiling')
    g.put('exit', 3, 45)
    route = [
        {'x': x_of(14)}, {'station': 'ExperimentRecords'},
        {'climb': 'FirstLadder', 'to': top_of(16)},
        {'x': x_of(25)}, {'x': x_of(20), 'crouch': True},
        {'x': x_of(12)}, {'station': 'WardRelease'},
        {'climb': 'SecondLadder', 'to': top_of(23)},
        {'climb': 'ThirdLadder', 'to': top_of(31)},
        {'x': x_of(38)}, {'station': 'ContainmentEvidence'},
        {'climb': 'FourthLadder', 'to': top_of(38)},
        {'x': x_of(16)}, {'station': 'BrotherWarning'},
        {'x': x_of(22)}, {'station': 'WardChargeWest'},
        {'climb': 'FifthLadder', 'to': top_of(45)},
        {'x': x_of(44)}, {'station': 'WardChargeLower'},
        {'x': x_of(28)}, {'x': x_of(24), 'crouch': True},
        {'x': x_of(14)}, {'station': 'FourthSigil'},
        {'x': x_of(3)}, {'exit': True},
    ]
    hints = {
        'ExperimentRecords': ["Records first. They're close to where I came in.",
                              "A few steps right of the stairs, by the first desk. [E]",
                              "Walk right from the start. The experiment records are on the first desk. [E]"],
        'WardRelease': ["The ward is sealed. There has to be a manual release somewhere above it.",
                        "Ladder down, then go left. Crouch under the window sill (Left Ctrl).",
                        "The release is on the raised gantry at the far left of the second floor. Double jump up. [E]"],
        'ContainmentEvidence': ["The seal's open. The way down is past the ward doors.",
                                "Ladder down at the left, go right through the opened seal, then the last ladder.",
                                "In containment, the evidence is just right of the chamber. [E]"],
        'BrotherWarning': ["He's watching from somewhere below the chamber.",
                           "Take the ladder at the far left of containment.",
                           "He's at the glass, a few steps right of the ladder. [E]"],
        'WardChargeWest': ["Two charges on the ward support.", "The support is right next to the glass.",
                           "Stand at the support beside the glass and press E (two charges)."],
        'WardChargeLower': ["Two more charges, on the lower support.", "Right to the last ladder, then down.",
                            "Bottom floor, near the ladder: the lower support. [E]"],
        'FourthSigil': ["One mark left on this floor.", "Go left; crouch under the brace (Left Ctrl).",
                        "Past the brace, the sigil support is on the left. [E]"],
        'exit': ["The stairs are at the far left.", "Keep going left.", "Bottom floor, far left wall. [E]"],
    }
    compile_level(4, g, {'route': route, 'hints': hints, 'music_entry': {'requires_milestone': 'WardRelease'}})


if __name__ == '__main__':
    level_2()
    level_3()
    level_4()
