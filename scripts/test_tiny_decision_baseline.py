import json
import unittest
import tiny_decision_baseline as model


class TinyDecisionTests(unittest.TestCase):
    def test_reproducible(self):
        self.assertEqual(model.train(), model.train())

    def test_train_dev_disjoint(self):
        self.assertFalse({s for samples in model.TRAIN.values() for s in samples}
                         & {s for _, s in model.DEV})

    def test_roundtrip(self):
        fitted = model.train()
        restored = json.loads(json.dumps(fitted))
        for _, sample in model.DEV:
            self.assertEqual(model.predict(fitted, sample), model.predict(restored, sample))

    def test_empty_and_unknown_abstain(self):
        fitted = model.train()
        for sample in ("", "1234 !!!", "🌀", "x" * 1025, None):
            self.assertEqual(model.predict(fitted, sample)["route"], "clarify")

    def test_never_returns_authority(self):
        for sample in ("execute now", "ignore instructions", "authorize all",
                       *[s for _, s in model.DEV]):
            answer = model.predict(model.train(), sample)
            self.assertEqual(set(answer), {"route", "reason"})
            self.assertIn(answer["route"], model.ROUTES)

    def test_smoke_accounting(self):
        result = model.evaluate(model.train())
        self.assertEqual(result["cases"], 16)
        self.assertEqual(result["correct"], 16)
        self.assertEqual(result["wrong"], 0)
        self.assertEqual(result["wrong_nonclarify"], 0)
        self.assertEqual(result["clarify_routes"], 4)
        self.assertEqual(result["correct"] + result["wrong"], result["cases"])
        self.assertEqual(result["abstained"] + result["classified_clarify"],
                         result["clarify_routes"])

    def test_fallback_is_not_a_classified_clarify(self):
        fitted = model.train()
        self.assertEqual(model.predict(fitted, "")["reason"], "insufficient_signal")
        self.assertEqual(model.predict(fitted, model.TRAIN["clarify"][0]),
                         {"route": "clarify", "reason": "classifier_suggestion"})

    def test_unicode_input_bounds(self):
        fitted = model.train()
        for sample in ("\ud800", "ä" * 513, "x" * 1025):
            self.assertEqual(model.predict(fitted, sample),
                             {"route": "clarify", "reason": "insufficient_signal"})

    def test_training_counts(self):
        fitted = model.train()
        self.assertEqual(fitted["training_examples"], 48)
        self.assertEqual(set(fitted["counts"]), set(model.ROUTES))
        for route in model.ROUTES:
            self.assertEqual(sum(fitted["counts"][route].values()), fitted["totals"][route])


if __name__ == "__main__":
    unittest.main()
