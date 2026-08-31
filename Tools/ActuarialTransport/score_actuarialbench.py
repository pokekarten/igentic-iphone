from __future__ import annotations

import argparse
import hashlib
import json
import math
from collections import defaultdict
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_BENCHMARK = ROOT / "evals" / "actuarial" / "actuarialbench-v0.jsonl"


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def load_jsonl(path: Path) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for line_number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        if not line.strip():
            continue
        value = json.loads(line)
        if not isinstance(value, dict):
            raise ValueError(f"{path}:{line_number} must be an object")
        rows.append(value)
    return rows


def parse_numeric(answer: Any) -> float | None:
    if isinstance(answer, bool):
        return None
    if isinstance(answer, (int, float)):
        return float(answer)
    if isinstance(answer, str):
        text = answer.strip().replace(",", ".")
        try:
            return float(text)
        except ValueError:
            return None
    return None


def score_one(case: dict[str, Any], prediction: dict[str, Any]) -> dict[str, Any]:
    expected = case["expected"]
    answer = prediction.get("answer")
    kind = expected["kind"]
    correct = False
    error: str | None = None

    if kind == "numeric":
        observed = parse_numeric(answer)
        target = float(expected["value"])
        tolerance = float(expected["absolute_tolerance"])
        if observed is None or not math.isfinite(observed):
            error = "not_numeric"
        else:
            correct = abs(observed - target) <= tolerance
            if not correct:
                error = "outside_tolerance"
    else:
        observed_text = str(answer).strip()
        target_text = str(expected["value"]).strip()
        correct = observed_text == target_text
        if not correct:
            error = "exact_mismatch"

    return {
        "case_id": case["case_id"],
        "domain": case["domain"],
        "task_type": case["task_type"],
        "correct": correct,
        "error": error,
        "latency_ms": prediction.get("latency_ms"),
        "peak_memory_mb": prediction.get("peak_memory_mb"),
    }


def score(benchmark: list[dict[str, Any]], predictions: list[dict[str, Any]]) -> dict[str, Any]:
    pred_by_id: dict[str, dict[str, Any]] = {}
    duplicates: list[str] = []
    for prediction in predictions:
        case_id = prediction.get("case_id")
        if not isinstance(case_id, str):
            raise ValueError("every prediction requires string case_id")
        if case_id in pred_by_id:
            duplicates.append(case_id)
        pred_by_id[case_id] = prediction
    if duplicates:
        raise ValueError(f"duplicate prediction case_id values: {sorted(set(duplicates))}")

    benchmark_ids = {case["case_id"] for case in benchmark}
    extra = sorted(set(pred_by_id) - benchmark_ids)
    if extra:
        raise ValueError(f"predictions contain unknown case_ids: {extra}")

    case_results: list[dict[str, Any]] = []
    missing: list[str] = []
    for case in benchmark:
        prediction = pred_by_id.get(case["case_id"])
        if prediction is None:
            missing.append(case["case_id"])
            case_results.append({
                "case_id": case["case_id"],
                "domain": case["domain"],
                "task_type": case["task_type"],
                "correct": False,
                "error": "missing_prediction",
                "latency_ms": None,
                "peak_memory_mb": None,
            })
        else:
            case_results.append(score_one(case, prediction))

    by_domain: dict[str, dict[str, int | float]] = {}
    domain_rows: defaultdict[str, list[dict[str, Any]]] = defaultdict(list)
    for row in case_results:
        domain_rows[row["domain"]].append(row)
    for domain, rows in sorted(domain_rows.items()):
        passed = sum(bool(row["correct"]) for row in rows)
        by_domain[domain] = {
            "passed": passed,
            "total": len(rows),
            "accuracy": passed / len(rows),
        }

    latencies = [
        float(row["latency_ms"])
        for row in case_results
        if isinstance(row["latency_ms"], (int, float)) and not isinstance(row["latency_ms"], bool)
    ]
    memories = [
        float(row["peak_memory_mb"])
        for row in case_results
        if isinstance(row["peak_memory_mb"], (int, float)) and not isinstance(row["peak_memory_mb"], bool)
    ]
    passed = sum(bool(row["correct"]) for row in case_results)
    return {
        "benchmark_cases": len(benchmark),
        "prediction_cases": len(predictions),
        "passed": passed,
        "failed": len(benchmark) - passed,
        "accuracy": passed / len(benchmark) if benchmark else 0.0,
        "missing_case_ids": missing,
        "mean_latency_ms": sum(latencies) / len(latencies) if latencies else None,
        "max_peak_memory_mb": max(memories) if memories else None,
        "by_domain": by_domain,
        "cases": case_results,
    }


def score_files(benchmark_path: Path, predictions_path: Path) -> dict[str, Any]:
    benchmark_path = benchmark_path.expanduser().resolve()
    predictions_path = predictions_path.expanduser().resolve()
    if not benchmark_path.is_file():
        raise ValueError(f"benchmark not found: {benchmark_path}")
    if not predictions_path.is_file():
        raise ValueError(f"predictions not found: {predictions_path}")
    result = score(load_jsonl(benchmark_path), load_jsonl(predictions_path))
    result["benchmark_sha256"] = sha256_file(benchmark_path)
    result["predictions_sha256"] = sha256_file(predictions_path)
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description="Score model predictions against an actuarial benchmark surface.")
    parser.add_argument("predictions", type=Path)
    parser.add_argument("--benchmark", type=Path, default=DEFAULT_BENCHMARK)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()

    result = score_files(args.benchmark, args.predictions)
    rendered = json.dumps(result, indent=2, sort_keys=True) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(rendered, encoding="utf-8")
    print(rendered, end="")
    return 0 if result["failed"] == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
