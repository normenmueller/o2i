import unittest
from pathlib import Path
from subprocess import CompletedProcess
from unittest.mock import patch

import check_haskell_api_contracts as contracts


class HaskellApiContractTest(unittest.TestCase):
    def test_compiler_command_uses_the_exact_project_and_build(self):
        project = Path("/tmp/o2i/spc")
        build = Path("/tmp/o2i/build")
        source = Path("/tmp/o2i/Client.hs")
        output = Path("/tmp/o2i/output")

        command = contracts.compiler_command(
            project, build, "o2i-core", source, output
        )

        self.assertIn(f"--project-dir={project}", command)
        self.assertIn(f"--builddir={build}", command)
        self.assertIn("exec", command)
        self.assertIn("-ddump-json", command)
        self.assertEqual(command[command.index("-package") + 1], "o2i-core")

    def test_parses_only_structured_ghc_diagnostics(self):
        output = "\n".join(
            (
                "Configuration is affected by cabal.project",
                '{"span":{"file":"Fixture.hs"},'
                '"messageClass":"MCDiagnostic SevError Just GHC-31891"}',
            )
        )

        diagnostics = contracts.parse_diagnostics(output)

        self.assertEqual(len(diagnostics), 1)
        self.assertEqual(contracts.error_code(diagnostics[0]), "GHC-31891")

    def test_resolves_fixture_local_diagnostic_paths(self):
        root = Path("/tmp/o2i").resolve()
        diagnostic = {
            "span": {"file": "spc/tst/Fixture.hs"},
            "messageClass": "MCDiagnostic SevError Just GHC-76037",
        }

        self.assertEqual(
            contracts.diagnostic_file(root, diagnostic),
            (root / "spc/tst/Fixture.hs").resolve(),
        )

    @patch.object(contracts, "compile_source")
    def test_compile_failure_rejects_unexpected_success(self, compile_source):
        compile_source.return_value = CompletedProcess([], 0, "", "")
        failure = contracts.CompileFailure(
            "spc/tst/Fixture.hs", (("GHC-31891", 1),)
        )

        with self.assertRaisesRegex(RuntimeError, "unexpectedly compiled"):
            contracts.check_compile_failure(
                Path("/tmp/o2i"),
                Path("/tmp/o2i/spc"),
                Path("/tmp/o2i/build"),
                "o2i-core",
                failure,
            )

    @patch.object(contracts, "compile_source")
    def test_compile_failure_rejects_foreign_spans(self, compile_source):
        diagnostic = (
            '{"span":{"file":"spc/tst/Other.hs"},'
            '"messageClass":"MCDiagnostic SevError Just GHC-31891"}'
        )
        compile_source.return_value = CompletedProcess([], 1, diagnostic, "")
        failure = contracts.CompileFailure(
            "spc/tst/Fixture.hs", (("GHC-31891", 1),)
        )

        with self.assertRaisesRegex(RuntimeError, "non-local diagnostics"):
            contracts.check_compile_failure(
                Path("/tmp/o2i"),
                Path("/tmp/o2i/spc"),
                Path("/tmp/o2i/build"),
                "o2i-core",
                failure,
            )


if __name__ == "__main__":
    unittest.main()
