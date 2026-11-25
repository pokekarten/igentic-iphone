"""Generate a deterministic appendix from the read-only PR #379 atlas snapshot.

Research-only dev script. It reads local atlas path explicitly and writes only
an allowlisted report. Does not clone or execute upstreams.
"""
from pathlib import Path
import re
import sys
import os
import tempfile

def require(condition, message):
    if not condition:
        raise SystemExit(message)


require(len(sys.argv) == 3, "Usage: generate_capability_gap_appendix.py ATLAS REPORT")
source = Path(sys.argv[1])
dest = Path(sys.argv[2])
root = Path(__file__).resolve().parents[1]
allowed = root / "docs/reports/agent-tool-coverage-gap-audit-2026-11-23.md"
require(allowed.resolve() == allowed and dest.resolve() == allowed
        and not dest.is_symlink() and dest.is_file(), "Destination is not the allowlisted report")
require(source.resolve() != allowed, "Atlas and report must be distinct")
atlas = source.read_text(encoding="utf-8")
a = atlas.index("### Reuse decision for the complete indexed corpus")
b = atlas.index("### What to combine first", a)
group_for = {}
for line in atlas[a:b].splitlines():
    if not line.startswith("| "):
        continue
    parts = [x.strip() for x in line.split("|")]
    if len(parts) > 4:
        for repo in re.findall(r"`([\w.-]+/[\w.-]+)`", parts[2]):
            group_for[repo.lower()] = parts[1]

all_repos = sorted(
    set(re.findall(r"https://github.com/([A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+)", atlas)),
    key=str.lower
)
require(len(all_repos) == 99, "Unexpected linked repository count")
explicit_external = [repo for repo in all_repos if repo.lower() != "pokekarten/igentic-iphone"]
cross_reference_only = sorted(set(group_for) - {r.lower() for r in all_repos})
external = sorted(set(explicit_external) | set(cross_reference_only), key=str.lower)
require(len(explicit_external) == 98 and len(cross_reference_only) == 9, "Unexpected corpus partition")
require(len(external) == 107 and len({r.lower() for r in external}) == 107
        and all(r.lower() in group_for for r in external), "Invalid corpus coverage")
gaps = {
    "Host device adapters": "General AX/screenshot/tap/swipe/typing; our adapter deliberately scopes operations to the own app. Requires Mac/host.",
    "Harness, persistence and sandbox components": "Durable loop, effect journal and isolated execution; current kernel routes metadata and memory is in-process.",
    "Native agent/workspace products": "Complete on-phone agent/planner, shared file workspace and persistent context beyond diagnostic/offline utilities.",
    "Inference engines and provider adapters": "Production-ready physical iPhone open-weight runtimes and reproducible memory/thermal/model evidence.",
    "Evaluation and GUI research": "External benchmark, long-horizon apps and independent pass-rate metrics beyond own-app fixtures.",
    "Phone-resident cross-app experiments": "Developer-mode, phone-hosted UI automation; unavailable in iGentic and not a general App Store API.",
    "Speech and conversational audio": "Voice input, local ASR, VAD, interruption, complete speech conversation; current PR adds only speech output.",
    "Developer transport and QA infrastructure": "Wider signed runner, WDA and multi-device infrastructure; native CoreDevice bridge is own-app-only.",
    "Simulator tooling": "Scripted multi-app test flow recording and replay; own iOS app simulator build exists.",
    "Public action and shortcut bridges": "Full typed App Intents/Shortcuts catalog, permission separation and shared policy for each action.",
    "Hybrid phone/host agent products": "Broad human takeover, mirrored-device monitoring and model-to-action UX.",
    "Out-of-target architecture references": "Extra hardware or Mac-only Accessibility; research-only, not a production dependency.",
    "Reverse-direction remote supervision": "Optional iPhone dashboard for Mac agents, not phone-autonomous control.",
    "Model and local-app UX references": "Polished offline model downloads/cache, multimodal and model-picker UX; current iGentic is not a general local model catalog.",
}

lines = atlas.splitlines()
by_group = {}
for repo in external:
    by_group.setdefault(group_for[repo.lower()], []).append(repo)
