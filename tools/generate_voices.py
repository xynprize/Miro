"""Build-time ElevenLabs voices for Keepers, the tower PA and Niro. Never ships credentials.

    python3 tools/generate_voices.py --list           # what would be generated (no key, no credits)
    python3 tools/generate_voices.py                  # generate missing/changed clips (needs ELEVENLABS_API_KEY)
    python3 tools/generate_voices.py --design-niro    # 3 designed Niro previews -> tmp/niro_previews/*.mp3
    python3 tools/generate_voices.py --keep-niro 2    # save preview 2 as Niro's voice, then regenerate his lines

Cast and emotions: data/voice_cast.json. Clips are cached by text/voice/settings hash, so only
changed lines cost credits. Niro and PA clips are named by a hash of the subtitle text
(see scripts/remote_radio.gd), so editing a line in the JSON automatically picks up a new clip.
Use --keepers-only to refresh the Keeper cast without touching Niro or the PA,
or --miro-only to generate just Miro (dialogue and inner thoughts).
"""
import argparse, base64, hashlib, json, os, re, sys, time, urllib.error, urllib.request
from collections import defaultdict
from concurrent.futures import ThreadPoolExecutor
from threading import Lock
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
CAST = ROOT / 'data/voice_cast.json'
OUT = ROOT / 'assets/audio/voice'
API = 'https://api.elevenlabs.io/v1'
NIRO_SPEAKERS = {'NIRO', 'THE VOICE', 'BROTHER', 'A VOICE BEYOND THE BARS'}


def text_hash(text):
    return hashlib.sha1(text.strip().encode()).hexdigest()[:10]


def api_key():
    key = os.environ.get('ELEVENLABS_API_KEY')
    env = ROOT / '.env'
    if not key and env.exists():
        for line in env.read_text().splitlines():
            if line.startswith('ELEVENLABS_API_KEY='):
                key = line.split('=', 1)[1].strip().strip('"\'')
    if not key:
        raise SystemExit('ELEVENLABS_API_KEY not configured (environment or .env)')
    return key


def request(path, key, body):
    req = urllib.request.Request(API + path, data=json.dumps(body).encode(),
                                 headers={'xi-api-key': key, 'Content-Type': 'application/json'})
    for attempt in range(4):
        try:
            return urllib.request.urlopen(req, timeout=180).read()
        except urllib.error.HTTPError as error:
            detail = error.read()[:300]
            if error.code in (409, 429, 503) and attempt < 3 and b'quota' not in detail:
                time.sleep(2 ** attempt)
                continue
            raise SystemExit(f'ElevenLabs {path} failed: HTTP {error.code} {detail!r}') from None
        except urllib.error.URLError as error:
            raise SystemExit(f'ElevenLabs {path} failed: {error.reason}') from None


def niro_delivery(text, default):
    if 'Please' in text or 'Stop' in text or "Don't" in text:
        return '[pleading]'
    if text.rstrip().endswith('?'):
        return '[mocking]'
    return default


