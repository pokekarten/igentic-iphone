"""Local-only, bounded acceptance with an independently captured screen.
Requires the explicitly installed Open iPhone Use v0.2.0 Python environment.
Never returns a screen, tree, coordinates, labels, device ID or arbitrary action.
"""
import asyncio
import importlib.metadata
import json
import struct
import sys

STATE = {
    'physicalWifi': False, 'ownAppPidVerified': False, 'screenBefore': False, 'accessibilityBefore': False,
    'targetUnique': False, 'hidAuthorized': False, 'inputAttempted': False,
    'screenAfter': False, 'navigationVerified': False, 'rawContentExported': False
}


def expected_target(rows):
    targets = [parts[0] for line in rows.splitlines()
               if len(parts := line.split('|', 4)) == 5
               and parts[1] == 'tap' and parts[3] == 'Open local discovery']
    return targets[0] if len(targets) == 1 and 'iGentic Diagnostics' in rows else None


async def capture(rsd):
    from oiu.coredevice import SCREEN_CAPTURE_SERVICE
    from pymobiledevice3.remote.core_device.screen_capture_service import ScreenCaptureService
    if SCREEN_CAPTURE_SERVICE not in rsd.peer_info.get('Services', {}):
        return False
    async with asyncio.timeout(10):
        async with ScreenCaptureService(rsd) as service:
            b = (await service.capture_screenshot()).get('image', b'')
            return (isinstance(b, bytes) and 24 < len(b) <= 32 * 1024 * 1024
                    and b[:8] == bytes([137,80,78,71,13,10,26,10])
                    and b[12:16] == b'IHDR'
                    and all(0 < x <= 16384 for x in struct.unpack('>II', b[16:24])))


def own_target(ax, rows, expected_pid):
    target = expected_target(rows)
    root = getattr(ax.observed, 'root', None)
    key = ax.refs.get(target)
    if not root or root[0] != expected_pid or not key or key[0] != expected_pid:
        return None
    return target


async def probe(mode, device, expected_pid):
    from oiu.coredevice import open_connection, tunnel, units
    from oiu.accessibility import AccessibilitySession
    async with asyncio.timeout(55):
        if mode == 'ax':
            async with tunnel(device) as (rsd, transport):
                STATE['physicalWifi'] = transport == 'Wi-Fi'
                if not STATE['physicalWifi']:
                    return
                ax = AccessibilitySession(rsd)
                try:
                    result = await ax.refresh()
                    rows = result.get('rows', '')
                    STATE['accessibilityBefore'] = result.get('ok') is True and 'iGentic Diagnostics' in rows
                    STATE['targetUnique'] = own_target(ax, rows, expected_pid) is not None
                    STATE['ownAppPidVerified'] = STATE['targetUnique']
                finally:
                    await ax.close()
            return
        async with open_connection(device) as connection:
            STATE['physicalWifi'] = connection.transport == 'Wi-Fi'
            if not STATE['physicalWifi'] or not connection.hid_available:
                return
            STATE['screenBefore'] = await capture(connection._rsd)
            if not STATE['screenBefore']:
                return
            result = await connection.accessibility.refresh()
            rows = result.get('rows', '')
            STATE['accessibilityBefore'] = result.get('ok') is True and 'iGentic Diagnostics' in rows
            target = own_target(connection.accessibility, rows, expected_pid)
            STATE['ownAppPidVerified'] = target is not None
            STATE['targetUnique'] = target is not None
            if not STATE['accessibilityBefore'] or not target:
                return
            await connection.touch_service()
            STATE['hidAuthorized'] = True
            point = await connection.accessibility.checked_point(target)
            # Live AX admission above checks identity, geometry, visibility,
            # hit-testing and stale refs. Exactly one input, never retry.
            STATE['inputAttempted'] = True
            await connection.tap(*map(units, point))
            await asyncio.sleep(.8)
            STATE['screenAfter'] = await capture(connection._rsd)
            result = await connection.accessibility.refresh()
            rows = result.get('rows', '')
            STATE['navigationVerified'] = (
                STATE['screenAfter'] and result.get('ok') is True
                and 'Explore' in rows and 'Local discovery' in rows
                and 'Open local discovery' not in rows
                and connection.accessibility.observed.root[0] == expected_pid)


def main():
    if len(sys.argv) != 4 or sys.argv[1] not in ('ax', 'touch') or not sys.argv[3].isdigit() or int(sys.argv[3]) <= 0:
        raise SystemExit(2)
    try:
        if importlib.metadata.version('open-iphone-use-server') != '0.2.0':
            raise ValueError('unsupportedAdapterVersion')
        asyncio.run(probe(sys.argv[1], sys.argv[2], int(sys.argv[3])))
    except Exception as error:
        code = getattr(error, 'code', type(error).__name__)
        STATE['reason'] = code if code in {
            'treeUnavailable', 'accessibilityUnavailable', 'targetCovered',
            'targetChanged', 'targetNotHittable', 'staleRef', 'TimeoutError',
            'OSError', 'ValueError', 'PackageNotFoundError'
        } else 'adapterError'
    print(json.dumps(STATE))


if __name__ == '__main__':
    main()
