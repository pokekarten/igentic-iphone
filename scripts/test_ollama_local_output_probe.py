import json
import unittest
from unittest.mock import patch

import ollama_local_output_probe as probe


class LocalOpenWeightOutputBoundaryTests(unittest.TestCase):
    def test_only_strict_non_authorizing_json_is_previewable(self):
        self.assertEqual(probe.classify_generated_text('{"action":"diagnostics.read","approved":false}'), 'synthetic_preview_only')

    def test_rejects_reasoning_prefix_and_think_suffix(self):
        observed = 'We are to return exactly the JSON object.\n</think>\n{"action":"diagnostics.read","approved":false}'
        self.assertEqual(probe.classify_generated_text(observed), 'not_strict_json')

    def test_rejects_action_substitution_and_approval(self):
        self.assertEqual(probe.classify_generated_text('{"action":"reminder.create","approved":false}'), 'action_or_approval_not_permitted')
        self.assertEqual(probe.classify_generated_text('{"action":"diagnostics.read","approved":true}'), 'action_or_approval_not_permitted')

    def test_rejects_duplicate_action_and_approval_keys(self):
        # json.loads defaults to last-key-wins, which can hide contradictory
        # model output from downstream policy and audit consumers.
        duplicate_approval = '{"action":"diagnostics.read","approved":true,"approved":false}'
        duplicate_action = '{"action":"reminder.create","action":"diagnostics.read","approved":false}'
        for output in (duplicate_approval, duplicate_action):
            self.assertEqual(probe.classify_generated_text(output), 'not_strict_json')

    def test_rejects_extra_fields_and_non_objects(self):
        for value in ('{"action":"diagnostics.read","approved":false,"extra":"test"}', '[1]', 'null'):
            self.assertNotEqual(probe.classify_generated_text(value), 'synthetic_preview_only')

    def test_rejects_non_string_and_oversized_output(self):
        self.assertEqual(probe.classify_generated_text(None), 'invalid_output')
        self.assertEqual(probe.classify_generated_text('a' * 2049), 'invalid_output')

    def test_public_evidence_does_not_echo_model_text(self):
        model_text = 'SECRET SYNTHETIC sentinel </think>'
        result = probe.public_evidence({'done': True, 'response': model_text, 'total_duration': 14, 'eval_count': 20, 'eval_duration': 10, 'debug': 'secret'})
        self.assertEqual(result, {'disposition': 'not_strict_json', 'total_duration': 14, 'eval_count': 20, 'eval_duration': 10})
        self.assertNotIn('SECRET', json.dumps(result))
        self.assertNotIn('secret', json.dumps(result))

    def test_untrusted_metrics_are_not_accepted(self):
        result = probe.public_evidence({'done': True, 'response': '{}', 'eval_count': True, 'total_duration': -1, 'eval_duration': float('inf')})
        self.assertEqual(result, {'disposition': 'invalid_schema'})

    def test_allowlist_rejects_external_model_names_before_any_network(self):
        with self.assertRaises(ValueError):
            probe.run_synthetic('https://example.com/model')
        self.assertEqual(probe.LOCAL_API, 'http://127.0.0.1:11434/api/generate')

    def test_default_does_not_call_inference(self):
        with patch('sys.argv', ['probe']):
            with patch.object(probe, 'run_synthetic', side_effect=AssertionError('called')):
                self.assertEqual(probe.main(), 0)


if __name__ == '__main__':
    unittest.main()
