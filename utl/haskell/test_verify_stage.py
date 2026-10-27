import contextlib
import io
import json
import os
from pathlib import Path
import runpy
import shlex
import subprocess
import sys
from tempfile import TemporaryDirectory
import unittest
from unittest.mock import patch

import check_haskell_api_contracts as contracts
import phase_clock


ROOT = Path(__file__).resolve().parents[2]
STAGE = ROOT / "utl/haskell/verify-stage.sh"
CLOCK = ROOT / "utl/haskell/phase_clock.py"


class CabalStageTest(unittest.TestCase):
    def setUp(self):
        self.directory = TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.work = Path(self.directory.name)
        self.bin = self.work / "bin"
        self.bin.mkdir()
        self.calls = self.work / "calls.jsonl"
        cabal = self.bin / "cabal"
        cabal.write_text(f"#!{sys.executable}\n" + '''
import json, os, sys
args = sys.argv[1:]
commands = {"build", "test", "haddock", "list-bin", "path", "exec", "sdist"}
command = next((a for a in args if a in commands), "unknown")
with open(os.environ["FAKE_CALL_LOG"], "a") as log:
    log.write(json.dumps(args) + "\\n")
print(os.environ.get("FAKE_STDOUT", ""), end="")
print(os.environ.get("FAKE_STDERR", ""), end="", file=sys.stderr)
if command == os.environ.get("FAKE_FAIL_COMMAND"):
    sys.exit(int(os.environ.get("FAKE_STATUS", "37")))
if command in {"list-bin", "path", "exec"} and "-v0" not in args:
    print("DIAGNOSTIC CONTAMINATION")
if command == "list-bin":
    print(os.environ["FAKE_BINARY"])
elif command == "path":
    print(json.dumps({"compiler": {"id": "ghc-9.10.3"}}))
''')
        cabal.chmod(0o755)
        binary = self.bin / "candidate-view"
        self.view_calls = self.work / "view.json"
        binary.write_text(f"#!{sys.executable}\n" +
                          'import json, os, pathlib, sys\n'
                          'pathlib.Path(os.environ["FAKE_VIEW_LOG"]).write_text(json.dumps(sys.argv[1:]))\n'
                          'print("VIEW_OK")\n'
                          'sys.exit(int(os.environ.get("FAKE_VIEW_STATUS", "0")))\n')
        binary.chmod(0o755)
        self.environment = {
            **os.environ, "PATH": str(self.bin) + os.pathsep + os.environ["PATH"],
            "FAKE_CALL_LOG": str(self.calls), "FAKE_BINARY": str(binary),
            "FAKE_VIEW_LOG": str(self.view_calls),
            "O2I_HASKELL_CABAL_VERBOSITY": "2",
        }

    def shell(self, commands, *, scope="foundation", environment=None):
        setup = f'''
set -eu
. {shlex.quote(str(STAGE))}
root={shlex.quote(str(ROOT))}
work={shlex.quote(str(self.work))}
scope={shlex.quote(scope)}
project_file=cabal.foundation.project
cabal_config="$work/config"
logs="$work/logs"
build="$work/normal"
build_log="$logs/build.log"
source_project="$work/archive"
source_logs="$work/archive-logs"
mkdir -p "$logs" "$build" "$source_project" "$source_logs"
begin_phase() {{ printf 'BEGIN:%s\\n' "$1"; }}
run_project_cabal() {{ run_haskell_cabal "$root/spec" "$project_file" "$@"; }}
'''
        return subprocess.run(
            ["sh", "-c", setup + commands], capture_output=True, text=True,
            env={**self.environment, **(environment or {})}, check=False,
        )

    def recorded(self):
        return [json.loads(line) for line in self.calls.read_text().splitlines()]

    def test_haddock_scopes_keep_targets_and_receive_common_options_once(self):
        for scope, expected in (
            ("foundation", ["o2i-core", "o2i-archimate-profile", "o2i-operation", "o2i-amx"]),
            ("complete", ["all"]),
        ):
            with self.subTest(scope=scope):
                result = self.shell("verify_haskell_haddock", scope=scope)
                self.assertEqual(result.returncode, 0, result.stderr)
                args = self.recorded()[-1]
                self.assertIn("-v2", args)
                self.assertEqual(args.count("--ghc-options=-Werror"), 1)
                self.assertIn("--semaphore", args)
                start = args.index("haddock") + 3
                self.assertEqual(args[start:start + len(expected)], expected)

    def test_haddock_forbidden_warnings_fail_for_both_scopes_and_streams(self):
        warnings = (
            "Missing documentation for: Example",
            "Warning: 'Example' is ambiguous.",
            "Warning: 'Example' is out of scope.",
            "Warning: could not find link destinations for: Example",
        )
        for scope in ("foundation", "complete"):
            for stream in ("FAKE_STDOUT", "FAKE_STDERR"):
                for warning in warnings:
                    with self.subTest(scope=scope, stream=stream, warning=warning):
                        result = self.shell(
                            "verify_haskell_haddock\nprintf 'NEXT_PHASE'",
                            scope=scope, environment={stream: warning + "\n"},
                        )
                        self.assertEqual(result.returncode, 1)
                        self.assertNotIn("NEXT_PHASE", result.stdout)

    def test_haddock_preserves_cabal_failure_even_when_warning_present(self):
        for warning in ("", "Missing documentation for: Example\n"):
            result = self.shell(
                "verify_haskell_haddock\nprintf 'NEXT_PHASE'",
                environment={"FAKE_FAIL_COMMAND": "haddock", "FAKE_STATUS": "37",
                             "FAKE_STDERR": warning},
            )
            self.assertEqual(result.returncode, 37)
            self.assertNotIn("NEXT_PHASE", result.stdout)

    def test_diagnostics_keep_machine_path_and_json_probes_quiet(self):
        result = self.shell('''
verify_haskell_candidate_views
run_project_cabal path --output-format=json --compiler-info --builddir="$build"
''')
        self.assertEqual(result.returncode, 0, result.stderr)
        lines = result.stdout.splitlines()
        self.assertEqual(lines[0], "VIEW_OK")
        self.assertEqual(json.loads(self.view_calls.read_text()), [str(ROOT / "meta/o2i.archimate")])
        self.assertIn("o2i-amx:o2i-amx-repository-view-check", self.recorded()[0])
        self.assertEqual(json.loads(lines[1])["compiler"]["id"], "ghc-9.10.3")
        for args in self.recorded():
            self.assertIn("-v0", args)
            self.assertNotIn("-v2", args)
            self.assertIn("--ghc-options=-Werror", args)
            self.assertNotIn("--semaphore", args)

    def test_probe_failure_stops_invocation(self):
        result = self.shell(
            'candidate=$(run_project_cabal list-bin example)\nprintf "NEXT_PHASE"',
            environment={"FAKE_FAIL_COMMAND": "list-bin", "FAKE_STATUS": "43"},
        )
        self.assertEqual(result.returncode, 43)
        self.assertNotIn("NEXT_PHASE", result.stdout)

    def test_candidate_view_failure_stops_stage(self):
        result = self.shell(
            'verify_haskell_candidate_views\nprintf "NEXT_PHASE"',
            environment={"FAKE_VIEW_STATUS": "31"},
        )
        self.assertEqual(result.returncode, 31)
        self.assertNotIn("NEXT_PHASE", result.stdout)

    def test_archive_closure_is_offline_in_distinct_build_tree(self):
        result = self.shell('''
run_project_cabal build all --builddir="$build"
verify_haskell_archive_tests
''')
        self.assertEqual(result.returncode, 0, result.stderr)
        normal, build, tests = self.recorded()
        self.assertIn("all:tests", build)
        self.assertIn("all", tests)
        self.assertIn("--builddir=" + str(self.work / "normal"), normal)
        for args in (build, tests):
            self.assertIn("--offline", args)
            self.assertIn("--builddir=" + str(self.work / "archive/dist-newstyle"), args)
            self.assertIn("--ghc-options=-Werror", args)
        self.assertIn("BEGIN:Haskell archive test-component build", result.stdout)
        self.assertIn("BEGIN:Haskell archive test command", result.stdout)

    def test_archive_build_failure_does_not_execute_tests(self):
        result = self.shell(
            "verify_haskell_archive_tests\nprintf 'NEXT_PHASE'",
            environment={"FAKE_FAIL_COMMAND": "build", "FAKE_STATUS": "29"},
        )
        self.assertEqual(result.returncode, 29)
        self.assertEqual(len(self.recorded()), 1)
        self.assertIn("BEGIN:Haskell archive test-component build", result.stdout)
        self.assertNotIn("BEGIN:Haskell archive test command", result.stdout)
        self.assertNotIn("NEXT_PHASE", result.stdout)

    def test_native_semaphore_is_only_requested_for_compilation_commands(self):
        commands = ("build", "test", "haddock", "list-bin", "path", "exec", "sdist", "--numeric-version")
        result = self.shell("\n".join(f"run_project_cabal {command}" for command in commands))
        self.assertEqual(result.returncode, 0, result.stderr)
        for command, args in zip(commands, self.recorded(), strict=True):
            with self.subTest(command=command):
                self.assertEqual(args.count("--semaphore"), int(command in {"build", "test", "haddock"}))
                self.assertNotIn("--enable-build-info", args)
                self.assertFalse(any(arg.startswith(("-j", "--jobs", "--ghc-option=-j", "--ghc-options=-j")) for arg in args))

    def test_native_command_failure_is_preserved_without_retry(self):
        for command in ("build", "test", "haddock"):
            with self.subTest(command=command):
                before = len(self.recorded()) if self.calls.exists() else 0
                result = self.shell(f'run_project_cabal {command}\nprintf "NEXT_PHASE"', environment={
                    "FAKE_FAIL_COMMAND": command, "FAKE_STATUS": "47",
                })
                self.assertEqual(result.returncode, 47)
                self.assertNotIn("NEXT_PHASE", result.stdout)
                self.assertEqual(len(self.recorded()) - before, 1)
                self.assertIn("--semaphore", self.recorded()[-1])

    def test_closed_verbosity_selector_rejects_other_values(self):
        result = self.shell("run_project_cabal build all", environment={
            "O2I_HASKELL_CABAL_VERBOSITY": "3",
        })
        self.assertEqual(result.returncode, 2)
        self.assertFalse(self.calls.exists())

    def test_api_exec_project_flags_leave_fixture_ghc_arguments_unchanged(self):
        constructors = (
            contracts.compiler_command(
                ROOT / "spec", "cabal.foundation.project", self.work / "normal",
                "o2i-core", self.work / "Public.hs", self.work / "output",
            ),
            contracts.private_compiler_command(
                ROOT / "spec", "cabal.foundation.project", self.work / "normal",
                self.work / "Private.hs", ROOT / "spec/lib/core/src", self.work / "output",
            ),
        )
        for command in constructors:
            result = subprocess.run(command, capture_output=True, text=True,
                                    env=self.environment, check=False)
            self.assertEqual(result.returncode, 0, result.stderr)
            args = self.recorded()[-1]
            separator = args.index("--")
            self.assertIn("-v0", args[:separator])
            self.assertIn("--ghc-options=-Werror", args[:separator])
            self.assertNotIn("--semaphore", args[:separator])
            self.assertNotIn("--ghc-options=-Werror", args[separator + 1:])
            self.assertIn("-fdiagnostics-as-json", args[separator + 1:])
            self.assertIn("-fforce-recomp", args[separator + 1:])
            self.assertEqual(result.stdout, "")