def collect_lines(cast):
    guard = json.loads((ROOT / 'data/guard_dialogue.json').read_text())
    branch = json.loads((ROOT / 'data/branch_reactions.json').read_text())
    jobs = []

    def add(clip, voice, text, delivery=''):
        jobs.append({'clip': clip, 'voice': voice, 'text': text.strip(), 'delivery': delivery})

    tags = cast['guard_delivery']
    roster = json.loads((ROOT / 'data/guard_roster.json').read_text())
    verses = json.loads((ROOT / 'data/branch_verses.json').read_text())
    voice_keys = [name.lower() for name in roster['keepers']] + ['niro', 'pa']
    voice_ids = [cast['voices'].get(name, {}).get('voice_id') for name in voice_keys]
    if not all(voice_ids) or len(set(voice_ids)) != len(voice_ids):
        raise SystemExit('Assign a separate ElevenLabs voice ID to every named Keeper, Niro and the PA.')

    def dialogue(ident, speaker, text, delivery=''):
        voice = speaker.lower()
        add(f'{voice}_{ident}', voice, text, delivery)

    for floor, conversation in guard['conversations'].items():
        speakers = roster['conversation_cast'][floor]
        for line in conversation:
            dialogue(line['id'], speakers[line['speaker']], line['text'], tags.get(line['id'], ''))
        for reputation in ('MISSING', 'HUNTED'):
            for index, text in enumerate(branch[reputation]['guard_line']):
                if reputation == 'HUNTED' and index == 0:
                    continue  # Replaced by floor-specific, confirmed-victim reports.
                clip = f'branch_{reputation.lower()}_{index}'
                dialogue(clip, speakers[index % 2], text, tags.get(clip, ''))
        for leaning, pool in verses.items():
            if leaning.startswith('_') or not pool:
                continue
            index = int(floor) % len(pool)
            for line_index, line in enumerate(pool[index]):
                clip = f'verse_{leaning}_{index}_{line_index}'
                dialogue(clip, speakers[line['speaker']], line['text'], '[quietly]')
    for speaker, profile in roster['keepers'].items():
        dialogue('alert', speaker, profile['alert'], '[shouting] ' + profile['delivery'])
        dialogue('lost', speaker, profile['lost'], '[quietly] ' + profile['delivery'])
        dialogue('body', speaker, profile['body'], '[shocked] ' + profile['delivery'])
        dialogue('sleeping', speaker, profile['sleeping'], ('[concerned] ' if profile.get('sleep_reaction') == 'concerned' else '[dryly] ') + profile['delivery'])
        for index, text in enumerate(profile['idle'], 1):
            dialogue(f'idle_{index}', speaker, text, profile['delivery'] + ' [muttering]')
    for scene_id, scene in roster['huddles'].items():
        for index, line in enumerate(scene['lines'], 1):
            dialogue(f'{scene_id}_{index}', scene['keepers'][line['speaker']], line['text'], line.get('delivery', ''))
    # Niro: every line he speaks, in person or over the remote.
    niro = []
    for path in sorted((ROOT / 'data/levels').glob('level_0*.json')):
        level = json.loads(path.read_text())
        for station in level.get('stations', []):
            for line in station.get('lines', []):
                if line[0] in NIRO_SPEAKERS:
                    niro.append(line[1])
        config = level.get('niro', {})
        for lines in config.get('appear_lines', {}).values():
            niro += [line[1] for line in lines if line[0] in NIRO_SPEAKERS]
        niro += list(config.get('retreat_lines', {}).values())
        niro += [(text, '[unhinged]') for text in config.get('taunts', [])]
    for reputation in ('MISSING', 'HUNTED'):
        niro += [branch[reputation]['remote_call'], branch[reputation]['boss_prefight']]
        niro += list(branch[reputation].get('remote_calls', {}).values())
    niro += branch['kill_disappointment']
    reactions = json.loads((ROOT / 'data/victim_reactions.json').read_text(encoding='utf-8'))
    niro += list(reactions['family_lines'].values())
    for report in reactions['reports'].values():
        for victim in report['victims']:
            dialogue('victim_' + victim.lower(), report['speaker'], victim + ' is dead.')
    niro.append('...Miro?')  # Level 1 floor report: the remote crackles.
    niro += list(json.loads((ROOT / 'data/interludes.json').read_text(encoding='utf-8')).get('floor_end_lines', {}).values())
    for scene in json.loads((ROOT / 'data/interludes.json').read_text(encoding='utf-8'))['scenes'].values():
        niro += [text for who, text in scene['lines'] if who != 'MIRO']  # between-level cinematics
        if 'hunted_first' in scene:
            niro.append(scene['hunted_first'])
    source = (ROOT / 'scripts/intro_level.gd').read_text()
    for speaker, text in re.findall(r'\["([A-Z ]+)", "((?:[^"\\]|\\.)*)"', source):
        if speaker in NIRO_SPEAKERS and '%' not in text and text not in NIRO_SPEAKERS:
            niro.append(text.replace('\\n', '\n').replace('\\"', '"'))
    # Judas, the first Keeper (Level 1 opening): stern, greedy, coughing.
    for speaker, text in re.findall(r'\["([A-Z ]+)", "((?:[^"\\]|\\.)*)"', source):
        if speaker == 'JUDAS':
            clean = text.replace('\\n', '\n').replace('\\"', '"')
            add('judas_' + text_hash(clean), 'judas', clean, '[stern] [coughs] [greedy]')
    bars = re.search(r'var response := "([^"]+)" if .* else "([^"]+)"', source)
    if bars:
        for response in bars.groups():
            niro.append("Miro. Please. Don't go any lower.\n" + response)
    seen = set()
    for entry in niro:
        text, delivery = entry if isinstance(entry, tuple) else (entry, None)
        if text.strip() in seen:
            continue
        seen.add(text.strip())
        add('niro_' + text_hash(text), 'niro', text, delivery or niro_delivery(text, cast['niro_delivery']))
    # Miro: every line he says out loud (speaker "MIRO" in any data file or script), plus his
    # inner thoughts. Dialogue clips are named by text hash like Niro's; thoughts by floor and id.
    if 'miro' in cast['voices']:
        spoken, said = [], set()

        def walk(node):
            if isinstance(node, list):
                if len(node) >= 2 and node[0] == 'MIRO' and isinstance(node[1], str):
                    spoken.append(node[1])
                for item in node:
                    walk(item)
            elif isinstance(node, dict):
                for item in node.values():
                    walk(item)

        for path in sorted((ROOT / 'data').rglob('*.json')):
            walk(json.loads(path.read_text(encoding='utf-8')))
        # Miro's two-option replies become MIRO lines when picked.
        for choice in json.loads((ROOT / 'data/dialogue_choices.json').read_text(encoding='utf-8'))['choices']:
            spoken.append(choice['prompt'])
            spoken += [option['text'] for option in choice['options']]
        for path in sorted((ROOT / 'scripts').glob('*.gd')):
            for text in re.findall(r'\["MIRO", "((?:[^"\\]|\\.)*)"', path.read_text(encoding='utf-8')):
                if '%' not in text:
                    spoken.append(text.replace('\\n', '\n').replace('\\"', '"'))
        for text in spoken:
            if text.strip() and text.strip() not in said:
                said.add(text.strip())
                add('miro_' + text_hash(text), 'miro', text, cast.get('miro_delivery', ''))
        # Floor openings and the MISSING/HUNTED thoughts are Miro thinking too.
        extra = []
        for path in sorted((ROOT / 'data/levels').glob('level_0*.json')):
            opening = json.loads(path.read_text(encoding='utf-8')).get('opening')
            if opening:
                extra.append(opening)
        extra += [branch[reputation]['thought'] for reputation in ('MISSING', 'HUNTED')]
        extra += json.loads((ROOT / 'data/interludes.json').read_text(encoding='utf-8')).get('hunt_thoughts', [])
        extra += [branch[reputation]['ending_thought'] for reputation in ('MISSING', 'HUNTED')]
        extra += [text for scene in json.loads((ROOT / 'data/interludes.json').read_text(encoding='utf-8'))['scenes'].values() for who, text in scene['lines'] if who == 'MIRO']
        for reputation in ('MISSING', 'HUNTED'):
            extra += list(branch[reputation].get('thoughts', {}).values())
        # The Z hints are Miro thinking it through: every tier, every floor.
        for path in sorted((ROOT / 'data/levels').glob('level_0*.json')):
            for tiers in json.loads(path.read_text(encoding='utf-8')).get('hints', {}).values():
                extra += [tier for tier in tiers if isinstance(tier, str)]
        level_one = (ROOT / 'scripts/intro_level.gd').read_text(encoding='utf-8')
        block = re.search(r'const L1_HINTS := [{](.*?)[\n][}]', level_one, re.S)
        if block:
            extra += [t.replace(chr(92) + 'n', chr(10)) for t in re.findall(r'"([^"]+)"', block.group(1)) if len(t) > 24]
        # Named gameplay hints are spoken thoughts as well as subtitles.
        world_features = (ROOT / 'scripts/world_features.gd').read_text(encoding='utf-8')
        extra += re.findall(r'const (?:TURRET_HINT|CAMERA_HACK_HINT) := "([^"]+)"', world_features)
        for text in extra:
            if text.strip() and text.strip() not in said:
                said.add(text.strip())
                add('miro_' + text_hash(text), 'miro', text, cast.get('miro_thought_delivery', '[whispers]'))
        thoughts = json.loads((ROOT / 'data/inner_dialogue.json').read_text(encoding='utf-8'))
        for floor, entries in thoughts.items():
            for entry in entries:
                add(f"thought_{floor}_{entry['id']}", 'miro', entry['text'], cast.get('miro_thought_delivery', '[whispers]'))
    # The sick prisoner on Level 2.
    if 'prisoner' in cast['voices']:
        def prisoners(node):
            if isinstance(node, list):
                if len(node) >= 2 and node[0] in ('PRISONER', 'THE PRISONER') and isinstance(node[1], str):
                    add('prisoner_' + text_hash(node[1]), 'prisoner', node[1], '[weak] [coughs]')
                for item in node:
                    prisoners(item)
            elif isinstance(node, dict):
                for item in node.values():
                    prisoners(item)
        for path in sorted((ROOT / 'data/levels').glob('level_0*.json')):
            prisoners(json.loads(path.read_text(encoding='utf-8')))
    # Replies a character makes after one of Miro's two-option answers.
    for choice_id, voice in (('l1_keeper', 'judas'), ('l2_sick', 'prisoner'), ('l2_offer', 'niro')):
        for choice in json.loads((ROOT / 'data/dialogue_choices.json').read_text(encoding='utf-8'))['choices']:
            if choice['id'] == choice_id:
                for option in choice['options']:
                    if 'reply' in option and voice in cast['voices']:
                        add(f'{voice}_' + text_hash(option['reply'][1]), voice, option['reply'][1],
                            {'prisoner': '[weak] [coughs]', 'niro': '[pleading]'}.get(voice, '[stern] [coughs] [greedy]'))
    # The opening cinematic's Tower PA line.
    opening_pa = json.loads((ROOT / 'data/interludes.json').read_text(encoding='utf-8'))['opening_pa']
    add('pa_' + text_hash(opening_pa), 'pa', opening_pa, '')
    for reputation in ('MISSING', 'HUNTED'):
        for key in ('pa', 'ending_pa'):
            text = branch[reputation][key]
            add('pa_' + text_hash(text), 'pa', text, '')
    return jobs


