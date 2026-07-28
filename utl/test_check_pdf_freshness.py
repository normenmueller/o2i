"""Focused tests for versioned White Paper freshness checks."""

from __future__ import annotations

import importlib.util
from pathlib import Path
import subprocess
import sys
import tempfile
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
                "O2I Syntax trägt Wirkung.",
                CHECKER.normalized_pdf_text(Path("paper.pdf")),
            )

    def test_text_normalization_preserves_word_boundaries(self) -> None:
        with patch.object(
            CHECKER.subprocess,
            "run",
            side_effect=(
                subprocess.CompletedProcess([], 0, "Key Result", ""),
                subprocess.CompletedProcess([], 0, "KeyResult", ""),
            ),
        ):
            self.assertNotEqual(
                CHECKER.normalized_pdf_text(Path("spaced.pdf")),
                CHECKER.normalized_pdf_text(Path("joined.pdf")),
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
            patch.object(CHECKER, "pdf_page_raster_digests") as rasters,
        ):
            self.assertEqual(
                [
                    "page count differs: versioned 72, rendered 73",
                    "normalized publication text differs at token 1: "
                    "versioned 'old', rendered 'new'",
                ],
                CHECKER.freshness_errors(
                    Path("versioned.pdf"),
                    Path("rendered.pdf"),
                ),
            )
            rasters.assert_not_called()

    def test_freshness_reports_visual_only_drift(self) -> None:
        with (
            patch.object(CHECKER, "pdf_page_count", side_effect=(2, 2)),
            patch.object(
                CHECKER,
                "normalized_pdf_text",
                side_effect=("same text", "same text"),
            ),
            patch.object(
                CHECKER,
                "pdf_page_raster_digests",
                side_effect=(
                    ((1, "same"), (2, "old")),
                    ((1, "same"), (2, "new")),
                ),
            ),
        ):
            self.assertEqual(
                ["visual content differs on pages: 2"],
                CHECKER.freshness_errors(
                    Path("versioned.pdf"),
                    Path("rendered.pdf"),
                ),
            )

    def test_real_pdfs_detect_visual_only_drift(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            versioned = self._render_test_pdf(root, "versioned", "2cm")
            rendered = self._render_test_pdf(root, "rendered", "3cm")

            self.assertEqual(
                ["visual content differs on pages: 1"],
                CHECKER.freshness_errors(versioned, rendered),
            )

    def test_page_rasters_are_sorted_numerically(self) -> None:
        def render(command, **_):
            prefix = Path(command[-1])
            prefix.with_name("page-2.ppm").write_bytes(b"P6\n2 1\n255\nbbb")
            prefix.with_name("page-1.ppm").write_bytes(b"P6\n1 1\n255\naaa")
            return subprocess.CompletedProcess(command, 0, "", "")

        with patch.object(CHECKER.subprocess, "run", side_effect=render):
            digests = CHECKER.pdf_page_raster_digests(
                Path("paper.pdf"),
                2,
            )

        self.assertEqual((1, 2), tuple(page for page, _ in digests))

    def test_missing_page_raster_is_rejected(self) -> None:
        def render(command, **_):
            prefix = Path(command[-1])
            prefix.with_name("page-1.ppm").write_bytes(b"P6\n1 1\n255\naaa")
            return subprocess.CompletedProcess(command, 0, "", "")

        with (
            patch.object(CHECKER.subprocess, "run", side_effect=render),
            self.assertRaisesRegex(
                CHECKER.PdfFreshnessError,
                "expected \\(1, 2\\), found \\(1,\\)",
            ),
        ):
            CHECKER.pdf_page_raster_digests(Path("paper.pdf"), 2)

    def test_rasterizer_failure_is_reported(self) -> None:
        completed = subprocess.CompletedProcess(
            args=[],
            returncode=1,
            stdout="",
            stderr="render failed",
        )
        with (
            patch.object(CHECKER.subprocess, "run", return_value=completed),
            self.assertRaisesRegex(
                CHECKER.PdfFreshnessError,
                "cannot rasterize paper.pdf: render failed",
            ),
        ):
            CHECKER.pdf_page_raster_digests(Path("paper.pdf"), 1)

    def test_main_accepts_matching_publications(self) -> None:
        with patch.object(CHECKER, "freshness_errors", return_value=[]):
            self.assertEqual(
                0,
                CHECKER.main(["versioned.pdf", "rendered.pdf"]),
            )

    def _render_test_pdf(
        self,
        directory: Path,
        name: str,
        width: str,
    ) -> Path:
        source = directory / f"{name}.tex"
        source.write_text(
            "\\documentclass{article}\n"
            "\\pagestyle{empty}\n"
            "\\begin{document}\n"
            "Same text.\\par\\vspace{1cm}\n"
            f"\\rule{{{width}}}{{1cm}}\n"
            "\\end{document}\n",
            encoding="ascii",
        )
        completed = subprocess.run(
            [
                "pdflatex",
                "-interaction=batchmode",
                "-halt-on-error",
                source.name,
            ],
            cwd=directory,
            check=False,
            capture_output=True,
            text=True,
        )
        self.assertEqual(0, completed.returncode, completed.stdout)
        return directory / f"{name}.pdf"


if __name__ == "__main__":
    unittest.main()
