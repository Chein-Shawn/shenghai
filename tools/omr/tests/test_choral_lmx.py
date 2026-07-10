import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from choral_lmx import linearize_musicxml


class ChoralLMXTests(unittest.TestCase):
    def test_linearizes_note_rest_and_lyric(self):
        xml = """<score-partwise><part id='P1'><measure number='1'><attributes><key><fifths>0</fifths></key><time><beats>4</beats><beat-type>4</beat-type></time></attributes><note><pitch><step>C</step><octave>4</octave></pitch><duration>1</duration><staff>1</staff><lyric><text>la</text></lyric></note><note><rest/><duration>1</duration><staff>1</staff></note></measure></part></score-partwise>"""
        tokens = linearize_musicxml(xml)
        self.assertIn("NOTE:C:0:4:1:STAFF:1", tokens)
        self.assertIn("REST:1:STAFF:1", tokens)
        self.assertIn("LYRIC:la", tokens)
        self.assertEqual(tokens[0], "<bos>")
        self.assertEqual(tokens[-1], "<eos>")
