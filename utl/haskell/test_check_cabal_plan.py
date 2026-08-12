import json
import unittest
from pathlib import Path
from tempfile import TemporaryDirectory

import check_cabal_plan as plan


class CabalPlanTest(unittest.TestCase):
    def write_contract(self, root: Path) -> tuple[Path, Path, Path]:
        project = root / "cabal.project"
        freeze = root / "cabal.project.freeze"
        solved = root / "plan.json"
        project.write_text("index-state: 2026-08-07T18:07:13Z\n")
        freeze.write_text(
            "constraints: any.base ==4.20.2.0, any.text ==2.1.3\n"
            "index-state: hackage.haskell.org 2026-08-07T18:07:13Z\n"
        )
        solved.write_text(
            json.dumps(
                {
                    "install-plan": [
                        {
                            "style": "local",
                            "pkg-name": "o2i-core",
                            "pkg-version": "0.2.0.0",
                        },
                        {
                            "type": "pre-existing",
                            "pkg-name": "base",
                            "pkg-version": "4.20.2.0",
                        },
                        {
                            "type": "configured",
                            "pkg-name": "text",
                            "pkg-version": "2.1.3",
                        },
                    ]
                }
            )
        )
        return project, freeze, solved

    def test_accepts_exact_frozen_solution(self):
        with TemporaryDirectory() as temporary:
            paths = self.write_contract(Path(temporary))
            plan.check(*paths)

    def test_rejects_unpinned_solved_package(self):
        with TemporaryDirectory() as temporary:
            project, freeze, solved = self.write_contract(Path(temporary))
            value = json.loads(solved.read_text())
            value["install-plan"].append(
                {
                    "type": "configured",
                    "pkg-name": "aeson",
                    "pkg-version": "2.2.5.0",
                }
            )
            solved.write_text(json.dumps(value))

            with self.assertRaisesRegex(ValueError, "aeson: frozen=missing"):
                plan.check(project, freeze, solved)

    def test_rejects_stale_frozen_package(self):
        with TemporaryDirectory() as temporary:
            project, freeze, solved = self.write_contract(Path(temporary))
            freeze.write_text(
                "constraints: any.base ==4.20.2.0, any.text ==2.1.3, "
                "any.aeson ==2.2.5.0\n"
                "index-state: hackage.haskell.org "
                "2026-08-07T18:07:13Z\n"
            )

            with self.assertRaisesRegex(ValueError, "aeson: frozen=2.2.5.0"):
                plan.check(project, freeze, solved)

    def test_rejects_plan_without_non_local_packages(self):
        with TemporaryDirectory() as temporary:
            project, freeze, solved = self.write_contract(Path(temporary))
            value = json.loads(solved.read_text())
            value["install-plan"] = [value["install-plan"][0]]
            solved.write_text(json.dumps(value))

            with self.assertRaisesRegex(
                ValueError, "no non-local package versions found"
            ):
                plan.check(project, freeze, solved)

    def test_rejects_index_state_drift(self):
        with TemporaryDirectory() as temporary:
            project, freeze, solved = self.write_contract(Path(temporary))
            project.write_text("index-state: 2026-08-08T00:00:00Z\n")

            with self.assertRaisesRegex(ValueError, "index-state mismatch"):
                plan.check(project, freeze, solved)

    def test_rejects_allow_newer(self):
        with TemporaryDirectory() as temporary:
            project, freeze, solved = self.write_contract(Path(temporary))
            project.write_text(
                "index-state: 2026-08-07T18:07:13Z\nallow-newer: base\n"
            )

            with self.assertRaisesRegex(ValueError, "allow-newer is forbidden"):
                plan.check(project, freeze, solved)

    def test_ignores_commented_out_pin(self):
        with TemporaryDirectory() as temporary:
            project, freeze, solved = self.write_contract(Path(temporary))
            freeze.write_text(
                "constraints: any.base ==4.20.2.0\n"
                "-- constraints: any.text ==2.1.3\n"
                "index-state: hackage.haskell.org "
                "2026-08-07T18:07:13Z\n"
            )

            with self.assertRaisesRegex(ValueError, "text: frozen=missing"):
                plan.check(project, freeze, solved)

    def test_rejects_non_object_plan_root(self):
        with TemporaryDirectory() as temporary:
            project, freeze, solved = self.write_contract(Path(temporary))
            solved.write_text(json.dumps([]))

            with self.assertRaisesRegex(ValueError, "plan root is not an object"):
                plan.check(project, freeze, solved)

    def test_rejects_non_object_plan_entry(self):
        with TemporaryDirectory() as temporary:
            project, freeze, solved = self.write_contract(Path(temporary))
            value = json.loads(solved.read_text())
            value["install-plan"].append("invalid")
            solved.write_text(json.dumps(value))

            with self.assertRaisesRegex(ValueError, "malformed plan entry"):
                plan.check(project, freeze, solved)


if __name__ == "__main__":
    unittest.main()