def generate(cast, jobs, key, workers=1):
    from prepare_game_audio import level
    OUT.mkdir(parents=True, exist_ok=True)
    manifest = OUT / 'provenance.json'
    records = json.loads(manifest.read_text()) if manifest.exists() else {}
    voice_locks = {name: Lock() for name in cast['voices']}

    def render(job):
        voice = cast['voices'][job['voice']]
        # Parenthetical stage directions are for the reader, not the voice.
        words = re.sub(r'\([^)]*\)', '', job['text'])
        spoken = (job['delivery'] + ' ' + words).strip().replace('\n', ' ')
        body = {'text': spoken, 'model_id': cast['model_id'],
                'voice_settings': {'stability': voice.get('stability', 0.5), 'similarity_boost': 0.75, 'use_speaker_boost': True}}
        signature = hashlib.sha256(json.dumps({'voice': voice['voice_id'], **body}, sort_keys=True).encode()).hexdigest()
        dest = OUT / (job['clip'] + '.mp3')
        if dest.exists() and records.get(job['clip'], {}).get('signature') == signature:
            return None
        raw = ROOT / 'tmp' / f"voice-{job['clip']}-{signature[:12]}.mp3"
        if not raw.exists():
            with voice_locks[job['voice']]:
                audio = request(f"/text-to-speech/{voice['voice_id']}?output_format=mp3_44100_128", key, body)
            raw.parent.mkdir(exist_ok=True)
            pending = raw.with_suffix('.tmp')
            pending.write_bytes(audio)
            pending.replace(raw)
        measurement = level(raw, dest, -18)
        return {'provider': 'ElevenLabs', 'voice_id': voice['voice_id'], 'voice_name': voice['name'],
                'model_id': cast['model_id'], 'text': job['text'], 'delivery': job['delivery'],
                'signature': signature, 'leveling': measurement}

    # Rotate voices between requests; a shared voice can only be initialized once at a time.
    by_voice = defaultdict(list)
    for job in jobs:
        by_voice[job['voice']].append(job)
    jobs = [group[index] for index in range(max(map(len, by_voice.values()), default=0))
            for group in by_voice.values() if index < len(group)]
    made = 0
    with ThreadPoolExecutor(max_workers=workers) as pool:
        # Bound pending requests so a provider error stops the batch promptly.
        for start in range(0, len(jobs), workers):
            batch = jobs[start:start + workers]
            tasks = [pool.submit(render, job) for job in batch]
            failed = []
            for job, task in zip(batch, tasks):
                try:
                    result = task.result()
                except (Exception, SystemExit) as error:
                    failed.append(f"{job['clip']}: {error}")
                    continue
                if result is not None:
                    records[job['clip']] = result
                    made += 1
                    print('Generated', job['clip'], flush=True)
            pending = manifest.with_suffix('.tmp')
            pending.write_text(json.dumps(records, indent=2) + '\n')
            pending.replace(manifest)
            if failed:
                raise SystemExit('\n'.join(failed))
    print(f'Voice library ready: {made} new clips, {len(jobs)} lines in the cast', flush=True)


