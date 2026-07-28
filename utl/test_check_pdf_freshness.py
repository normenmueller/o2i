"""Focused tests for versioned White Paper source and render freshness."""

from __future__ import annotations

import importlib.util
import json
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

    def test_render_comparison_reports_page_and_text_drift(self) -> None:
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
                    "normalized publication text differs at token 1: "
                    "versioned 'old', rendered 'new'",
                ],
                CHECKER.rendered_publication_errors(
                    Path("versioned.pdf"),
                    Path("rendered.pdf"),
                ),
            )

    def test_source_digest_detects_visual_asset_drift(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = self._publication_root(Path(directory))
            figure = root / "img" / "figure.png"
            before = CHECKER.publication_source_digest(root)
            figure.write_bytes(b"new pixels")
            after = CHECKER.publication_source_digest(root)
            self.assertNotEqual(before, after)

    def test_source_digest_detects_layout_source_drift(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = self._publication_root(Path(directory))
            before = CHECKER.publication_source_digest(root)
            article = root / "o2i.md"
            article.write_text(
                article.read_text(encoding="utf-8") + "\n\\clearpage\n",
                encoding="utf-8",
            )
            after = CHECKER.publication_source_digest(root)
            self.assertNotEqual(before, after)

    def test_source_digest_detects_included_snippet_drift(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = self._publication_root(Path(directory))
            before = CHECKER.publication_source_digest(root)
            (root / "snippet.hs").write_text("answer = 43\n", encoding="ascii")
            after = CHECKER.publication_source_digest(root)
            self.assertNotEqual(before, after)

    def test_manifest_binds_current_sources_and_pdf(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = self._publication_root(Path(directory))
            pdf = root / "o2i.pdf"
            manifest = root / "o2i.pdf.manifest.json"
            CHECKER.write_manifest(root, pdf, manifest)
            self.assertEqual(
                [],
                CHECKER.source_binding_errors(root, pdf, manifest),
            )

    def test_manifest_rejects_stale_sources_and_pdf(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = self._publication_root(Path(directory))
            pdf = root / "o2i.pdf"
            manifest = root / "o2i.pdf.manifest.json"
            CHECKER.write_manifest(root, pdf, manifest)
            (root / "img" / "figure.png").write_bytes(b"changed")
            pdf.write_bytes(b"changed pdf")
            self.assertEqual(
                [
                    "publication source fingerprint differs",
                    "versioned PDF digest differs from its publication manifest",
                ],
                CHECKER.source_binding_errors(root, pdf, manifest),
            )

    def test_manifest_schema_is_closed(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            manifest = Path(directory) / "manifest.json"
            manifest.write_text(
                json.dumps(
                    {
                        "schema": CHECKER.MANIFEST_SCHEMA,
                        "source_sha256": "0" * 64,
                        "pdf_sha256": "1" * 64,
                        "unexpected": "value",
                    }
                ),
                encoding="utf-8",
            )
            with self.assertRaisesRegex(
                CHECKER.PdfFreshnessError,
                "invalid shape",
            ):
                CHECKER.read_manifest(manifest)

    def test_main_accepts_matching_publication(self) -> None:
        with patch.object(CHECKER, "freshness_errors", return_value=[]):
            self.assertEqual(
                0,
                CHECKER.main(
                    [
                        "check",
                        "--root",
                        ".",
                        "--versioned",
                        "o2i.pdf",
                        "--rendered",
                        "rendered.pdf",
                        "--manifest",
                        "o2i.pdf.manifest.json",
                    ]
                ),
            )

    def _publication_root(self, root: Path) -> Path:
        (root / "img").mkdir()
        (root / "acc").mkdir()
        (root / "utl").mkdir()
        (root / "o2i.md").write_text(
            "# O2I\n\n"
            "!include snippet.hs\n\n"
            "![Figure](img/figure.png)\n",
            encoding="utf-8",
        )
        (root / "README.md").write_text("# O2I\n", encoding="utf-8")
        (root / "ACKNOWLEDGEMENTS.md").write_text(
            "# Acknowledgements\n",
            encoding="utf-8",
        )
        (root / "snippet.hs").write_text("answer = 42\n", encoding="ascii")
        (root / "img" / "figure.png").write_bytes(b"pixels")
        (root / "acc" / "figure.tex").write_text(
            "\\begin{tikzpicture}\\end{tikzpicture}\n",
            encoding="ascii",
        )
        (root / "toPDF.sh").write_text("#!/bin/sh\n", encoding="ascii")
        (root / "utl" / "render-archimate-profile.py").write_text(
            "# generated profile\n",
            encoding="ascii",
        )
        (root / "utl" / "render-paper-figures.sh").write_text(
            "#!/bin/sh\n",
            encoding="ascii",
        )
        (root / "o2i.pdf").write_bytes(b"pdf")
        return root


if __name__ == "__main__":
    unittest.main()
