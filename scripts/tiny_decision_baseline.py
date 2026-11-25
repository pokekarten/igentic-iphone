#!/usr/bin/env python3
"""Train an independent, zero-dependency offline decision baseline.

Synthetic route suggestions only. No model API, network, external weights,
permissions or execution. This is a deliberately small classifier, not an LLM.
"""
from __future__ import annotations

import argparse
from collections import Counter
import json
import math
from pathlib import Path
import re
import unicodedata

ROUTES = ("arguments", "knowledge", "summarize", "clarify")
# Separate synthetic development corpus, not derived from the action or
# decision/evidence V0 benchmarks. No real personal records.
TRAIN = {
    "arguments": [
        "Vergleiche die Vor- und Nachteile der beiden Entwürfe",
        "Welche Gegenargumente sprechen gegen diesen Vorschlag",
        "Bewerte die Alternativen und begründe deine Wahl",
        "Wäge Nutzen und Nachteile beider Möglichkeiten ab",
        "Welche Argumente stützen diese These",
        "Analysiere die Einwände gegen die Empfehlung",
        "Compare the pros and cons of both approaches",
        "Evaluate competing alternatives and justify the choice",
        "What counterarguments challenge the proposal",
        "Weigh the benefits and drawbacks of these options",
        "Which arguments support this position",
        "Assess the objections to this recommendation",
    ],
    "knowledge": [
        "Suche die Definition im lokalen Glossar",
        "Finde die Quelle dieser Fachinformation",
        "Durchsuche die Wissensdatenbank nach dem Begriff",
        "Rufe die hinterlegte Dokumentation ab",
        "Wo steht diese Information im Handbuch",
        "Zeige die gespeicherten Referenzen zum Thema",
        "Search the local knowledge base for this term",
        "Retrieve the relevant documentation",
        "Find the source of this technical fact",
        "Look up the definition in the glossary",
        "Where is this information in the manual",
        "Find stored references on this topic",
    ],
    "summarize": [
        "Fasse den Text in wenigen Sätzen zusammen",
        "Erstelle eine kurze Zusammenfassung des Artikels",
        "Kürze die Notiz auf die wichtigsten Punkte",
        "Verdichte diesen Absatz zu einer Übersicht",
        "Gib die Kernaussagen des Berichts wieder",
        "Schreibe eine knappe Inhaltsangabe",
        "Summarize the passage in a few sentences",
        "Create a brief summary of the article",
        "Condense this note to its key points",
        "Give a short overview of the report",
        "Extract the main points from the supplied text",
        "Write a concise synopsis of the paragraph",
    ],
    "clarify": [
        "Mach das irgendwie",
        "Erledige die Sache von vorhin",
        "Ich weiß nicht was genau gemeint ist",
        "Das andere bitte",
        "Tue etwas damit",
        "Was auch immer richtig ist",
        "Do that thing",
        "Handle it somehow",
        "I am not sure what I mean",
        "The other one please",
        "Whatever seems right",
        "Take care of it",
    ],
}
# Development smoke only; not a blind test, no claim of generalization.
DEV = [
    ("arguments", "Wäge die Vorzüge und Risiken der Optionen ab"),
    ("arguments", "Compare the drawbacks of competing recommendations"),
    ("arguments", "Gibt es überzeugende Gegenargumente zur These"),
    ("arguments", "Assess alternatives and justify a recommendation"),
    ("knowledge", "Suche den Fachbegriff in der Dokumentation"),
    ("knowledge", "Look up the term in the local reference manual"),
    ("knowledge", "Finde eine hinterlegte Quelle im Wissensarchiv"),
    ("knowledge", "Retrieve the stored glossary entry"),
    ("summarize", "Fasse den Absatz kurz zusammen"),
    ("summarize", "Condense the supplied article into a short summary"),
    ("summarize", "Gib die wichtigsten Kernaussagen wieder"),
    ("summarize", "Summarize the report in two sentences"),
    ("clarify", "Mach einfach irgendwas damit"),
    ("clarify", "Do the other thing please"),
    ("clarify", "Das da bitte irgendwie"),
    ("clarify", "Handle whatever I meant"),
]
MAX_BYTES = 1024
MIN_MARGIN = 0.25  # heuristic, not calibrated probability


def features(text):
    text = unicodedata.normalize("NFKC", text).casefold()
    words = re.findall(r"[^\W\d_]+", text, flags=re.UNICODE)
    out = Counter()
    for word in words:
        out["w:" + word] += 1
        padded = "^" + word + "$"
        for i in range(len(padded) - 2):
            out["g:" + padded[i:i + 3]] += 1
    return out


def train():
    counts = {route: Counter() for route in ROUTES}
    for route in ROUTES:
        for sample in TRAIN[route]:
            counts[route].update(features(sample))
    vocab = sorted(set().union(*(set(c) for c in counts.values())))
    return {
        "format": "igentic-tiny-nb-v0",
        "routes": list(ROUTES),
        "vocabulary": vocab,
        "counts": {route: dict(sorted(counts[route].items())) for route in ROUTES},
        "totals": {route: sum(counts[route].values()) for route in ROUTES},
        "training_examples": sum(map(len, TRAIN.values())),
    }


def predict(model, text):
    fallback = {"route": "clarify", "reason": "insufficient_signal"}
    if not isinstance(text, str) or len(text) > MAX_BYTES:
        return fallback
    try:
        if len(text.encode("utf-8")) > MAX_BYTES:
            return fallback
    except UnicodeEncodeError:
        return fallback
    known = set(model["vocabulary"])
    observed = {k: v for k, v in features(text).items() if k in known}
    if len(observed) < 3:
        return fallback
    scores = {}
    for route in ROUTES:
        denom = model["totals"][route] + len(known)
        scores[route] = sum(
            n * math.log((model["counts"][route].get(k, 0) + 1) / denom)
            for k, n in observed.items()
        ) / sum(observed.values())
    ranked = sorted(ROUTES, key=lambda route: (-scores[route], route))
    if scores[ranked[0]] - scores[ranked[1]] < MIN_MARGIN:
        return fallback
    return {"route": ranked[0], "reason": "classifier_suggestion"}


def evaluate(model):
    results = Counter()
    for expected, text in DEV:
        prediction = predict(model, text)
        guess = prediction["route"]
        results["correct"] += guess == expected
        results["wrong"] += guess != expected
        results["abstained"] += prediction["reason"] == "insufficient_signal"
        results["classified_clarify"] += (
            guess == "clarify" and prediction["reason"] == "classifier_suggestion"
        )
        results["clarify_routes"] += guess == "clarify"
        results["wrong_nonclarify"] += guess != expected and guess != "clarify"
    return {"cases": len(DEV), **results}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--export", type=Path, help="optional local model export; never automatic")
    args = parser.parse_args()
    model = train()
    encoded = json.dumps(model, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    if args.export:
        # Refuse to overwrite an existing file.
        with args.export.open("x", encoding="utf-8") as out:
            out.write(encoded + "\n")
    print(json.dumps({"training_examples": model["training_examples"],
                      "features": len(model["vocabulary"]),
                      "export_bytes": len((encoded + "\n").encode("utf-8")),
                      "development_smoke": evaluate(model)}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