def design_niro(cast, key):
    brief = cast['voices']['niro']
    body = {'voice_description': brief['design_brief'], 'model_id': 'eleven_ttv_v3', 'text': brief['design_sample']}
    previews = json.loads(request('/text-to-voice/design', key, body)).get('previews', [])
    folder = ROOT / 'tmp/niro_previews'
    folder.mkdir(parents=True, exist_ok=True)
    keep = {}
    for index, preview in enumerate(previews, 1):
        (folder / f'niro_{index}.mp3').write_bytes(base64.b64decode(preview['audio_base_64']))
        keep[str(index)] = preview['generated_voice_id']
    (folder / 'previews.json').write_text(json.dumps(keep, indent=2))
    print(f'Listen to {folder}/niro_1..{len(previews)}.mp3, then run --keep-niro <number>.')


def keep_niro(cast, key, number):
    previews = json.loads((ROOT / 'tmp/niro_previews/previews.json').read_text())
    brief = cast['voices']['niro']
    body = {'voice_name': 'Niro (Miro)', 'voice_description': brief['design_brief'], 'generated_voice_id': previews[str(number)]}
    voice_id = json.loads(request('/text-to-voice', key, body))['voice_id']
    brief['voice_id'] = voice_id
    brief['name'] = f'Niro (designed voice, preview {number})'
    CAST.write_text(json.dumps(cast, indent=2) + '\n')
    print('Niro now uses designed voice', voice_id)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--list', action='store_true')
    parser.add_argument('--keepers-only', action='store_true')
    parser.add_argument('--miro-only', action='store_true')
    parser.add_argument('--workers', type=int, choices=(1, 2, 3), default=1)
    parser.add_argument('--design-niro', action='store_true')
    parser.add_argument('--keep-niro', type=int)
    args = parser.parse_args()
    cast = json.loads(CAST.read_text())
    jobs = collect_lines(cast)
    if args.keepers_only:
        jobs = [job for job in jobs if job['voice'] not in {'niro', 'pa'}]
    if args.miro_only:
        jobs = [job for job in jobs if job['voice'] == 'miro']
    if args.list:
        for job in jobs:
            print(f"{job['clip']:<22} {job['voice']:<8} {job['delivery']} {job['text']!r}")
        print(len(jobs), 'lines')
        return
    key = api_key()
    if args.design_niro:
        return design_niro(cast, key)
    if args.keep_niro:
        keep_niro(cast, key, args.keep_niro)
    generate(cast, jobs, key, args.workers)


if __name__ == '__main__':
    main()
