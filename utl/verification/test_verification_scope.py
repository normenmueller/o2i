#!/usr/bin/env python3
"""Tests for conservative path-sensitive O2I verification selection."""

from __future__ import annotations

from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest

import verification_scope as scope


ROOT = Path(__file__).resolve().parents[2]
VERIFY = ROOT / "utl" / "verify.sh"
WORKFLOW = ROOT / ".github/workflows/verify.yml"


def git(root: Path, *arguments: str) -> str:
    """Run one deterministic Git command in a test repository."""
    result = subprocess.run(
        ["git", "-C", str(root), *arguments],
        check=True,
        capture_output=True,
        text=True,
    )
    return result.stdout.strip()


def repository_paths(root: Path) -> set[str]:
    """Return the exact repository inventory with or without Git metadata."""
    if (root / ".git").exists():
        result = subprocess.run(
            ["git", "-C", str(root), "ls-files", "-z"],
            check=True,
            capture_output=True,
        )
        paths = {
            value.decode("utf-8")
            for value in result.stdout.split(b"\0")
            if value
        }
        return {path for path in paths if (root / path).is_file()}
    return {
        path.relative_to(root).as_posix()
        for path in root.rglob("*")
        if path.is_file()
    }


class VerificationPathMatrixTests(unittest.TestCase):
    """Keep stage ownership explicit and conservative."""

    def test_representative_path_matrix(self) -> None:
        cases = {
            ".agents/skills/o2i-formalization/SKILL.md": {
                "licensing",
                "governance",
            },
            ".ai4x/STATE.md": {"licensing", "governance"},
            ".ai4x/operations/haskell-authoring.md": {
                "licensing",
                "governance",
                "haskell",
            },
            ".ai4x/operations/modeling.md": {
                "licensing",
                "governance",
                "model",
            },
            ".ai4x/operations/publication.md": {
                "licensing",
                "governance",
                "paper",
            },
            ".github/workflows/verify.yml": set(scope.STAGES),
            "meta/o2i.archimate": {"licensing", "model", "haskell"},
            "spec/lib/adapter/amx/src/O2I/Adapter/AMX.hs": {
                "licensing",
                "haskell",
            },
            "spec/lib/core/src/O2I/Graph.hs": {
                "licensing",
                "haskell",
                "paper",
            },
            "spec/ctr/archimate/profile.json": {
                "licensing",
                "model",
                "haskell",
                "paper",
            },
            "utl/governance/ai4x_contract.py": {
                "licensing",
                "governance",
            },
            "utl/haskell/check_cabal_plan.py": {"licensing", "haskell"},
            "README.md": {"licensing", "paper"},
            "doc/README.md": {"licensing", "paper"},
            "doc/misc/wtf.md": {"licensing", "paper"},
            "doc/guide/ethos.md": {"licensing", "paper"},
            "doc/paper/o2i.md": {"licensing", "paper"},
            "doc/paper/o2i.pdf": {"licensing", "paper"},
            "doc/paper/o2i.pdf.manifest.json": {"licensing", "paper"},
            "doc/images/O2I Modellzustand.png": {"licensing", "paper"},
            "doc/resources/md2pdf.json": {"licensing", "paper"},
            "utl/paper/render-paper.sh": {"licensing", "paper"},
            "doc/model/illustration.archimate": {
                "licensing", "model", "haskell", "paper",
            },
            "CHANGELOG.md": {"licensing"},
            "LICENSING.md": {"licensing"},
            "REUSE.toml": {"licensing"},
            "LICENSES/Apache-2.0.txt": {"licensing"},
            "utl/licensing/check-license-texts.sh": {"licensing"},
            "utl/licensing/check_license_assignments.py": {"licensing"},
            "utl/licensing/test_license_assignments.py": {"licensing"},
            "utl/model/repository_view_contract.py": {
                "licensing",
                "model",
            },
        }
        for path, expected in cases.items():
            with self.subTest(path=path):
                self.assertEqual(expected, set(scope.stages_for_path(path) or ()))

    def test_multiple_paths_form_one_union(self) -> None:
        selection = scope.classify_paths(
            (".ai4x/STATE.md", "meta/o2i.archimate", "README.md")
        )
        self.assertEqual("selective", selection.mode)
        self.assertEqual(
            {"licensing", "governance", "model", "haskell", "paper"},
            set(selection.stages),
        )

    def test_model_source_selects_executable_candidate_gate(self) -> None:
        selection = scope.classify_paths(("meta/o2i.archimate",))

        self.assertEqual("selective", selection.mode)
        self.assertEqual(
            {"licensing", "model", "haskell"},
            set(selection.stages),
        )

    def test_foundation_routes_the_real_model_to_the_typed_view_checker(
        self,
    ) -> None:
        contract = VERIFY.read_text(encoding="utf-8")

        self.assertIn(
            "o2i-amx:o2i-amx-repository-view-check",
            contract,
        )
        self.assertIn(
            '"$candidate_view_checker" "$root/meta/o2i.archimate"',
            contract,
        )
        self.assertNotIn("check-executable-views.py", contract)
        self.assertFalse(
            (ROOT / "utl" / "model" / "check-executable-views.py").exists()
        )
        self.assertFalse(
            (
                ROOT
                / "utl"
                / "model"
                / "test_check_executable_views.py"
            ).exists()
        )

    def test_repository_view_tools_route_to_model_and_licensing(self) -> None:
        paths = (
            "utl/model/repository_view_contract.py",
            "utl/model/test_repository_view_contract.py",
            "utl/model/focused_view_contract.py",
            "utl/model/test_focused_view_contract.py",
        )
        for path in paths:
            with self.subTest(path=path):
                selection = scope.classify_paths((path,))
                self.assertEqual("selective", selection.mode)
                self.assertEqual("path-matrix", selection.reason)
                self.assertEqual(
                    {"licensing", "model"},
                    set(selection.stages),
                )

    def test_unknown_path_selects_every_stage(self) -> None:
        selection = scope.classify_paths(("future/contract.txt",))
        self.assertEqual("full", selection.mode)
        self.assertEqual("unknown-path", selection.reason)
        self.assertEqual(set(scope.STAGES), set(selection.stages))

    def test_empty_change_set_selects_every_stage(self) -> None:
        selection = scope.classify_paths(())
        self.assertEqual("full", selection.mode)
        self.assertEqual("empty-change-set", selection.reason)

    def test_neutral_change_keeps_licensing_verification(self) -> None:
        selection = scope.classify_paths(("CHANGELOG.md",))
        self.assertEqual({"licensing"}, set(selection.stages))
        self.assertEqual("path-matrix", selection.reason)

    def test_every_current_repository_path_is_known(self) -> None:
        paths = repository_paths(ROOT)
        paths.update(
            {
                "utl/verification/verification_scope.py",
                "utl/verification/test_verification_scope.py",
            }
        )
        unknown = sorted(
            path for path in paths if scope.stages_for_path(path) is None
        )
        self.assertEqual([], unknown)

    def test_gitless_repository_inventory_uses_export_tree(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / ".ai4x").mkdir()
            (root / ".ai4x/STATE.md").write_text("state\n", encoding="ascii")
            (root / "README.md").write_text("readme\n", encoding="ascii")
            self.assertEqual(
                {".ai4x/STATE.md", "README.md"},
                repository_paths(root),
            )


