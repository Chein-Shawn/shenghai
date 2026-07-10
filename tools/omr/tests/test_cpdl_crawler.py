import unittest

from tools.omr.crawl_cpdl import parse_wikitext


class CPDLVoiceFilterTests(unittest.TestCase):
    def accepted(self, voicing: str) -> bool:
        text = f"{{{{Voicing|4|{voicing}}}}}"
        return bool(parse_wikitext("Example", text)["accepted"])

    def test_accepts_target_voice_counts(self):
        for value in ("SATB", "SSATB", "SSATBB", "SSAATTBB"):
            with self.subTest(value=value):
                self.assertTrue(self.accepted(value))

    def test_rejects_more_than_two_divisi_per_role(self):
        self.assertFalse(self.accepted("SSSAATTB"))

    def test_rejects_polychoral_over_limit(self):
        self.assertFalse(self.accepted("SAT.SSATB"))

    def test_extracts_media_and_license(self):
        record = parse_wikitext(
            "Example",
            "{{Voicing|4|SATB}} {{Copy|CPDL}} [[Media:score.pdf|{{pdf}}]] [[Media:score.mxl|{{XML}}]]",
        )
        self.assertEqual(record["license_status"], "cpdl_license")
        self.assertEqual(record["pdf_files"], ["score.pdf"])
        self.assertEqual(record["musicxml_files"], ["score.mxl"])


if __name__ == "__main__":
    unittest.main()
