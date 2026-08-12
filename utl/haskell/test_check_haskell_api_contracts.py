import unittest
from pathlib import Path
from subprocess import CompletedProcess
from tempfile import TemporaryDirectory
from unittest.mock import patch

import check_haskell_api_contracts as contracts


class HaskellApiContractTest(unittest.TestCase):
    def test_relational_internal_imports_are_executor_only(self):
        declarations = (
            "import O2I.Validation.Relational.Internal\n",
            "import qualified O2I.Validation.Relational.Internal\n",
            "import safe O2I.Validation.Relational.Internal\n",
            'import "o2i-core" O2I.Validation.Relational.Internal\n',
            'import qualified "o2i-core" '
            "O2I.Validation.Relational.Internal as Internal\n",
            "import O2I.Validation.Relational.Internal qualified\n",
            "import\n  qualified\n  "
            "O2I.Validation.Relational.Internal\n",
            "import {-# SOURCE #-} safe qualified "
            '"o2i-core" O2I.Validation.Relational.Internal\n',
        )
        for declaration in declarations:
            with self.subTest(declaration=declaration):
                with TemporaryDirectory() as temporary:
                    root = Path(temporary)
                    source = root / "spc/lib/core/src"
                    evaluator = (
                        source / "O2I/Validation/Relational/Eval.hs"
                    )
                    author = source / "O2I/Language/Macro.hs"
                    evaluator.parent.mkdir(parents=True)
                    author.parent.mkdir(parents=True)
                    evaluator.write_text(declaration)
                    author.write_text(declaration)

                    with self.assertRaisesRegex(
                        RuntimeError,
                        "O2I/Language/Macro.hs",
                    ):
                        contracts.check_relational_internal_import_boundary(
                            root
                        )

    def test_import_scanner_ignores_comments_and_package_strings(self):
        source = """
-- import O2I.Validation.Relational.Internal
{- import qualified O2I.Validation.Relational.Internal -}
import "O2I.Validation.Relational.Internal" O2I.Language.Macro
"""

        self.assertEqual(
            contracts.imported_modules(source),
            ("O2I.Language.Macro",),
        )

    def test_compiler_command_uses_the_exact_project_and_build(self):
        project = Path("/tmp/o2i/spc")
        build = Path("/tmp/o2i/build")
        source = Path("/tmp/o2i/Client.hs")
        output = Path("/tmp/o2i/output")

        command = contracts.compiler_command(
            project, "cabal.foundation.project", build, "o2i-core", source,
            output
        )

        self.assertIn(f"--project-dir={project}", command)
        self.assertIn("--project-file=cabal.foundation.project", command)
        self.assertIn(f"--builddir={build}", command)
        self.assertIn("exec", command)
        self.assertIn("-fdiagnostics-as-json", command)
        self.assertEqual(command[command.index("-package") + 1], "o2i-core")

    def test_private_compiler_uses_source_tree_without_public_package(self):
        project = Path("/tmp/o2i/spc")
        build = Path("/tmp/o2i/build")
        source = Path("/tmp/o2i/PrivateFailure.hs")
        source_dir = Path("/tmp/o2i/spc/lib/core/src")
        output = Path("/tmp/o2i/output")

        command = contracts.private_compiler_command(
            project, None, build, source, source_dir, output
        )

        self.assertIn(f"-i{source_dir}", command)
        self.assertNotIn("o2i-core", command)
        self.assertEqual(command[-1], str(source))

    @patch.object(contracts, "compile_source")
    def test_compile_pass_checks_every_external_client(self, compile_source):
        compile_source.return_value = CompletedProcess([], 0, "", "")
        contract = contracts.PackageContract(
            "o2i-core", ("FirstClient.hs", "SecondClient.hs"), ()
        )

        contracts.check_compile_pass(
            Path("/tmp/o2i"),
            Path("/tmp/o2i/spc"),
            None,
            Path("/tmp/o2i/build"),
            contract,
        )

        self.assertEqual(
            [call.args[-1] for call in compile_source.call_args_list],
            ["FirstClient.hs", "SecondClient.hs"],
        )

    @patch.object(contracts, "check_compile_pass")
    @patch.object(contracts, "check_compile_failure")
    @patch.object(contracts, "check_relational_internal_import_boundary")
    def test_package_selection_limits_public_and_private_contracts(
        self, check_boundary, check_compile_failure, check_compile_pass
    ):
        with patch.object(contracts, "PRIVATE_COMPILE_FAILURES", ()), \
             patch.object(contracts, "PRIVATE_COMPILE_PASSES", ()):
            contracts.check_contracts(
                Path("/tmp/o2i"),
                Path("/tmp/o2i/spc"),
                Path("/tmp/o2i/build"),
                frozenset({"o2i-archimate-profile"}),
            )

        check_boundary.assert_not_called()
        self.assertGreater(check_compile_failure.call_count, 0)
        self.assertTrue(
            all(
                call.args[4] == "o2i-archimate-profile"
                for call in check_compile_failure.call_args_list
            )
        )
        self.assertEqual(
            [call.args[-1].package for call in check_compile_pass.call_args_list],
            ["o2i-archimate-profile"],
        )

    def test_package_selection_rejects_unknown_package(self):
        with self.assertRaisesRegex(ValueError, "unknown API-contract packages"):
            contracts.check_contracts(
                Path("/tmp/o2i"),
                Path("/tmp/o2i/spc"),
                Path("/tmp/o2i/build"),
                frozenset({"o2i-unknown"}),
            )

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

    def test_parses_ghc_910_structured_diagnostics(self):
        output = (
            '{"severity":"Error","code":1928,'
            '"span":{"file":"Fixture.hs"}}'
        )

        diagnostics = contracts.parse_diagnostics(output)

        self.assertEqual(len(diagnostics), 1)
        self.assertEqual(contracts.error_code(diagnostics[0]), "GHC-01928")

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
                None,
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
                None,
                Path("/tmp/o2i/build"),
                "o2i-core",
                failure,
            )


if __name__ == "__main__":
    unittest.main()