class CheckpointVerificationTests(unittest.TestCase):
    """Checkpoint reduction must account for every local input without altering CI."""

    def repository(self, root: Path) -> Path:
        git(root, "init", "--quiet")
        git(root, "config", "user.email", "o2i@example.invalid")
        git(root, "config", "user.name", "O2I Test")
        model = root / "doc/model/illustration.archimate"
        model.parent.mkdir(parents=True)
        model.write_text("original model\n", encoding="utf-8")
        (root / ".gitignore").write_text("ignored/\n", encoding="utf-8")
        git(root, "add", ".")
        git(root, "commit", "--quiet", "-m", "base")
        return model

    def selection(self, root: Path) -> scope.Selection:
        return scope.select_for_event(root, "checkpoint", "", "", "false")

    def test_staged_unstaged_untracked_and_ignored_inputs(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            model = self.repository(root)
            model.write_text("staged model\n", encoding="utf-8")
            git(root, "add", "doc/model/illustration.archimate")
            model.write_text("original model\n", encoding="utf-8")
            untracked = root / "doc/model/new model.archimate"
            untracked.write_text("new\n", encoding="utf-8")
            ignored = root / "ignored/unsafe.py"
            ignored.parent.mkdir()
            ignored.write_text("ignored\n", encoding="utf-8")
            self.assertEqual(
                {"doc/model/illustration.archimate", "doc/model/new model.archimate"},
                set(scope.checkpoint_paths(root) or ()),
            )
            self.assertEqual({"licensing", "model"}, set(self.selection(root).stages))

    def test_each_working_tree_layer_can_select_the_checkpoint(self) -> None:
        for state in ("staged", "unstaged", "untracked"):
            with self.subTest(state=state), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                model = self.repository(root)
                if state == "untracked":
                    model = model.with_name("new.archimate")
                model.write_text("changed\n", encoding="utf-8")
                if state == "staged":
                    git(root, "add", "doc/model/illustration.archimate")
                self.assertEqual("illustration-checkpoint", self.selection(root).reason)

    def test_rename_keeps_old_and_new_paths_and_deletion_remains_visible(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            model = self.repository(root)
            git(root, "mv", "doc/model/illustration.archimate", "unknown.archimate")
            self.assertEqual(
                {"doc/model/illustration.archimate", "unknown.archimate"},
                set(scope.checkpoint_paths(root) or ()),
            )
            self.assertEqual("unknown-path", self.selection(root).reason)
            (root / "unknown.archimate").unlink()
            self.assertIn("unknown.archimate", scope.checkpoint_paths(root) or ())
            self.assertEqual(scope.ALL_STAGES, self.selection(root).stages)

    def test_intermediate_staged_rename_path_cannot_be_hidden(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.repository(root)
            (root / "spec").mkdir()
            git(root, "mv", "doc/model/illustration.archimate", "spec/intermediate.hs")
            (root / "spec/intermediate.hs").rename(root / "doc/model/renamed.archimate")
            paths = {
                "doc/model/illustration.archimate", "spec/intermediate.hs",
                "doc/model/renamed.archimate",
            }
            self.assertEqual(paths, set(scope.checkpoint_paths(root) or ()))
            self.assertEqual(scope.classify_paths(paths), self.selection(root))
            self.assertIn("haskell", self.selection(root).stages)

    def test_unstaged_deletion_and_unknown_untracked_file_are_not_lost(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.repository(root).unlink()
            self.assertEqual(
                ("doc/model/illustration.archimate",), scope.checkpoint_paths(root)
            )
            (root / "unknown.txt").write_text("unknown\n", encoding="utf-8")
            self.assertEqual("unknown-path", self.selection(root).reason)

    def test_mixed_changes_keep_the_regular_matrix(self) -> None:
        for other in (
            "spec/cli/src/app/Main.hs", "README.md", "utl/verify.sh",
            ".github/workflows/verify.yml", "future/unknown.txt",
            "doc/model/tool.py", "meta/o2i.archimate",
        ):
            with self.subTest(other=other), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                model = self.repository(root)
                model.write_text("changed\n", encoding="utf-8")
                added = root / other
                added.parent.mkdir(parents=True, exist_ok=True)
                added.write_text("mixed\n", encoding="utf-8")
                self.assertEqual(
                    scope.classify_paths(("doc/model/illustration.archimate", other)),
                    self.selection(root),
                )

    def test_missing_git_empty_tree_forced_and_explicit_ranges_fail_closed(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.assertEqual("unavailable-working-tree", self.selection(root).reason)
            self.repository(root)
            self.assertEqual("empty-change-set", self.selection(root).reason)
            for base, head, forced, reason in (
                ("", "", "true", "forced-checkpoint"),
                ("HEAD", "", "false", "checkpoint-range-unsupported"),
                ("", "HEAD", "false", "checkpoint-range-unsupported"),
                (git(root, "rev-parse", "HEAD"), git(root, "rev-parse", "HEAD"),
                 "false", "checkpoint-range-unsupported"),
            ):
                selection = scope.select_for_event(root, "checkpoint", base, head, forced)
                self.assertEqual(reason, selection.reason)
                self.assertEqual(scope.ALL_STAGES, selection.stages)

    def test_same_illustration_commit_keeps_pr_and_push_checks(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            model = self.repository(root)
            base = git(root, "rev-parse", "HEAD")
            model.write_text("changed\n", encoding="utf-8")
            self.assertEqual({"licensing", "model"}, set(self.selection(root).stages))
            git(root, "add", ".")
            git(root, "commit", "--quiet", "-m", "model change")
            head = git(root, "rev-parse", "HEAD")
            for event in ("push", "pull_request"):
                self.assertEqual(
                    {"licensing", "model", "haskell", "paper"},
                    set(scope.select_for_event(root, event, base, head, "false").stages),
                )

    def test_checkpoint_dispatch_executes_only_selected_stages(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.repository(root).write_text("changed\n", encoding="utf-8")
            selector = root / "utl/verification/verification_scope.py"
            selector.parent.mkdir(parents=True)
            shutil.copyfile(Path(scope.__file__), selector)
            runner = root / "utl/verify.sh"
            source = VERIFY.read_text(encoding="utf-8")
            for stage in scope.STAGES:
                source = re.sub(
                    rf"(?ms)^verify_{stage}\(\) \{{.*?^\}}",
                    lambda match, stage=stage:
                        f"verify_{stage}() {{\n  printf '{stage}\\n' >> calls\n}}",
                    source,
                    count=1,
                )
            runner.write_text(source, encoding="utf-8")
            git(root, "add", "utl")
            git(root, "commit", "--quiet", "-m", "test runner")
            result = subprocess.run(
                ["sh", str(runner), "checkpoint"], cwd=root,
                capture_output=True, text=True,
            )
            self.assertEqual(0, result.returncode, result.stderr)
            self.assertEqual("licensing\nmodel\n", (root / "calls").read_text())
            self.assertIn("illustration-checkpoint", result.stderr)
            for program, expected_exit, expected_calls in (
                ("pass\n", 2, ""),
                ("raise SystemExit(9)\n", 9, ""),
                ("print('licensing\\n$(touch executed)')\n", 2, "licensing\n"),
            ):
                with self.subTest(program=program):
                    (root / "calls").unlink(missing_ok=True)
                    selector.write_text(program, encoding="utf-8")
                    failed = subprocess.run(
                        ["sh", str(runner), "checkpoint"], cwd=root,
                        capture_output=True, text=True,
                    )
                    self.assertEqual(expected_exit, failed.returncode, failed.stderr)
                    calls = root / "calls"
                    self.assertEqual(expected_calls, calls.read_text() if calls.exists() else "")
                    self.assertFalse((root / "executed").exists())
            (root / "calls").unlink(missing_ok=True)
            selector.write_text("print('licensing\\nmodel\\npaper')\n", encoding="utf-8")
            runner.write_text(
                source.replace("printf 'model\\n' >> calls", "return 7"),
                encoding="utf-8",
            )
            failed = subprocess.run(
                ["sh", str(runner), "checkpoint"], cwd=root,
                capture_output=True, text=True,
            )
            self.assertEqual(7, failed.returncode, failed.stderr)
            self.assertEqual("licensing\n", (root / "calls").read_text())


class VerificationDiffTests(unittest.TestCase):
    """Keep event and Git-range fallbacks safe."""

    def test_manual_unknown_and_forced_events_select_every_stage(self) -> None:
        cases = (
            ("workflow_dispatch", "", "", "false", "manual-dispatch"),
            ("schedule", "", "", "false", "unknown-event"),
            ("push", "0" * 40, "1" * 40, "false", "unavailable-diff"),
            ("push", "1" * 40, "2" * 40, "true", "forced-push"),
            ("push", "1" * 40, "2" * 40, "maybe", "invalid-force-flag"),
        )
        for event, base, head, forced, reason in cases:
            with self.subTest(reason=reason):
                selection = scope.select_for_event(
                    ROOT,
                    event,
                    base,
                    head,
                    forced,
                )
                self.assertEqual(set(scope.STAGES), set(selection.stages))
                self.assertEqual(reason, selection.reason)

    def test_unavailable_git_object_selects_every_stage(self) -> None:
        selection = scope.select_for_event(
            ROOT,
            "push",
            "1" * 40,
            "2" * 40,
            "false",
        )
        self.assertEqual("unavailable-diff", selection.reason)
        self.assertEqual(set(scope.STAGES), set(selection.stages))

    def test_rename_classifies_old_and_new_paths(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            git(root, "init", "--quiet")
            git(root, "config", "user.email", "o2i@example.invalid")
            git(root, "config", "user.name", "O2I Test")
            source = root / "spec/source.hs"
            source.parent.mkdir(parents=True)
            source.write_text("module Source where\n", encoding="ascii")
            git(root, "add", "spec/source.hs")
            git(root, "commit", "--quiet", "-m", "base")
            base = git(root, "rev-parse", "HEAD")

            git(root, "mv", "spec/source.hs", "LICENSING.md")
            git(root, "commit", "--quiet", "-m", "rename")
            head = git(root, "rev-parse", "HEAD")

            paths = scope.changed_paths(root, "push", base, head)
            self.assertIsNotNone(paths)
            self.assertEqual(
                {"spec/source.hs", "LICENSING.md"},
                set(paths or ()),
            )
            selection = scope.classify_paths(paths or ())
            self.assertEqual({"licensing", "haskell"}, set(selection.stages))

    def test_pull_request_uses_only_changes_since_merge_base(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            git(root, "init", "--quiet", "--initial-branch=trunk")
            git(root, "config", "user.email", "o2i@example.invalid")
            git(root, "config", "user.name", "O2I Test")
            (root / "LICENSE").write_text("base\n", encoding="ascii")
            git(root, "add", "LICENSE")
            git(root, "commit", "--quiet", "-m", "base")
            git(root, "branch", "feature")

            (root / "README.md").write_text("target\n", encoding="ascii")
            git(root, "add", "README.md")
            git(root, "commit", "--quiet", "-m", "target")
            base = git(root, "rev-parse", "HEAD")

            git(root, "checkout", "--quiet", "feature")
            source = root / "spec/source.hs"
            source.parent.mkdir(parents=True)
            source.write_text("module Source where\n", encoding="ascii")
            git(root, "add", "spec/source.hs")
            git(root, "commit", "--quiet", "-m", "feature")
            head = git(root, "rev-parse", "HEAD")

            paths = scope.changed_paths(root, "pull_request", base, head)
            self.assertEqual(("spec/source.hs",), paths)
            selection = scope.classify_paths(paths or ())
            self.assertEqual({"licensing", "haskell"}, set(selection.stages))

    def test_github_output_is_complete_and_stable(self) -> None:
        selection = scope.classify_paths((".ai4x/STATE.md",))
        self.assertEqual(
            """\
licensing=true
governance=true
model=false
haskell=false
paper=false
mode=selective
reason=path-matrix""",
            scope.github_output(selection),
        )


class VerificationWorkflowTests(unittest.TestCase):
    """Keep all required checks visible while heavy work is conditional."""

    def test_haskell_job_consumes_the_frozen_foundation_contract(self) -> None:
        content = WORKFLOW.read_text(encoding="utf-8")
        haskell_job = content.split("\n  haskell:\n", maxsplit=1)[1].split(
            "\n  paper:\n",
            maxsplit=1,
        )[0]
        foundation_tools = haskell_job.split(
            "\n      - name: Install Foundation verification tools\n",
            maxsplit=1,
        )[1].split("\n      - name:", maxsplit=1)[0]
        self.assertIn("CABAL_VERSION: 3.16.1.0", haskell_job)
        self.assertIn("GHC_VERSION: 9.10.3", haskell_job)
        self.assertIn("REUSE_VERSION: 6.2.0", haskell_job)
        self.assertIn("timeout-minutes: 60", haskell_job)
        self.assertNotIn("CABAL_VERSION: 3.14.2.0", haskell_job)
        self.assertNotIn("GHC_VERSION: 9.6.5", haskell_job)
        self.assertIn(
            'pipx install "reuse[charset-normalizer]==$REUSE_VERSION"',
            foundation_tools,
        )
        self.assertIn(
            "if [ \"$O2I_EVENT_NAME\" = 'pull_request' ]; then",
            haskell_job,
        )
        self.assertIn("./utl/verify.sh foundation", haskell_job)
        self.assertIn("./utl/verify.sh haskell", haskell_job)
        for contract in (
            "spec/.ghc-version",
            "spec/cabal.project",
            "spec/cabal.project.freeze",
            "spec/cabal.foundation.project",
            "spec/cabal.foundation.project.freeze",
        ):
            with self.subTest(contract=contract):
                self.assertIn(contract, haskell_job)

    def test_remote_triggers_are_pull_request_manual_and_release_only(self) -> None:
        content = WORKFLOW.read_text(encoding="utf-8")
        self.assertIn(
            """\
on:
  push:
    tags:
      - 'o2i-v*'
  pull_request:
  workflow_dispatch:
""",
            content,
        )
        self.assertIn(
            "O2I_FORCE_FULL: ${{ startsWith(github.ref, "
            "'refs/tags/o2i-v') }}",
            content,
        )
        self.assertNotIn("github.event.forced", content)

    def test_workflow_preserves_names_and_uses_each_scope_output(self) -> None:
        content = WORKFLOW.read_text(encoding="utf-8")
        cases = (
            ("Repository licensing", "licensing"),
            ("Change governance", "governance"),
            ("Model contracts", "model"),
            ("Haskell specification", "haskell"),
            ("White Paper", "paper"),
        )
        for name, stage in cases:
            with self.subTest(stage=stage):
                self.assertIn(f"name: {name}", content)
                self.assertIn(f"steps.scope.outputs.{stage}", content)
        selected_steps = (
            ("Install licensing verification tools", "licensing"),
            ("Verify repository licensing", "licensing"),
            ("Verify change governance", "governance"),
            ("Verify model contracts", "model"),
            ("Set up Haskell", "haskell"),
            ("Restore Haskell dependencies and tools", "haskell"),
            ("Install Foundation verification tools", "haskell"),
            ("Verify Haskell specification", "haskell"),
            ("Install White Paper dependencies", "paper"),
            ("Verify White Paper", "paper"),
        )
        for name, stage in selected_steps:
            with self.subTest(step=name):
                self.assertIn(
                    f"- name: {name}\n"
                    f"        if: steps.scope.outputs.{stage} == 'true'",
                    content,
                )
                self.assertIn(
                    f"if: steps.scope.outputs.{stage} != 'true'",
                    content,
                )
        self.assertEqual(
            5,
            content.count("python3 -B utl/verification/verification_scope.py"),
        )
        self.assertEqual(5, content.count("fetch-depth: 0"))
        self.assertNotIn("\n    paths:", content)
        self.assertIn("workflow_dispatch:", content)
        actions = re.findall(r"(?m)^\s+uses: ([^@\s]+)@([^\s]+)", content)
        self.assertGreater(len(actions), 0)
        for action, revision in actions:
            with self.subTest(action=action):
                self.assertRegex(revision, r"^[0-9a-f]{40}$")


if __name__ == "__main__":
    unittest.main()