require(set(by_group) == set(gaps), "Invalid capability groups")
missing_details = {
    "a-ghorbani/pocketpal-ai": "Phone-local LLM chat application, local model download and use.",
    "javichulvi/hermit": "Local model/assistant interface reference; verify current platform and model support before adoption.",
    "john-rocky/coreai-kit": "iOS 27 Swift runtime for Core AI chat, speech and vision with model downloads, caching and Foundation Models integration.",
    "john-rocky/coreai-model-zoo": "Downloadable Core AI model catalog, conversion recipes, source-vs-export validation and Swift examples.",
    "kilianbalaguer/voltaire": "Local MLX model app for iPhone/iPad/Mac; check source and redistribution limitations.",
    "luckeyfaraday/local-models": "Local model application/UX and model selection reference.",
    "pgorzelany/swift-llama-cpp": "Swift package wrapper around llama.cpp for native iOS model inference.",
    "reezxy/local-ai-vision-app": "Swift/Metal fully local vision app example.",
    "simonmaddox/foundation-models-byo-model": "Bring your own model to iOS 27 Foundation Models with Core ML/llama.cpp backends.",
}
out = []
for group in sorted(by_group):
    repos = by_group[group]
    out.extend(["", "### " + group + " (" + str(len(repos)) + ")", "",
                "**iGentic gap:** " + gaps[group], "",
                "| Project | Source-described functionality (not newly device-verified) |",
                "| --- | --- |"])
    for repo in repos:
        target = "https://github.com/" + repo
        # Exact repo path boundary: "appium/appium" must NOT match
        # "appium/appium-mcp", and "mlx-swift" must not match "mlx-swift-lm".
        exact_url = re.compile(re.escape(target) + r"(?=[)/#?\s]|$)", re.IGNORECASE)
        matches = [line for line in lines
                   if line.startswith("|") and exact_url.search(line)]
        if matches:
            cells = [cell.strip() for cell in matches[0].split("|") if cell.strip()]
            n = next(i for i, cell in enumerate(cells) if exact_url.search(cell))
            description = cells[n + 1] if n + 1 < len(cells) else ""
            # Source tables sometimes put a project and a source citation in one
            # column. Never parse their language as control instructions.
            description = re.sub(r"\[([^]]+)\]\(https?://[^)]+\)", r"\1", description)
        elif repo.lower() == "google/artemis":
            description = "Primarily Android end-to-end GUI agent and MCP; iOS driver work is still a separate integration candidate."
        else:
            description = missing_details.get(repo.lower(), "Research-only source; review current upstream before integration.")
        capability_override = {
            "rryam/foundationmodelskit": "Swift Apple Foundation Models tool-loop guardrails, structured generation, per-turn budgets, EventKit mutation receipts and unknown-outcome handling.",
            "carrotciallo/poki-for-linux": "Unofficial Linux-host adaptation of Poki using Rust idevice and Node MCP, USB and RemoteXPC.",
            "jkcoxson/devicehub_rs": "Rust-based CoreDevice display and HID service bridge, GUI, MCP and VNC; requires separate network/authentication review.",
            "wazixuan/iospilot": "Mac-hosted Python MCP using iOS 27+ CoreDevice accessibility, HID input and screen settling.",
            "lllllayer/eiscue": "iPhone-resident screenshot-to-vision-to-action agent; one-use frame binding, uncertain-result handling and optional continued-background tasks.",
            "turbo1123/roubao": "Swift/Rust iPhone-resident agent derived from iphone-use-app, loopback VPN bridge, resumable task UX and manual consent.",
        }
        description = capability_override.get(repo.lower(), description)
        description = re.sub(r"\s+", " ", description).replace("|", "/")
        if len(description) > 250:
            description = description[:247].rstrip() + "..."
        out.append("| [" + repo + "](" + target + ") | " + description + " |")
out += ["", "---", "",
        "**Scope closure:** all 107 external upstream identities (98 linked in the frozen atlas + 9 additional catalog cross-references) appear exactly once. "
        "This is classification of source projects, not verified readiness, licensing clearance or installation.", ""]
prior = allowed.read_text(encoding="utf-8")
marker = "## Appendix: full atlas-to-gap coverage (107 external repositories)"
require(prior.count(marker) == 1, "Missing or duplicate appendix marker")
updated = prior[:prior.index(marker) + len(marker)] + "\n" + "\n".join(out)
if updated != prior:
    # Atomic replacement avoids modifying another file through a hard link.
    # Only this generator's temporary file is removed on failure.
    tmp = None
    try:
        with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", dir=allowed.parent,
                                         prefix=".capability-appendix-", delete=False) as output:
            tmp = Path(output.name)
            output.write(updated)
        os.chmod(tmp, allowed.stat().st_mode & 0o777)
        require(allowed.resolve() == allowed and not allowed.is_symlink(),
                "Destination changed")
        os.replace(tmp, allowed)
    finally:
        if tmp is not None:
            tmp.unlink(missing_ok=True)
print("appendix_groups=", len(by_group), "external_upstreams=", len(external), "report_bytes=", allowed.stat().st_size)
