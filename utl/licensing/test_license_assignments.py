#!/usr/bin/env python3
"""Tests for O2I's path-based licensing assignment contract."""

from __future__ import annotations

from pathlib import Path
import tempfile
import unittest

from check_license_assignments import validate_repository


VALID_CONFIG = """\
version = 1

[[annotations]]
path = ["README.md"]
precedence = "override"
SPDX-FileCopyrightText = "2026 nemron"
SPDX-License-Identifier = "CC-BY-4.0"

[[annotations]]
path = ["REUSE.toml", "utl/**"]
precedence = "override"
SPDX-FileCopyrightText = "2026 nemron"
SPDX-License-Identifier = "Apache-2.0"
"""


class LicenseAssignmentTests(unittest.TestCase):
    """Reject ambiguous or competing repository license assignments."""

    def fixture(
        self,
        config: str = VALID_CONFIG,
    ) -> tuple[Path, tuple[str, ...]]:
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        root = Path(temporary.name)
        (root / "utl").mkdir()
        (root / "README.md").write_text("O2I\n", encoding="ascii")
        (root / "REUSE.toml").write_text(config, encoding="utf-8")
        (root / "utl/check.py").write_text("pass\n", encoding="ascii")
        return root, ("README.md", "REUSE.toml", "utl/check.py")

    def test_accepts_one_path_assignment_per_repository_file(self) -> None:
        root, paths = self.fixture()
        self.assertEqual((), validate_repository(root, paths))

    def test_rejects_overlapping_path_assignments(self) -> None:
        config = VALID_CONFIG.replace(
            'path = ["REUSE.toml", "utl/**"]',
            'path = ["README.md", "REUSE.toml", "utl/**"]',
        )
        root, paths = self.fixture(config)
        violations = validate_repository(root, paths)
        self.assertTrue(
            any(
                "README.md" in item and "exactly one" in item
                for item in violations
            )
        )

    def test_rejects_overlapping_patterns_within_one_annotation(self) -> None:
        config = VALID_CONFIG.replace(
            'path = ["REUSE.toml", "utl/**"]',
            'path = ["REUSE.toml", "utl/**", "utl/check.py"]',
        )
        root, paths = self.fixture(config)
        violations = validate_repository(root, paths)
        self.assertTrue(
            any(
                "utl/check.py" in item and "exactly one" in item
                for item in violations
            )
        )

    def test_requires_an_explicit_assignment_for_reuse_toml(self) -> None:
        config = VALID_CONFIG.replace('"REUSE.toml", ', "")
        root, paths = self.fixture(config)
        violations = validate_repository(root, paths)
        self.assertTrue(
            any(
                "REUSE.toml" in item and "matched: none" in item
                for item in violations
            )
        )

    def test_rejects_an_unsupported_license_identifier(self) -> None:
        config = VALID_CONFIG.replace("CC-BY-4.0", "MIT")
        root, paths = self.fixture(config)
        violations = validate_repository(root, paths)
        self.assertTrue(
            any(
                "closed license set" in item and "MIT" in item
                for item in violations
            )
        )

    def test_rejects_multiple_identifiers_in_one_annotation(self) -> None:
        config = VALID_CONFIG.replace(
            'SPDX-License-Identifier = "Apache-2.0"',
            'SPDX-License-Identifier = ["Apache-2.0", "CC-BY-4.0"]',
        )
        root, paths = self.fixture(config)
        violations = validate_repository(root, paths)
        self.assertTrue(
            any("exactly one permitted license" in item for item in violations)
        )

    def test_rejects_competing_embedded_spdx_license(self) -> None:
        root, paths = self.fixture()
        marker = "SPDX-License-" + "Identifier: Apache-2.0\n"
        (root / "README.md").write_text(marker, encoding="ascii")
        violations = validate_repository(root, paths)
        self.assertTrue(any("embedded SPDX" in item for item in violations))

    def test_rejects_competing_embedded_spdx_copyright(self) -> None:
        root, paths = self.fixture()
        marker = "SPDX-File" + "CopyrightText: 2026 nemron\n"
        (root / "README.md").write_text(marker, encoding="ascii")
        violations = validate_repository(root, paths)
        self.assertTrue(any("embedded SPDX" in item for item in violations))

    def test_rejects_nested_reuse_toml_authority(self) -> None:
        root, paths = self.fixture()
        nested = root / "utl/REUSE.toml"
        nested.write_text(VALID_CONFIG, encoding="utf-8")
        violations = validate_repository(root, (*paths, "utl/REUSE.toml"))
        self.assertTrue(
            any("nested licensing authority" in item for item in violations)
        )

    def test_canonical_license_texts_need_no_path_annotation(self) -> None:
        root, paths = self.fixture()
        license_path = root / "LICENSES/Apache-2.0.txt"
        license_path.parent.mkdir()
        license_path.write_text("Apache License\n", encoding="ascii")
        self.assertEqual(
            (),
            validate_repository(root, (*paths, "LICENSES/Apache-2.0.txt")),
        )


if __name__ == "__main__":
    unittest.main()
