import unittest
from pathlib import Path
from subprocess import CompletedProcess
from tempfile import TemporaryDirectory
from unittest.mock import patch

import check_haskell_api_contracts as contracts


class HaskellApiContractTest(unittest.TestCase):
    def test_core_inventory_requires_exact_sources_and_public_modules(self):
        with TemporaryDirectory() as temporary:
            package = Path(temporary)
            for source_name in contracts.CORE_SOURCE_FILES:
                source = package / source_name
                source.parent.mkdir(parents=True, exist_ok=True)
                source.write_text("module Fixture where\n")
            modules = ",\n    ".join(sorted(contracts.CORE_EXPOSED_MODULES))
            (package / "o2i-core.cabal").write_text(
                "cabal-version: 3.0\n\nlibrary\n"
                f"  exposed-modules:\n    {modules}\n"
                "  hs-source-dirs: src\n"
            )

            contracts.check_core_package_inventory(package)

    def test_core_inventory_rejects_unexpected_source(self):
        with TemporaryDirectory() as temporary:
            package = Path(temporary)
            for source_name in contracts.CORE_SOURCE_FILES:
                source = package / source_name
                source.parent.mkdir(parents=True, exist_ok=True)
                source.write_text("module Fixture where\n")
            extra = package / "src/O2I/Legacy.hs"
            extra.parent.mkdir(parents=True, exist_ok=True)
            extra.write_text("module O2I.Legacy where\n")
            modules = ",\n    ".join(sorted(contracts.CORE_EXPOSED_MODULES))
            (package / "o2i-core.cabal").write_text(
                "cabal-version: 3.0\n\nlibrary\n"
                f"  exposed-modules:\n    {modules}\n"
            )

            with self.assertRaisesRegex(RuntimeError, "O2I/Legacy.hs"):
                contracts.check_core_package_inventory(package)

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

    def test_compiler_command_selects_the_exact_main_unit_when_registered(self):
        with TemporaryDirectory() as temporary:
            build = Path(temporary)
            package_db = build / "packagedb/ghc-9.10.3"
            package_db.mkdir(parents=True)
            unit = "o2i-core-0.2.0.0-inplace"
            (package_db / f"{unit}.conf").write_text("")

            command = contracts.compiler_command(
                Path("/tmp/o2i/spc"),
                "cabal.foundation.project",
                build,
                "o2i-core",
                Path("/tmp/o2i/Client.hs"),
                Path("/tmp/o2i/output"),
            )

            self.assertEqual(command[command.index("-package-id") + 1], unit)

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

    def test_evidence_record_update_inventory_is_exactly_twelve_plus_nineteen(
        self,
    ):
        contracts.check_evidence_record_update_inventory()

        domains = [
            contract.module
            for contract in contracts.EVIDENCE_RECORD_UPDATES
        ]
        identities = {
            (
                contract.module,
                contract.evidence_type,
                contract.projection,
            )
            for contract in contracts.EVIDENCE_RECORD_UPDATES
        }
        self.assertEqual(len(domains), 31)
        self.assertEqual(domains.count("O2I.Structure"), 12)
        self.assertEqual(domains.count("O2I.Semantics.Input"), 19)
        self.assertEqual(len(identities), 31)

    def test_evidence_record_update_inventory_rejects_missing_case(self):
        incomplete = contracts.EVIDENCE_RECORD_UPDATES[:-1]

        with patch.object(
            contracts, "EVIDENCE_RECORD_UPDATES", incomplete
        ):
            with self.assertRaisesRegex(RuntimeError, "exactly 31"):
                contracts.check_evidence_record_update_inventory()

    @patch.object(contracts, "assert_compile_failure_at")
    @patch.object(contracts.subprocess, "run")
    def test_every_evidence_record_update_is_one_isolated_source(
        self, run, assert_failure
    ):
        run.return_value = CompletedProcess([], 1, "", "")
        sources = []

        def observe(_root, source, _display, _expected, _result):
            sources.append(source.read_text())

        assert_failure.side_effect = observe
        contracts.check_evidence_record_updates(
            Path("/tmp/o2i"),
            Path("/tmp/o2i/spc"),
            "cabal.foundation.project",
            Path("/tmp/o2i/build"),
        )

        self.assertEqual(run.call_count, 31)
        self.assertEqual(assert_failure.call_count, 31)
        self.assertEqual(len(sources), 31)
        for source, contract in zip(
            sources, contracts.EVIDENCE_RECORD_UPDATES
        ):
            self.assertIn(f"import {contract.module}", source)
            self.assertIn(
                f"forge :: {contract.evidence_type} "
                f"-> {contract.evidence_type}",
                source,
            )
            self.assertEqual(source.count("evidence {"), 1)
            self.assertIn(
                f"evidence {{{contract.projection} = undefined}}",
                source,
            )

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
    def test_package_selection_limits_public_and_private_contracts(
        self, check_compile_failure, check_compile_pass
    ):
        with patch.object(contracts, "PRIVATE_COMPILE_FAILURES", ()):
            contracts.check_contracts(
                Path("/tmp/o2i"),
                Path("/tmp/o2i/spc"),
                Path("/tmp/o2i/build"),
                frozenset({"o2i-archimate-profile"}),
            )
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
