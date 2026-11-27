"""Owner-authorized local acceptance of exactly one built-in iGentic App Shortcut.

No personal Shortcut, raw screen/tree, model invocation or permissions dialog
is selected. The external adapter is optional and runs only on the owner Mac.
"""
import asyncio
import importlib.metadata
import json
import math
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import uuid

BUNDLE = 'de.bos.neoagent.igenticdiagnostics'
SHORTCUTS = 'com.apple.shortcuts'
JOURNAL_DIR = 'Library/Application Support/iGentic'
JOURNAL = 'shortcuts-status-loop-v1.json'
TITLE = 'iGentic Status-Loop'
SIBLINGS = {'Check Local AI', 'Check Diagnostics', 'iPhone Status',
            'ChatGPT-Beispielaufgabe', 'KI-Auftrag starten', 'Agent Task Preview'}
REFERENCE_DATE = 978307200
STATE = {'physicalWifi': False, 'systemAppVerified': False, 'appGroupVerified': False,
         'nativeShortcutVisible': False, 'baselineKnown': False, 'inputAttempted': False,
         'freshFinishedJournal': False, 'rawLibraryExported': False,
         'modelCalled': False, 'permissionDialogAccepted': False}


def rows(value):
    return [p for line in value.get('rows', '').splitlines()
            if len(p := line.split('|', 4)) == 5]


def unique_target(items, labels):
    matches = [p for p in items if p[3] in labels and p[1] == 'tap'
               and p[2] == 'button']
    return matches[0][0] if len(matches) == 1 else None


def app_group_target(items, name):
    """Only an entry in the system library's Apps section, never a shortcut tile."""
    if not any(p[2] == 'heading' and p[3] in {'Mediathek', 'Library'} for p in items):
        return None
    section = None
    matches = []
    for p in items:
        if p[2] == 'heading':
            section = p[3]
        elif p[3] == name and p[1] == 'tap' and p[2] == 'button':
            matches.append((section, p[0]))
    return matches[0][1] if len(matches) == 1 and matches[0][0] == 'Apps' else None


def status_target(items, name):
    """Group title plus multiple independently registered sibling actions."""
    if not any(p[3] == name and p[2] == 'heading' for p in items):
        return None
    if len({p[3] for p in items} & SIBLINGS) < 2:
        return None
    matches = [p for p in items if p[3] == TITLE and p[1] == 'tap'
               and p[2] in {'button', 'generic'}]
    return matches[0][0] if len(matches) == 1 else None


def valid_journal(value):
    if (not isinstance(value, dict) or set(value) != {'schema', 'id', 'createdAt', 'stage'}
            or type(value['schema']) is not int or value['schema'] != 1
            or type(value['createdAt']) not in (int, float)
            or not math.isfinite(value['createdAt'])
            or value['stage'] not in {'awaitingStatus', 'readAttempted', 'awaitingFinish',
                                      'finished', 'expired', 'rejected'}):
        raise ValueError('invalidJournal')
    ident = str(uuid.UUID(value['id']))
    if ident != value['id'].lower():
        raise ValueError('invalidJournal')
    return {'id': ident, 'createdAt': value['createdAt'], 'stage': value['stage']}


def fresh_completion(before, after, started, observed):
    return (after is not None and after['stage'] == 'finished'
            and (before is None or before['id'] != after['id'])
            and started - 30 <= after['createdAt'] + REFERENCE_DATE <= observed + 30)


def core(device, args, folder):
    output = Path(folder) / 'response.json'
    output.unlink(missing_ok=True)
    p = subprocess.run(['/usr/bin/xcrun', 'devicectl', 'device', *args,
                        '--device', device, '--json-output', str(output), '--timeout', '15'],
                       capture_output=True, timeout=20)
    if p.returncode or not output.is_file():
        raise ValueError('coreDeviceFailed')
    return json.loads(output.read_text())['result']


def journal(device, folder):
    result = core(device, ['info', 'files', '--domain-type', 'appDataContainer',
                           '--domain-identifier', BUNDLE, '--subdirectory', JOURNAL_DIR,
                           '--no-recurse', '--search', JOURNAL], folder)
    files = result.get('files')
    if not isinstance(files, list) or len(files) > 1:
        raise ValueError('journalListingUnverified')
    if not files:
        return None
    dest = Path(folder) / 'journal.json'
    dest.unlink(missing_ok=True)
    core(device, ['copy', 'from', '--source', JOURNAL_DIR + '/' + JOURNAL,
                  '--domain-type', 'appDataContainer', '--domain-identifier', BUNDLE,
                  '--destination', str(dest)], folder)
    if not dest.is_file() or dest.stat().st_size > 512:
        raise ValueError('invalidJournal')
    return valid_journal(json.loads(dest.read_text()))


