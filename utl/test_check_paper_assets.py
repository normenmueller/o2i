import importlib.util
import tempfile
import unittest
from pathlib import Path


MODULE_PATH = Path(__file__).with_name("check-paper-assets.py")
SPEC = importlib.util.spec_from_file_location("check_paper_assets", MODULE_PATH)
assert SPEC is not None and SPEC.loader is not None
CHECKER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(CHECKER)


def document_with(*targets: str) -> dict:
    return {
        "pandoc-api-version": [1, 23],
        "meta": {},
        "blocks": [
            {
                "t": "Para",
                "c": [
                    {
                        "t": "Image",
                        "c": [["", [], []], [], [target, ""]],
                    }
                ],
            }
            for target in targets
        ],
    }


class PaperAssetTest(unittest.TestCase):
    def test_existing_nonempty_local_image_passes(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            image = root / "img" / "O2I Syntax.png"
            image.parent.mkdir()
            image.write_bytes(b"png")

            self.assertEqual(
                [],
                CHECKER.validate_assets(
                    document_with("img/O2I%20Syntax.png"),
                    root,
                ),
            )

    def test_missing_and_empty_images_are_reported_deterministically(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            empty = root / "empty.png"
            empty.touch()

            self.assertEqual(
                [
                    "paper image is missing or empty: empty.png",
                    "paper image is missing or empty: missing.png",
                ],
                CHECKER.validate_assets(
                    document_with("missing.png", "empty.png"),
                    root,
                ),
            )

    def test_external_image_is_outside_local_asset_contract(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            self.assertEqual(
                [],
                CHECKER.validate_assets(
                    document_with("https://example.org/image.png"),
                    Path(directory),
                ),
            )

    def test_image_cannot_escape_paper_workspace(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            self.assertEqual(
                ["paper image escapes workspace: ../image.png"],
                CHECKER.validate_assets(
                    document_with("../image.png"),
                    Path(directory),
                ),
            )

    def test_malformed_image_node_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaisesRegex(ValueError, "malformed Pandoc Image node"):
                CHECKER.validate_assets(
                    {"t": "Image", "c": []},
                    Path(directory),
                )


if __name__ == "__main__":
    unittest.main()
