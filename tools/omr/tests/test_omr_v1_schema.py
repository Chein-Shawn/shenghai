import unittest

from omr_v1_schema import CORE_SYMBOL_KINDS, model_kind, normalize_kind, target_index


class OMRV1SchemaTests(unittest.TestCase):
    def test_core_schema_is_stable(self):
        self.assertEqual(len(CORE_SYMBOL_KINDS), 14)
        self.assertEqual(model_kind("notehead"), "notehead")
        self.assertEqual(model_kind("full-notehead"), "notehead")
        self.assertEqual(target_index("barline"), CORE_SYMBOL_KINDS.index("barline"))
        self.assertEqual(model_kind("noteheadBlackOnLine"), "notehead")
        self.assertEqual(model_kind("dynamicCrescendoHairpin"), "repeat_or_direction")

    def test_detail_can_be_preserved_without_becoming_a_v1_target(self):
        self.assertEqual(normalize_kind("Rare Repeat Sign"), "rare_repeat_sign")
        self.assertIsNone(model_kind("part_name"))
        self.assertIsNone(target_index("fermata"))


if __name__ == "__main__":
    unittest.main()
