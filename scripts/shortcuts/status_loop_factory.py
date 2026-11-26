#!/usr/bin/env python3
"""Build a local-only, unsigned two-turn shortcut candidate from app metadata.

No installation, signing, network access or device action is performed.
The Apple AppIntent descriptor encoding is a candidate until import/runtime
acceptance on iOS; a valid plist is not evidence of a working shortcut.
"""
import argparse
import json
import os
import plistlib
import re
import subprocess
import sys
import uuid
from pathlib import Path

START = "iGenticStartStatusLoopIntent"
ADVANCE = "iGenticAdvanceStatusLoopIntent"
EXPECTED = {START: set(), ADVANCE: {"taskID", "modelReply", "finishAfterRead"}}
NAME = "iGentic Status-Loop Zwei-Schritt Test"
# Xcode 27 metadata observed in the actual iPhoneOS build: String=0, Bool=1.
PARAM_TYPES = {"taskID": 0, "modelReply": 0, "finishAfterRead": 1}

def primitive(value):
    if not isinstance(value, dict):
        return None
    try:
        kind = value["primitive"]["wrapper"]["typeIdentifier"]
        return kind if type(kind) is int else None
    except (KeyError, TypeError):
        return None



def check_metadata(metadata):
    actions = metadata.get("actions")
    if not isinstance(actions, dict):
        raise ValueError("Invalid App Intents metadata")
    for identifier, expected in EXPECTED.items():
        intent = actions.get(identifier)
        if not isinstance(intent, dict) or intent.get("identifier") != identifier:
            raise ValueError(f"Missing intent: {identifier}; rebuild current iGentic")
        if intent.get("isDiscoverable") is not True:
            raise ValueError(f"Intent not discoverable: {identifier}")
        if primitive(intent.get("outputType")) != 0:
            raise ValueError(f"Invalid output type: {identifier}")
        if type(intent.get("supportedModes")) is not int or intent["supportedModes"] != 1:
            raise ValueError(f"Invalid background mode: {identifier}")
        params = intent.get("parameters")
        if not isinstance(params, list):
            raise ValueError(f"Invalid parameters: {identifier}")
        names = []
        for p in params:
            if not isinstance(p, dict):
                raise ValueError("Invalid parameter record")
            name = p.get("name", p.get("identifier"))
            if not isinstance(name, str) or not name:
                raise ValueError("Unknown metadata parameter encoding")
            names.append(name)
            if name in expected and (primitive(p.get("valueType")) != PARAM_TYPES[name]
                                     or p.get("isOptional") is not False):
                raise ValueError(f"Invalid parameter type or optionality: {identifier}")
        if set(names) != expected or len(names) != len(expected):
            raise ValueError(f"Parameter contract mismatch: {identifier}")
    return True


def token(output, name):
    return {"WFSerializationType": "WFTextTokenAttachment",
            "Value": {"Type": "ActionOutput", "OutputUUID": output,
                      "OutputName": name}}


def action(identifier, **parameters):
    return {"WFWorkflowActionIdentifier": identifier,
            "WFWorkflowActionParameters": parameters}


