#!/usr/bin/env python3
"""Tests for conservative path-sensitive O2I verification selection."""

from __future__ import annotations

from pathlib import Path
import re
import subprocess
import tempfile
import unittest

import verification_scope as scope


ROOT = Path(__file__).resolve().parents[1]
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


class VerificationPathMatrixTests(unittest.TestCase):
    """Keep stage ownership explicit and conservative."""

    def test_representative_path_matrix(self) -> None:
        cases = {
            ".ai4X/STATE.md": {"governance"},
            ".ai4X/operations/haskell-authoring.md": {
                "governance",
                "haskell",
            },
            ".ai4X/operations/modeling.md": {"governance", "model"},
            ".ai4X/operations/publication.md": {
                "governance",
                "paper",
            },
            ".github/workflows/verify.yml": set(scope.STAGES),
            "mdl/o2i.archimate": {"model"},
            "spc/lib/adapter/amx/src/O2I/Adapter/AMX.hs": {"haskell"},
            "spc/lib/core/src/O2I/Graph.hs": {"haskell", "paper"},
            "spc/ctr/archimate/profile.json": {
                "model",
                "haskell",
                "paper",
            },
            "README.md": {"paper"},
            "wtf.md": {"paper"},
            "CHANGELOG.md": set(),
            "utl/render-archimate-profile.py": {"model", "paper"},
        }
        for path, expected in cases.items():
            with self.subTest(path=path):
                self.assertEqual(expected, set(scope.stages_for_path(path) or ()))

    def test_multiple_paths_form_one_union(self) -> None:
        selection = scope.classify_paths(
            (".ai4X/STATE.md", "mdl/o2i.archimate", "README.md")
        )
        self.assertEqual("selective", selection.mode)
        self.assertEqual(
            {"governance", "model", "paper"},
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

    def test_neutral_change_keeps_repository_hygiene(self) -> None:
        selection = scope.classify_paths(("CHANGELOG.md",))
        self.assertEqual({"governance"}, set(selection.stages))
        self.assertEqual("repository-hygiene", selection.reason)

    def test_every_current_repository_path_is_known(self) -> None:
        result = subprocess.run(
            ["git", "-C", str(ROOT), "ls-files", "-z"],
            check=True,
            capture_output=True,
        )
        paths = {
            value.decode("utf-8")
            for value in result.stdout.split(b"\0")
            if value
        }
        paths.update(
            {
                "utl/verification_scope.py",
                "utl/test_verification_scope.py",
            }
        )
        unknown = sorted(
            path for path in paths if scope.stages_for_path(path) is None
        )
        self.assertEqual([], unknown)


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
            source = root / "spc/source.hs"
            source.parent.mkdir(parents=True)
            source.write_text("module Source where\n", encoding="ascii")
            git(root, "add", "spc/source.hs")
            git(root, "commit", "--quiet", "-m", "base")
            base = git(root, "rev-parse", "HEAD")

            git(root, "mv", "spc/source.hs", "LICENSE")
            git(root, "commit", "--quiet", "-m", "rename")
            head = git(root, "rev-parse", "HEAD")

            paths = scope.changed_paths(root, "push", base, head)
            self.assertIsNotNone(paths)
            self.assertEqual({"spc/source.hs", "LICENSE"}, set(paths or ()))
            selection = scope.classify_paths(paths or ())
            self.assertEqual({"haskell"}, set(selection.stages))

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
            source = root / "spc/source.hs"
            source.parent.mkdir(parents=True)
            source.write_text("module Source where\n", encoding="ascii")
            git(root, "add", "spc/source.hs")
            git(root, "commit", "--quiet", "-m", "feature")
            head = git(root, "rev-parse", "HEAD")

            paths = scope.changed_paths(root, "pull_request", base, head)
            self.assertEqual(("spc/source.hs",), paths)
            selection = scope.classify_paths(paths or ())
            self.assertEqual({"haskell"}, set(selection.stages))

    def test_github_output_is_complete_and_stable(self) -> None:
        selection = scope.classify_paths((".ai4X/STATE.md",))
        self.assertEqual(
            """\
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

    def test_workflow_preserves_names_and_uses_each_scope_output(self) -> None:
        content = WORKFLOW.read_text(encoding="utf-8")
        cases = (
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
            ("Verify change governance", "governance"),
            ("Verify model contracts", "model"),
            ("Set up Haskell", "haskell"),
            ("Restore Haskell dependencies and tools", "haskell"),
            ("Install Haskell verification tools", "haskell"),
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
            4,
            content.count("python3 -B utl/verification_scope.py"),
        )
        self.assertEqual(4, content.count("fetch-depth: 0"))
        self.assertNotIn("\n    paths:", content)
        self.assertIn("workflow_dispatch:", content)
        actions = re.findall(r"(?m)^\s+uses: ([^@\s]+)@([^\s]+)", content)
        self.assertGreater(len(actions), 0)
        for action, revision in actions:
            with self.subTest(action=action):
                self.assertRegex(revision, r"^[0-9a-f]{40}$")


if __name__ == "__main__":
    unittest.main()