def app(device, bundle, folder):
    args = ['info', 'apps', '--bundle-id', bundle]
    if bundle == SHORTCUTS:
        args += ['--include-default-apps']
    matches = [a for a in core(device, args, folder)['apps']
               if a.get('bundleIdentifier') == bundle]
    if len(matches) != 1:
        raise ValueError('appIdentityUnverified')
    return matches[0]


def system_pid(device, folder):
    url = app(device, SHORTCUTS, folder).get('url')
    if not isinstance(url, str) or not url.startswith('file:') or not url.endswith('.app/'):
        raise ValueError('systemAppIdentityUnverified')
    matches = [p for p in core(device, ['info', 'processes'], folder)['runningProcesses']
               if isinstance(p.get('executable'), str) and p['executable'].startswith(url)
               and p['executable'][len(url):] and '/' not in p['executable'][len(url):]]
    if len(matches) != 1 or type(matches[0].get('processIdentifier')) is not int or matches[0]['processIdentifier'] <= 0:
        raise ValueError('systemProcessUnverified')
    return matches[0]['processIdentifier']


async def probe(device, folder):
    from oiu.coredevice import open_connection, units
    own = app(device, BUNDLE, folder)
    name = own.get('name')
    if name != 'iGentic':
        raise ValueError('unexpectedOwnAppName')
    before = journal(device, folder)
    if before and before['stage'] not in {'finished', 'expired', 'rejected'}:
        raise ValueError('pendingTaskPreserved')
    STATE['baselineKnown'] = True
    # CoreDevice's launch positional argument must follow its options.
    launch = subprocess.run(['/usr/bin/xcrun', 'devicectl', 'device', 'process', 'launch',
                             '--device', device, '--timeout', '15', SHORTCUTS],
                            capture_output=True, timeout=20)
    if launch.returncode:
        raise ValueError('systemAppLaunchFailed')
    pid = system_pid(device, folder)
    async with asyncio.timeout(70):
        async with open_connection(device) as connection:
            STATE['physicalWifi'] = connection.transport == 'Wi-Fi'
            if not STATE['physicalWifi'] or not connection.hid_available:
                return
            ax = connection.accessibility

            async def observed():
                result = await ax.refresh()
                if not result.get('ok') or ax.observed.root[0] != pid:
                    raise ValueError('wrongForegroundApp')
                STATE['systemAppVerified'] = True
                return rows(result)

            async def tap(ref):
                if not ref or ax.refs.get(ref, (None,))[0] != pid:
                    raise ValueError('unverifiedTarget')
                await connection.touch_service()
                point = await ax.checked_point(ref)
                await connection.tap(*map(units, point))
                await asyncio.sleep(.8)

            items = await observed()
            # No dialog dismissal or permission automation in the durable test.
            # Navigate from All Shortcuts to Library only when the system heading
            # and one exact back button are present.
            if any(p[2] == 'heading' and p[3] in {'Alle Kurzbefehle', 'All Shortcuts'} for p in items) or status_target(items, name):
                await tap(unique_target(items, {'Mediathek', 'Library'}))
                items = await observed()
            group = app_group_target(items, name)
            if group:
                await tap(group)
                items = await observed()
                STATE['appGroupVerified'] = True
            else:
                # An already-open group is insufficient provenance: enter it
                # from the Apps section in a separate explicit acceptance run.
                return
            ref = status_target(items, name)
            STATE['nativeShortcutVisible'] = ref is not None
            if not ref:
                return
            started = time.time()
            # Mark potential input BEFORE dispatch; no automatic retry.
            STATE['inputAttempted'] = True
            await tap(ref)
            # Read-only polling. Never re-tap or accept a system prompt.
            for _ in range(6):
                try:
                    after = await asyncio.to_thread(journal, device, folder)
                    if fresh_completion(before, after, started, time.time()):
                        STATE['freshFinishedJournal'] = True
                        STATE['taskId'] = after['id']  # local caller only
                        return
                except (ValueError, OSError, subprocess.SubprocessError):
                    pass
                await asyncio.sleep(.75)


def main():
    if len(sys.argv) != 2 or importlib.metadata.version('open-iphone-use-server') != '0.2.0':
        raise SystemExit(2)
    try:
        with tempfile.TemporaryDirectory(prefix='igentic-system-shortcut-') as folder:
            asyncio.run(probe(sys.argv[1], folder))
    except Exception as error:
        # Fixed stage flags only. Never return error text, labels or private IDs.
        STATE['blocked'] = True
    print(json.dumps(STATE))


if __name__ == '__main__':
    main()