def workflow(metadata, bundle, team):
    check_metadata(metadata)
    if not re.fullmatch(r"[A-Za-z0-9.-]+", bundle) or not re.fullmatch(r"[A-Z0-9]{10}", team):
        raise ValueError("Missing or invalid app signing identity")
    ids = [str(uuid.uuid5(uuid.NAMESPACE_URL, f"igentic:status-loop:v1:{n}")).upper()
           for n in ("start", "dict", "task", "read", "finish")]

    def native(identifier, title, output, **params):
        return action(bundle + "." + identifier,
                      AppIntentDescriptor={"BundleIdentifier": bundle,
                                           "TeamIdentifier": team,
                                           "AppIntentIdentifier": identifier,
                                           "Name": title},
                      UUID=output, **params)

    task = token(ids[2], "Auftrags-ID")
    return {
        "WFWorkflowName": NAME,
        "WFWorkflowClientVersion": "2700.0.4",
        "WFWorkflowMinimumClientVersion": 900,
        "WFWorkflowMinimumClientVersionString": "900",
        "WFWorkflowIcon": {"WFWorkflowIconGlyphNumber": 59511,
                           "WFWorkflowIconStartColor": 4282601983},
        "WFWorkflowTypes": [], "WFWorkflowImportQuestions": [],
        "WFWorkflowInputContentItemClasses": [],
        "WFWorkflowOutputContentItemClasses": [],
        "WFWorkflowActions": [
            native(START, "iGentic Status-Loop starten", ids[0]),
            action("is.workflow.actions.detect.dictionary", UUID=ids[1],
                   WFInput=token(ids[0], "iGentic Status-Loop starten")),
            action("is.workflow.actions.getvalueforkey", UUID=ids[2],
                   CustomOutputName="Auftrags-ID", WFDictionaryKey="taskId",
                   WFGetDictionaryValueType="Value",
                   WFInput=token(ids[1], "Dictionary")),
            native(ADVANCE, "iGentic Status-Loop fortsetzen", ids[3],
                   taskID=task, modelReply='{"action":"status.read"}',
                   finishAfterRead=False),
            native(ADVANCE, "iGentic Status-Loop fortsetzen", ids[4],
                   taskID=task, modelReply='{"action":"finish"}',
                   finishAfterRead=False),
        ],
    }


def app_identity(app):
    # Never print the local signer, bundle identifier, or codesign output.
    subprocess.run(["codesign", "--verify", "--strict", str(app)],
                   check=True, capture_output=True, timeout=30)
    info = plistlib.loads((app / "Info.plist").read_bytes())
    details = subprocess.run(["codesign", "-dv", "--verbose=4", str(app)],
                             check=True, capture_output=True, text=True, timeout=30)
    match = re.search(r"^TeamIdentifier=([A-Z0-9]{10})$", details.stderr, re.M)
    if not match:
        raise ValueError("No signed app team identity")
    return info["CFBundleIdentifier"], match.group(1)


def write_private_candidate(path, data):
    # Exclusive creation: never overwrite existing files or follow an output symlink.
    # The candidate embeds a local team identifier, so set private mode at creation.
    with os.fdopen(os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600), "wb") as file:
        file.write(data)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    source = parser.add_mutually_exclusive_group(required=True)
    source.add_argument("--metadata", type=Path, help="Preflight only")
    source.add_argument("--app", type=Path, help="Signed local iGentic .app")
    parser.add_argument("--output", type=Path, help="New unsigned .shortcut candidate")
    args = parser.parse_args()
    if args.output and (not args.app or args.output.suffix != ".shortcut"):
        parser.error("--output requires --app and a .shortcut filename")
    try:
        path = args.metadata or args.app / "Metadata.appintents/extract.actionsdata"
        metadata = json.loads(path.read_text())
        check_metadata(metadata)
        if args.output:
            bundle, team = app_identity(args.app)
            data = plistlib.dumps(workflow(metadata, bundle, team), fmt=plistlib.FMT_BINARY)
            write_private_candidate(args.output, data)
        print(json.dumps({"metadataReady": True, "candidateCreated": bool(args.output),
                          "signed": False, "imported": False, "physicalVerified": False}))
        return 0
    except ValueError as exc:
        # Fixed validation messages only; never print metadata or signer.
        message = str(exc)
        if not message.startswith(("Missing intent:", "Intent not discoverable:", "Parameter contract mismatch:", "Invalid ", "Unknown metadata", "Missing or invalid", "No signed")):
            message = "Invalid or unsupported metadata"
        print(message, file=sys.stderr)
    except (OSError, KeyError, TypeError, subprocess.SubprocessError):
        print("Local build or output unavailable; no installation attempted", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main())
