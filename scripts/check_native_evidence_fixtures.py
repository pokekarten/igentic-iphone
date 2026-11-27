"""Verify the frozen native lab cases mirror the canonical V0 fixtures."""
import itertools
import json
from pathlib import Path
import igentic_decision_knowledge_eval as ev

def expected_lines():
    for case in ev.load_cases():
        expected = case["expected"]
        choices = []
        for order in itertools.permutations(expected):
            for citations in itertools.permutations(expected["citations"]):
                obj = {key: list(citations) if key == "citations" else expected[key] for key in order}
                choices.append(json.dumps(obj, ensure_ascii=False, separators=(",", ":")))
        def quote(value):
            return json.dumps(value, ensure_ascii=False)
        yield '        .init(id: ' + quote(case["id"]) + ', prompt: ' + quote(ev.prompt_for(case)) + ', decision: ' + quote(expected["decision"]) + ', accepted: [' + ', '.join(map(quote, choices)) + ']),'

def main():
    source = (Path(__file__).resolve().parents[1] / "Tools/MLXModelLab/Sources/MLXProbe/EvidenceResearch.swift").read_text()
    actual = [line for line in source.splitlines() if line.startswith("        .init(id: ")]
    assert actual == list(expected_lines()), "Native fixtures diverged"
    assert 'private static let instructions = ' + json.dumps(ev.SYSTEM, ensure_ascii=False) in source, "Native prompt diverged"
    print("16 native fixtures and instructions match canonical V0")

if __name__ == "__main__":
    main()
