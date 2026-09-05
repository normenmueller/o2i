import unittest
from pathlib import Path
from tempfile import TemporaryDirectory

import check_atomic_cutover as cutover


class AtomicCutoverTest(unittest.TestCase):
    def write_target(self, root: Path) -> None:
        project = root / "spc" / "cabal.project"
        project.parent.mkdir(parents=True)
        project.write_text(
            "packages:\n"
            + "".join(
                f"  {relative}\n"
                for relative, _, _ in cutover.TARGET_PACKAGES
            )
            + "\nindex-state: 2026-08-07T18:07:13Z\n",
            encoding="utf-8",
        )
        for relative, name, dependencies in cutover.TARGET_PACKAGES:
            package = root / "spc" / relative
            package.mkdir(parents=True)
            dependency_lines = ["    base >=4.20 && <4.21"]
            dependency_lines.extend(
                f"    {dependency} ==0.3.0.0"
                for dependency in sorted(dependencies)
            )
            (package / f"{name}.cabal").write_text(
                f"name: {name}\n"
                "version: 0.3.0.0\n\n"
                "library\n"
                "  build-depends:\n"
                + ",\n".join(dependency_lines)
                + "\n  hs-source-dirs: src\n\n"
                "test-suite test\n"
                "  build-depends: base\n",
                encoding="utf-8",
            )

    def test_accepts_exact_target(self) -> None:
        with TemporaryDirectory() as temporary:
            root = Path(temporary)
            self.write_target(root)
            cutover.check(root)

    def test_rejects_wrong_root_registration(self) -> None:
        with TemporaryDirectory() as temporary:
            root = Path(temporary)
            self.write_target(root)
            project = root / "spc" / "cabal.project"
            project.write_text(
                project.read_text(encoding="utf-8").replace(
                    "  cli\n", "  lib/inspection\n  cli\n"
                ),
                encoding="utf-8",
            )
            with self.assertRaisesRegex(ValueError, "target packages"):
                cutover.check(root)

    def test_rejects_legacy_package_directory(self) -> None:
        with TemporaryDirectory() as temporary:
            root = Path(temporary)
            self.write_target(root)
            (root / "spc" / "lib" / "inspection").mkdir()
            with self.assertRaisesRegex(ValueError, "still exists"):
                cutover.check(root)

    def test_rejects_legacy_registration_marker(self) -> None:
        with TemporaryDirectory() as temporary:
            root = Path(temporary)
            self.write_target(root)
            verify = root / "utl" / "verify.sh"
            verify.parent.mkdir(parents=True)
            verify.write_text("package=o2i-inspection\n", encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "legacy marker"):
                cutover.check(root)

    def test_rejects_legacy_cli_command(self) -> None:
        with TemporaryDirectory() as temporary:
            root = Path(temporary)
            self.write_target(root)
            source = root / "spc" / "cli" / "src" / "Command.hs"
            source.parent.mkdir(parents=True)
            source.write_text('command = "inspect"\n', encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "legacy CLI"):
                cutover.check(root)

    def test_rejects_wrong_production_dependency_edge(self) -> None:
        with TemporaryDirectory() as temporary:
            root = Path(temporary)
            self.write_target(root)
            cli = root / "spc" / "cli" / "o2i-cli.cabal"
            cli.write_text(
                cli.read_text(encoding="utf-8").replace(
                    "    o2i-operation ==0.3.0.0",
                    "    o2i-core ==0.2.0.0,\n"
                    "    o2i-operation ==0.3.0.0",
                ),
                encoding="utf-8",
            )
            with self.assertRaisesRegex(ValueError, "target dependencies"):
                cutover.check(root)


if __name__ == "__main__":
    unittest.main()
