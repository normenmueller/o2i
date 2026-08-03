"""Tests for executable repository Candidate View acceptance."""

from __future__ import annotations

import copy
import importlib.util
from pathlib import Path
import subprocess
import unittest
from unittest import mock


ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "utl" / "model" / "check-executable-views.py"
SPEC = importlib.util.spec_from_file_location(
    "check_executable_views",
    SCRIPT,
)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError(f"cannot load {SCRIPT}")
CHECKER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(CHECKER)


def valid_report(view_name: str) -> dict:
    diagnostics = [
        {
            "code": code,
            "severity": "warn",
            "stage": "semantics",
        }
        for code, count in CHECKER.EXPECTED_DIAGNOSTICS[view_name].items()
        for _ in range(count)
    ]
    stages = []
    for stage, state, blocker in CHECKER.EXPECTED_STAGES:
        record = {"stage": stage, "state": state}
        if blocker is not None:
            record["blockedBy"] = dict(blocker)
        stages.append(record)
    return {
        "schema": CHECKER.EXPECTED_SCHEMA,
        "inspectionState": "inspected",
        "result": "partial",
        "request": {
            "viewSelector": {"kind": "name", "value": view_name}
        },
        "viewResolution": {"view": {"name": view_name}},
        "stages": stages,
        "diagnostics": diagnostics,
    }


