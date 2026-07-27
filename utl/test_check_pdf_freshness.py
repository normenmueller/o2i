"""Focused tests for versioned White Paper freshness checks."""

from __future__ import annotations

import importlib.util
from pathlib import Path
import subprocess
import sys
import unittest
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "utl" / "check-pdf-freshness.py"
SPEC = importlib.util.spec_from_file_location("check_pdf_freshness", SCRIPT)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError(f"cannot load {SCRIPT}")
CHECKER = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = CHECKER
SPEC.loader.exec_module(CHECKER)


class PdfFreshnessTest(unittest.TestCase):
    def test_text_normalization_ignores_layout_whitespace(self) -> None:
        completed = subprocess.CompletedProcess(
            args=[],
            returncode=0,
            stdout="O2I  Syntax\nträgt\tWirkung.\n",
            stderr="",
        )
        with patch.object(CHECKER.subprocess, "run", return_value=completed):
            self.assertEqual(
                "O2ISyntaxträgtWirkung.",
                CHECKER.normalized_pdf_text(Path("paper.pdf")),
            )

    def test_page_count_is_parsed(self) -> None:
        completed = subprocess.CompletedProcess(
            args=[],
            returncode=0,
            stdout="Title: O2I\nPages:          73\n",
            stderr="",
        )
        with patch.object(CHECKER.subprocess, "run", return_value=completed):
            self.assertEqual(73, CHECKER.pdf_page_count(Path("paper.pdf")))

    def test_freshness_reports_page_and_text_drift(self) -> None:
        with (
            patch.object(CHECKER, "pdf_page_count", side_effect=(72, 73)),
            patch.object(
                CHECKER,
                "normalized_pdf_text",
                side_effect=("old", "new"),
            ),
        ):
            self.assertEqual(
                [
                    "page count differs: versioned 72, rendered 73",
                    "normalized publication text differs",
                ],
                CHECKER.freshness_errors(
                    Path("versioned.pdf"),
                    Path("rendered.pdf"),
                ),
            )

    def test_main_accepts_matching_publications(self) -> None:
        with patch.object(CHECKER, "freshness_errors", return_value=[]):
            self.assertEqual(
                0,
                CHECKER.main(["versioned.pdf", "rendered.pdf"]),
            )


if __name__ == "__main__":
    unittest.main()
