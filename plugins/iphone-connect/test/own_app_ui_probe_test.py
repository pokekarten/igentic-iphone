import importlib.util
from pathlib import Path
from types import SimpleNamespace
import unittest

spec = importlib.util.spec_from_file_location('own_app_ui_probe',
    Path(__file__).resolve().parents[1] / 'scripts' / 'own-app-ui-probe.py')
probe = importlib.util.module_from_spec(spec)
spec.loader.exec_module(probe)

TITLE = 'a|read|text|iGentic Diagnostics|'
TARGET = 'b|tap|button|Open local discovery|'


class TestTarget(unittest.TestCase):
    def test_exact_unique_action(self):
        self.assertEqual(probe.expected_target(TITLE + '\n' + TARGET), 'b')
        for rows in [TARGET, TITLE + '\n' + TARGET + '\n' + TARGET,
                     TITLE + '\n' + TARGET.replace('|tap|', '|read|'),
                     TITLE + '\n' + TARGET.replace('Open local discovery', 'Open local discovery other')]:
            self.assertIsNone(probe.expected_target(rows))

    def test_root_and_target_must_be_owned_process(self):
        def ax(root, target):
            return SimpleNamespace(observed=SimpleNamespace(root=(root,1)), refs={'b':(target,2)})
        self.assertEqual(probe.own_target(ax(123,123), TITLE+'\n'+TARGET,123),'b')
        self.assertIsNone(probe.own_target(ax(124,123), TITLE+'\n'+TARGET,123))
        self.assertIsNone(probe.own_target(ax(123,124), TITLE+'\n'+TARGET,123))
        self.assertIsNone(probe.own_target(ax(123,123), TITLE,123))


if __name__ == '__main__':
    unittest.main()