class ExecutableViewContractTest(unittest.TestCase):
    def test_exact_candidate_contract_is_accepted(self) -> None:
        for view_name in CHECKER.EXPECTED_DIAGNOSTICS:
            with self.subTest(view=view_name):
                self.assertEqual(
                    [],
                    CHECKER.validate_report(
                        view_name,
                        3,
                        valid_report(view_name),
                    ),
                )

    def test_exit_code_and_result_are_both_required(self) -> None:
        view_name = "O2I Syntax - Contextualization"
        report = valid_report(view_name)
        report["result"] = "failed"

        errors = CHECKER.validate_report(view_name, 1, report)

        self.assertIn("expected CLI exit 3, found 1", errors)
        self.assertIn("expected result 'partial', found 'failed'", errors)

    def test_schema_and_inspection_state_are_exact(self) -> None:
        view_name = "O2I Syntax - Contextualization"
        report = valid_report(view_name)
        report["schema"] = "other"
        report["inspectionState"] = "pending"

        errors = CHECKER.validate_report(view_name, 3, report)

        self.assertIn(
            "expected schema 'o2i.inspection.report/v1', found 'other'",
            errors,
        )
        self.assertIn(
            "expected inspectionState 'inspected', found 'pending'",
            errors,
        )

    def test_stage_drift_is_rejected(self) -> None:
        view_name = "O2I Syntax - Contextualization"
        report = valid_report(view_name)
        report["stages"][3]["state"] = "failed"

        errors = CHECKER.validate_report(view_name, 3, report)

        self.assertTrue(
            any("unexpected stage states" in error for error in errors),
            errors,
        )

    def test_blocker_reason_is_exact(self) -> None:
        view_name = "O2I Syntax - Contextualization"
        report = valid_report(view_name)
        report["stages"][5]["blockedBy"]["reason"] = "failed"

        errors = CHECKER.validate_report(view_name, 3, report)

        self.assertTrue(
            any("unexpected stage states" in error for error in errors),
            errors,
        )

    def test_diagnostic_multiset_is_exact(self) -> None:
        view_name = "O2I Syntax - Collective Strategy Realization"
        report = valid_report(view_name)
        report["diagnostics"].append(
            {
                "code": "unexpected",
                "severity": "error",
                "stage": "profile",
            }
        )

        errors = CHECKER.validate_report(view_name, 3, report)

        self.assertTrue(
            any("unexpected diagnostic multiset" in error for error in errors),
            errors,
        )
        self.assertIn("diagnostic 'unexpected' is not semantic", errors)
        self.assertIn("diagnostic 'unexpected' is not a warning", errors)

    def test_view_identity_is_exact(self) -> None:
        view_name = "O2I Syntax - Contextualization"
        report = copy.deepcopy(valid_report(view_name))
        report["request"]["viewSelector"]["value"] = "Other"
        report["viewResolution"]["view"]["name"] = "Other"

        errors = CHECKER.validate_report(view_name, 3, report)

        self.assertTrue(
            any("unexpected View selector" in error for error in errors),
            errors,
        )
        self.assertIn("resolved View name differs: 'Other'", errors)

    def test_malformed_report_collections_are_total(self) -> None:
        view_name = "O2I Syntax - Contextualization"
        report = valid_report(view_name)
        report["stages"] = [None]
        report["diagnostics"] = [None]

        errors = CHECKER.validate_report(view_name, 3, report)

        self.assertIn("stages contains a non-object entry", errors)
        self.assertIn("diagnostics contains a non-object entry", errors)

    def test_nested_null_and_scalar_values_are_total(self) -> None:
        view_name = "O2I Syntax - Contextualization"
        report = valid_report(view_name)
        report["request"] = None
        report["viewResolution"] = "invalid"
        report["stages"][5]["blockedBy"] = "semantics"

        errors = CHECKER.validate_report(view_name, 3, report)

        self.assertIn("request is not an object", errors)
        self.assertIn("viewResolution is not an object", errors)
        self.assertIn("viewResolution.view is not an object", errors)
        self.assertIn(
            "stage 'traceability' blockedBy is not an object",
            errors,
        )
        self.assertTrue(
            any("unexpected stage states" in error for error in errors),
            errors,
        )

    def test_cli_timeout_is_reported_without_exception(self) -> None:
        with mock.patch.object(
            CHECKER.subprocess,
            "run",
            side_effect=subprocess.TimeoutExpired("o2i", 30),
        ):
            errors = CHECKER.inspect_view(
                Path("o2i"),
                Path("model.archimate"),
                "O2I Syntax - Contextualization",
            )

        self.assertEqual(
            ["O2I CLI exceeded the 30-second execution limit"],
            errors,
        )

    def test_invalid_cli_encoding_is_reported_without_exception(self) -> None:
        completed = subprocess.CompletedProcess(
            args=["o2i"],
            returncode=3,
            stdout=b"\xff",
            stderr=b"\xfe",
        )
        with mock.patch.object(
            CHECKER.subprocess,
            "run",
            return_value=completed,
        ):
            errors = CHECKER.inspect_view(
                Path("o2i"),
                Path("model.archimate"),
                "O2I Syntax - Contextualization",
            )

        self.assertEqual(
            [
                "CLI stdout is not valid UTF-8 at byte 0",
                "CLI stderr is not valid UTF-8 at byte 0",
            ],
            errors,
        )

    def test_malformed_json_diagnostic_is_sanitized_and_bounded(self) -> None:
        completed = subprocess.CompletedProcess(
            args=["o2i"],
            returncode=3,
            stdout=b"not JSON",
            stderr=("first\n\x1b[31m" + "x" * 1000).encode("utf-8"),
        )
        with mock.patch.object(
            CHECKER.subprocess,
            "run",
            return_value=completed,
        ):
            errors = CHECKER.inspect_view(
                Path("o2i"),
                Path("model.archimate"),
                "O2I Syntax - Contextualization",
            )

        self.assertEqual(1, len(errors))
        self.assertIn("stderr: first\\u000a\\u001b[31m", errors[0])
        self.assertTrue(errors[0].endswith("...[truncated]"), errors[0])
        excerpt = errors[0].split("; stderr: ", maxsplit=1)[1]
        self.assertLessEqual(len(excerpt), CHECKER.DIAGNOSTIC_EXCERPT_LIMIT)
        self.assertNotIn("\n", excerpt)


if __name__ == "__main__":
    unittest.main()