class ObservationTest(unittest.TestCase):
    def test_elapsed_invalid_or_reversed_samples_stay_unknown(self):
        for start, end in (("", "1"), ("x", "1"), ("2", "1"), ("-1", "1")):
            self.assertEqual(phase_clock.elapsed(start, end), "UNKNOWN")
        self.assertEqual(phase_clock.elapsed("1000000000", "2500000001"), "1.500000001")

    def test_wall_clock_jump_does_not_change_monotonic_samples(self):
        samples = []
        for wall, monotonic in ((100, 1000000000), (-999999, 2500000000)):
            output = io.StringIO()
            with patch.object(phase_clock.time, "time", return_value=wall), \
                 patch.object(phase_clock.time, "monotonic_ns", return_value=monotonic), \
                 contextlib.redirect_stdout(output):
                phase_clock.main(["now"])
            samples.append(output.getvalue().strip())
        self.assertEqual(phase_clock.elapsed(*samples), "1.500000000")

    def test_clock_process_failure_reports_unknown_and_nonzero(self):
        output = io.StringIO()
        with patch.object(sys, "argv", [str(CLOCK), "now"]), \
             patch("time.monotonic_ns", side_effect=OSError("unavailable")), \
             contextlib.redirect_stdout(output), self.assertRaises(SystemExit) as raised:
            runpy.run_path(str(CLOCK), run_name="__main__")
        self.assertEqual(raised.exception.code, 1)
        self.assertEqual(output.getvalue().strip(), "UNKNOWN")


if __name__ == "__main__":
    unittest.main()
