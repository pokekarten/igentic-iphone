import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location('system_shortcut_probe',
    Path(__file__).resolve().parents[1] / 'scripts' / 'system-shortcut-probe.py')
probe = importlib.util.module_from_spec(spec)
spec.loader.exec_module(probe)

def row(ref, label, role='button', action='tap'):
    return [ref, action, role, label, '']

class TestSystemShortcut(unittest.TestCase):
    def test_only_unique_app_group_in_apps_section(self):
        library = row('a', 'Mediathek', 'heading', 'read')
        apps = row('b', 'Apps', 'heading', 'read')
        igentic = row('c', 'iGentic')
        self.assertEqual(probe.app_group_target([library, apps, igentic], 'iGentic'), 'c')
        for wrong in [[library, igentic, apps], [library, apps, igentic, igentic],
                      [apps, igentic], [library, apps, row('d', 'Folder', 'heading','read'), igentic]]:
            self.assertIsNone(probe.app_group_target(wrong, 'iGentic'))

    def test_status_requires_group_and_registered_siblings(self):
        heading = row('a', 'iGentic', 'heading', 'read')
        status = row('b', probe.TITLE, 'generic')
        siblings = [row('c', 'Check Local AI', 'generic'), row('d', 'iPhone Status', 'generic')]
        self.assertEqual(probe.status_target([heading, status, *siblings], 'iGentic'), 'b')
        for wrong in [[status, *siblings], [heading,status], [heading,status,status,*siblings],
                      [heading,row('b',probe.TITLE,'generic','read'),*siblings]]:
            self.assertIsNone(probe.status_target(wrong, 'iGentic'))

    def test_journal_requires_exact_schema_and_fresh_distinct_completion(self):
        x = {'schema':1,'id':'11111111-1111-4111-8111-111111111111','createdAt':1000,'stage':'finished'}
        before = probe.valid_journal(x)
        after = probe.valid_journal({**x,'id':'22222222-2222-4222-8222-222222222222','createdAt':1005})
        start=probe.REFERENCE_DATE+1004
        end=start+5
        self.assertTrue(probe.fresh_completion(before,after,start,end))
        self.assertTrue(probe.fresh_completion(None,after,start,end))
        self.assertFalse(probe.fresh_completion(before,before,start,end))
        self.assertFalse(probe.fresh_completion(before,{**after,'stage':'awaitingFinish'},start,end))
        self.assertFalse(probe.fresh_completion(before,{**after,'createdAt':0},start,end))
        self.assertFalse(probe.fresh_completion(before,{**after,'createdAt':99999},start,end))
        for bad in [{**x,'schema':True},{**x,'id':'x'},{**x,'createdAt':float('nan')},
                    {**x,'stage':'unknown'},{**x,'extra':'private'}]:
            with self.assertRaises((ValueError,TypeError)):
                probe.valid_journal(bad)

if __name__ == '__main__':
    unittest.main()
