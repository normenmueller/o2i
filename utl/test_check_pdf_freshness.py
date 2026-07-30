"""Focused tests for White Paper source binding and render consistency."""

from __future__ import annotations

from contextlib import redirect_stderr, redirect_stdout
import importlib.util
import io
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

RENDERER_CONTRACT = {
    "acquisition_revision": "0" * 40,
    "schema": CHECKER.RENDERER_CONTRACT_SCHEMA,
    "tool": "md2pdf",
    "version": "1.2.3",
}
MANIFEST_RENDERER = {"tool": "md2pdf", "version": "1.2.3"}


class PdfFreshnessTest(unittest.TestCase):
    def test_installed_renderer_version_is_parsed(self) -> None:
        completed = subprocess.CompletedProcess(
            args=[],
            returncode=0,
            stdout="md2pdf, v1.2.3, (C) 2026 nemron\n",
            stderr="",
        )
        with patch.object(CHECKER.subprocess, "run", return_value=completed):
            self.assertEqual("1.2.3", CHECKER.installed_renderer_version())

    def test_renderer_rejects_mismatched_installed_version(self) -> None:
        with (
            patch.object(
                CHECKER,
                "read_renderer_contract",
                return_value=RENDERER_CONTRACT,
            ),
            patch.object(
                CHECKER,
                "installed_renderer_version",
                return_value="1.2.2",
            ),
        ):
            self.assertEqual(
                [
                    "installed md2pdf version 1.2.2 differs from required 1.2.3",
                ],
                CHECKER.renderer_version_errors(Path(".")),
            )

    def test_renderer_contract_schema_is_closed(self) -> None:
        payload = dict(RENDERER_CONTRACT, unexpected="value")
        with self.assertRaisesRegex(
            CHECKER.PdfFreshnessError,
            "invalid shape",
        ):
            CHECKER._validated_renderer_contract(payload, "renderer contract")

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

    def test_snippet_contract_accepts_unique_ordered_markers(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = self._snippet_root(
                Path(directory),
                'snippetStart="-- start", snippetEnd="-- end"',
                "-- start\nanswer = 42\n-- end\n",
            )
            self.assertIn(
                (root / "snippet.hs").resolve(),
                CHECKER.publication_inputs(root),
            )

    def test_snippet_contract_rejects_missing_start_marker(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = self._snippet_root(
                Path(directory),
                'snippetStart="-- start", snippetEnd="-- end"',
                "answer = 42\n-- end\n",
            )
            with self.assertRaisesRegex(
                CHECKER.PdfFreshnessError,
                "snippetStart marker 0 times",
            ):
                CHECKER.publication_inputs(root)

    def test_snippet_contract_rejects_missing_end_marker(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = self._snippet_root(
                Path(directory),
                'snippetStart="-- start", snippetEnd="-- end"',
                "-- start\nanswer = 42\n",
            )
            with self.assertRaisesRegex(
                CHECKER.PdfFreshnessError,
                "snippetEnd marker 0 times",
            ):
                CHECKER.publication_inputs(root)

    def test_snippet_contract_rejects_duplicate_start_marker(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = self._snippet_root(
                Path(directory),
                'snippetStart="-- start", snippetEnd="-- end"',
                "-- start\nanswer = 42\n-- start\n-- end\n",
            )
            with self.assertRaisesRegex(
                CHECKER.PdfFreshnessError,
                "snippetStart marker 2 times",
            ):
                CHECKER.publication_inputs(root)

    def test_snippet_contract_rejects_duplicate_end_marker(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = self._snippet_root(
                Path(directory),
                'snippetStart="-- start", snippetEnd="-- end"',
                "-- start\n-- end\nanswer = 42\n-- end\n",
            )
            with self.assertRaisesRegex(
                CHECKER.PdfFreshnessError,
                "snippetEnd marker 2 times",
            ):
                CHECKER.publication_inputs(root)

    def test_snippet_contract_rejects_reversed_markers(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = self._snippet_root(
                Path(directory),
                'snippetStart="-- start", snippetEnd="-- end"',
                "-- end\nanswer = 42\n-- start\n",
            )
            with self.assertRaisesRegex(
                CHECKER.PdfFreshnessError,
                "places snippetStart after snippetEnd",
            ):
                CHECKER.publication_inputs(root)

    def test_snippet_contract_rejects_unpaired_options(self) -> None:
        for options in ('snippetStart="-- start"', 'snippetEnd="-- end"'):
            with self.subTest(options=options):
                with tempfile.TemporaryDirectory() as directory:
                    root = self._snippet_root(
                        Path(directory),
                        options,
                        "-- start\nanswer = 42\n-- end\n",
                    )
                    with self.assertRaisesRegex(
                        CHECKER.PdfFreshnessError,
                        "must declare snippetStart and snippetEnd together",
                    ):
                        CHECKER.publication_inputs(root)

    def test_snippet_contract_rejects_duplicate_options(self) -> None:
        options = (
            'snippetStart="-- start", snippetStart="-- start", '
            'snippetEnd="-- end"',
            'snippetStart="-- start", snippetEnd="-- end", '
            'snippetEnd="-- end"',
        )
        for duplicate in options:
            with self.subTest(options=duplicate):
                with tempfile.TemporaryDirectory() as directory:
                    root = self._snippet_root(
                        Path(directory),
                        duplicate,
                        "-- start\nanswer = 42\n-- end\n",
                    )
                    with self.assertRaisesRegex(
                        CHECKER.PdfFreshnessError,
                        "invalid or duplicate",
                    ):
                        CHECKER.publication_inputs(root)

    def test_snippet_contract_rejects_invalid_options(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = self._snippet_root(
                Path(directory),
                'snippetStart=--start, snippetEnd="-- end"',
                "-- start\nanswer = 42\n-- end\n",
            )
            with self.assertRaisesRegex(
                CHECKER.PdfFreshnessError,
                "invalid or duplicate snippetStart option",
            ):
                CHECKER.publication_inputs(root)

    def test_main_accepts_valid_source_contracts(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = self._snippet_root(
                Path(directory),
                'snippetStart="-- start", snippetEnd="-- end"',
                "-- start\nanswer = 42\n-- end\n",
            )
            output = io.StringIO()
            with redirect_stdout(output):
                self.assertEqual(
                    0,
                    CHECKER.main(["sources", "--root", str(root)]),
                )
            self.assertIn("source contracts are current", output.getvalue())

    def test_main_rejects_invalid_source_contracts(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = self._snippet_root(
                Path(directory),
                'snippetStart="-- start", snippetEnd="-- end"',
                "answer = 42\n-- end\n",
            )
            errors = io.StringIO()
            with redirect_stderr(errors):
                self.assertEqual(
                    1,
                    CHECKER.main(["sources", "--root", str(root)]),
                )
            self.assertIn("snippetStart marker 0 times", errors.getvalue())

    def test_manifest_binds_current_sources_and_pdf(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = self._publication_root(Path(directory))
            pdf = root / "o2i.pdf"
            manifest = root / "o2i.pdf.manifest.json"
            CHECKER.write_manifest(root, pdf, manifest)
            payload = CHECKER.read_manifest(manifest)
            self.assertEqual(MANIFEST_RENDERER, payload["renderer"])
            self.assertEqual(
                [],
                CHECKER.source_binding_errors(root, pdf, manifest),
            )

    def test_manifest_rejects_renderer_identity_drift(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = self._publication_root(Path(directory))
            pdf = root / "o2i.pdf"
            manifest = root / "o2i.pdf.manifest.json"
            CHECKER.write_manifest(root, pdf, manifest)
            contract = dict(RENDERER_CONTRACT, version="1.2.4")
            (root / CHECKER.RENDERER_CONTRACT).write_text(
                json.dumps(contract, indent=2, sort_keys=True) + "\n",
                encoding="utf-8",
            )
            self.assertEqual(
                [
                    "publication source fingerprint differs",
                    "publication renderer identity differs",
                ],
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
                        "renderer": MANIFEST_RENDERER,
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
        with (
            patch.object(CHECKER, "renderer_version_errors", return_value=[]),
            patch.object(CHECKER, "freshness_errors", return_value=[]),
        ):
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

    def test_main_rejects_mismatched_renderer(self) -> None:
        errors = io.StringIO()
        with (
            patch.object(
                CHECKER,
                "renderer_version_errors",
                return_value=[
                    "installed md2pdf version 1.2.2 differs from required 1.2.3",
                ],
            ),
            redirect_stderr(errors),
        ):
            self.assertEqual(
                1,
                CHECKER.main(["renderer", "--root", "."]),
            )
        self.assertIn("Publication renderer is invalid", errors.getvalue())

    def test_main_prints_acquisition_revision_for_ci(self) -> None:
        output = io.StringIO()
        with (
            patch.object(
                CHECKER,
                "read_renderer_contract",
                return_value=RENDERER_CONTRACT,
            ),
            redirect_stdout(output),
        ):
            self.assertEqual(
                0,
                CHECKER.main(
                    [
                        "contract",
                        "--root",
                        ".",
                        "--field",
                        "acquisition-revision",
                    ]
                ),
            )
        self.assertEqual("0" * 40 + "\n", output.getvalue())

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
        (root / CHECKER.RENDERER_CONTRACT).write_text(
            json.dumps(RENDERER_CONTRACT, indent=2, sort_keys=True) + "\n",
            encoding="utf-8",
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

    def _snippet_root(self, root: Path, options: str, source: str) -> Path:
        publication = self._publication_root(root)
        (publication / "o2i.md").write_text(
            f"# O2I\n\n!include`{options}` snippet.hs\n",
            encoding="utf-8",
        )
        (publication / "snippet.hs").write_text(source, encoding="utf-8")
        return publication


if __name__ == "__main__":
    unittest.main()
