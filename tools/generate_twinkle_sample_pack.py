#!/usr/bin/env python3

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import html


REPO_ROOT = Path(__file__).resolve().parent.parent
MUSICXML_OUTPUT = REPO_ROOT / "samples" / "musicxml" / "twinkle-multipage-ground-truth.musicxml"
SCORE_OUTPUT_DIR = REPO_ROOT / "samples" / "scores" / "twinkle-sample-pack"
INTACT_OUTPUT_DIR = SCORE_OUTPUT_DIR / "twinkle_intact"
PDF_OUTPUT = INTACT_OUTPUT_DIR / "twinkle-multipage.pdf"
PNG_OUTPUTS = [INTACT_OUTPUT_DIR / f"twinkle-page-{index}.png" for index in range(1, 4)]
README_OUTPUT = SCORE_OUTPUT_DIR / "README.md"

PAGE_WIDTH = 2480
PAGE_HEIGHT = 3508
MARGIN_X = 180
SYSTEM_TOPS = [620, 1900]
SYSTEM_WIDTH = PAGE_WIDTH - MARGIN_X * 2
CLEF_BLOCK_WIDTH = 210
LINE_SPACING = 28
STAFF_HEIGHT = LINE_SPACING * 4
MEASURES_PER_SYSTEM = 4
MEASURES_PER_PAGE = 8
TOTAL_PAGES = 3


@dataclass(frozen=True)
class NoteSpec:
    pitch: str
    value: str


@dataclass(frozen=True)
class MeasureSpec:
    notes: tuple[NoteSpec, ...]
    direction: str | None = None


PHRASE = [
    MeasureSpec(
        notes=(
            NoteSpec("C4", "quarter"),
            NoteSpec("C4", "quarter"),
            NoteSpec("G4", "quarter"),
            NoteSpec("G4", "quarter"),
        ),
        direction="Andante"
    ),
    MeasureSpec(
        notes=(
            NoteSpec("A4", "quarter"),
            NoteSpec("A4", "quarter"),
            NoteSpec("G4", "half"),
        )
    ),
    MeasureSpec(
        notes=(
            NoteSpec("F4", "quarter"),
            NoteSpec("F4", "quarter"),
            NoteSpec("E4", "quarter"),
            NoteSpec("E4", "quarter"),
        )
    ),
    MeasureSpec(
        notes=(
            NoteSpec("D4", "quarter"),
            NoteSpec("D4", "quarter"),
            NoteSpec("C4", "half"),
        )
    ),
    MeasureSpec(
        notes=(
            NoteSpec("G4", "quarter"),
            NoteSpec("G4", "quarter"),
            NoteSpec("F4", "quarter"),
            NoteSpec("F4", "quarter"),
        )
    ),
    MeasureSpec(
        notes=(
            NoteSpec("E4", "quarter"),
            NoteSpec("E4", "quarter"),
            NoteSpec("D4", "half"),
        )
    ),
    MeasureSpec(
        notes=(
            NoteSpec("C4", "quarter"),
            NoteSpec("C4", "quarter"),
            NoteSpec("G4", "quarter"),
            NoteSpec("G4", "quarter"),
        )
    ),
    MeasureSpec(
        notes=(
            NoteSpec("A4", "quarter"),
            NoteSpec("A4", "quarter"),
            NoteSpec("G4", "half"),
        )
    ),
]

MEASURES = []
for page_index in range(TOTAL_PAGES):
    for phrase_index, measure in enumerate(PHRASE):
        direction = measure.direction
        if page_index == 1 and phrase_index == 0:
            direction = "mf"
        elif page_index == 2 and phrase_index == 0:
            direction = "rit."
        MEASURES.append(MeasureSpec(notes=measure.notes, direction=direction))


def make_fonts() -> dict[str, ImageFont.FreeTypeFont]:
    return {
        "title": ImageFont.truetype("/System/Library/Fonts/Supplemental/Times New Roman Bold.ttf", 78),
        "subtitle": ImageFont.truetype("/System/Library/Fonts/Supplemental/Times New Roman Italic.ttf", 34),
        "page": ImageFont.truetype("/System/Library/Fonts/Supplemental/Times New Roman.ttf", 28),
        "direction": ImageFont.truetype("/System/Library/Fonts/Supplemental/Times New Roman Italic.ttf", 34),
        "measure": ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial.ttf", 22),
        "time": ImageFont.truetype("/System/Library/Fonts/Supplemental/Times New Roman Bold.ttf", 50),
        "clef": ImageFont.truetype("/System/Library/Fonts/Apple Symbols.ttf", 92),
    }


def pitch_step(pitch: str) -> str:
    return pitch[0]


def pitch_octave(pitch: str) -> int:
    return int(pitch[-1])


def midi_number(pitch: str) -> int:
    step = pitch_step(pitch)
    octave = pitch_octave(pitch)
    semitone = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}[step]
    return (octave + 1) * 12 + semitone


def note_type_duration(value: str) -> int:
    return {"quarter": 1, "half": 2}[value]


def y_for_pitch(staff_top: int, pitch: str) -> float:
    midi = midi_number(pitch)
    bottom_line_midi = 64  # E4
    step_offset = (midi - bottom_line_midi) / 2
    return staff_top + STAFF_HEIGHT - step_offset * (LINE_SPACING / 2)


def draw_staff(draw: ImageDraw.ImageDraw, x0: int, x1: int, y_top: int) -> None:
    for index in range(5):
        y = y_top + index * LINE_SPACING
        draw.line((x0, y, x1, y), fill="black", width=2)


def draw_clef_and_meter(draw: ImageDraw.ImageDraw, fonts: dict[str, ImageFont.FreeTypeFont], x: int, y_top: int) -> None:
    draw.text((x, y_top - 54), "𝄞", font=fonts["clef"], fill="black")
    meter_x = x + 110
    draw.text((meter_x, y_top - 6), "4", font=fonts["time"], fill="black")
    draw.text((meter_x, y_top + 40), "4", font=fonts["time"], fill="black")


def draw_note(draw: ImageDraw.ImageDraw, center_x: float, center_y: float, note: NoteSpec) -> None:
    note_width = 34
    note_height = 24
    bbox = (
        center_x - note_width / 2,
        center_y - note_height / 2,
        center_x + note_width / 2,
        center_y + note_height / 2,
    )
    if note.value == "half":
        draw.ellipse(bbox, outline="black", width=3, fill="white")
    else:
        draw.ellipse(bbox, outline="black", width=2, fill="black")

    stem_x = center_x + note_width / 2 - 3
    stem_top = center_y - 96
    draw.line((stem_x, center_y, stem_x, stem_top), fill="black", width=3)

    if pitch_step(note.pitch) == "C":
        ledger_y = center_y
        draw.line((center_x - 28, ledger_y, center_x + 28, ledger_y), fill="black", width=2)


def draw_measure(
    draw: ImageDraw.ImageDraw,
    fonts: dict[str, ImageFont.FreeTypeFont],
    staff_top: int,
    measure_left: int,
    measure_width: int,
    measure_number: int,
    measure: MeasureSpec,
    is_first_measure_in_system: bool
) -> None:
    if is_first_measure_in_system:
        draw_clef_and_meter(draw, fonts, measure_left + 16, staff_top)
        note_start = measure_left + CLEF_BLOCK_WIDTH
    else:
        note_start = measure_left + 18

    draw.text((measure_left + 8, staff_top - 52), str(measure_number), font=fonts["measure"], fill="#666666")

    if measure.direction:
        draw.text((note_start, staff_top - 88), measure.direction, font=fonts["direction"], fill="black")

    usable_width = measure_left + measure_width - 26 - note_start
    positions = len(measure.notes)
    spacing = usable_width / max(positions, 1)
    for index, note in enumerate(measure.notes):
        center_x = note_start + spacing * (index + 0.5)
        center_y = y_for_pitch(staff_top, note.pitch)
        draw_note(draw, center_x, center_y, note)

    measure_right = measure_left + measure_width
    draw.line((measure_right, staff_top - 2, measure_right, staff_top + STAFF_HEIGHT + 2), fill="black", width=3)


def make_page(page_index: int, fonts: dict[str, ImageFont.FreeTypeFont]) -> Image.Image:
    image = Image.new("RGB", (PAGE_WIDTH, PAGE_HEIGHT), "white")
    draw = ImageDraw.Draw(image)

    if page_index == 0:
        title = "Twinkle Twinkle Little Star"
        subtitle = "Public-domain VocalDive sample fixture"
        title_box = draw.textbbox((0, 0), title, font=fonts["title"])
        title_x = (PAGE_WIDTH - (title_box[2] - title_box[0])) / 2
        draw.text((title_x, 180), title, font=fonts["title"], fill="black")
        subtitle_box = draw.textbbox((0, 0), subtitle, font=fonts["subtitle"])
        subtitle_x = (PAGE_WIDTH - (subtitle_box[2] - subtitle_box[0])) / 2
        draw.text((subtitle_x, 285), subtitle, font=fonts["subtitle"], fill="#444444")

    for system_offset, staff_top in enumerate(SYSTEM_TOPS):
        system_index = page_index * 2 + system_offset
        first_measure = system_index * MEASURES_PER_SYSTEM
        draw_staff(draw, MARGIN_X, PAGE_WIDTH - MARGIN_X, staff_top)
        measure_width = SYSTEM_WIDTH // MEASURES_PER_SYSTEM
        for local_measure_index in range(MEASURES_PER_SYSTEM):
            measure_index = first_measure + local_measure_index
            measure_left = MARGIN_X + local_measure_index * measure_width
            draw_measure(
                draw=draw,
                fonts=fonts,
                staff_top=staff_top,
                measure_left=measure_left,
                measure_width=measure_width,
                measure_number=measure_index + 1,
                measure=MEASURES[measure_index],
                is_first_measure_in_system=(local_measure_index == 0)
            )
        draw.line((MARGIN_X, staff_top - 2, MARGIN_X, staff_top + STAFF_HEIGHT + 2), fill="black", width=3)

    footer = f"Page {page_index + 1}"
    footer_box = draw.textbbox((0, 0), footer, font=fonts["page"])
    footer_x = (PAGE_WIDTH - (footer_box[2] - footer_box[0])) / 2
    draw.text((footer_x, PAGE_HEIGHT - 160), footer, font=fonts["page"], fill="#666666")
    return image


def xml_for_measure(number: int, measure: MeasureSpec, include_attributes: bool) -> str:
    parts: list[str] = [f'    <measure number="{number}">']
    if include_attributes:
        parts.extend([
            "      <attributes>",
            "        <divisions>1</divisions>",
            "        <key><fifths>0</fifths></key>",
            "        <time><beats>4</beats><beat-type>4</beat-type></time>",
            "        <clef><sign>G</sign><line>2</line></clef>",
            "      </attributes>",
            '      <sound tempo="96"/>',
        ])
    if measure.direction:
        if measure.direction in {"mf", "f", "ff", "p", "mp"}:
            parts.extend([
                '      <direction placement="above">',
                "        <direction-type>",
                f"          <dynamics><{measure.direction}/></dynamics>",
                "        </direction-type>",
                "      </direction>",
            ])
        else:
            parts.extend([
                '      <direction placement="above">',
                "        <direction-type>",
                f"          <words>{html.escape(measure.direction)}</words>",
                "        </direction-type>",
                "      </direction>",
            ])
    for note in measure.notes:
        parts.extend([
            "      <note>",
            "        <pitch>",
            f"          <step>{pitch_step(note.pitch)}</step>",
            f"          <octave>{pitch_octave(note.pitch)}</octave>",
            "        </pitch>",
            f"        <duration>{note_type_duration(note.value)}</duration>",
            f"        <type>{note.value}</type>",
            "      </note>",
        ])
    parts.append("    </measure>")
    return "\n".join(parts)


def make_musicxml() -> str:
    measure_blocks = [
        xml_for_measure(index + 1, measure, include_attributes=(index == 0))
        for index, measure in enumerate(MEASURES)
    ]
    return "\n".join([
        '<?xml version="1.0" encoding="UTF-8" standalone="no"?>',
        '<!DOCTYPE score-partwise PUBLIC "-//Recordare//DTD MusicXML 4.0 Partwise//EN" "http://www.musicxml.org/dtds/partwise.dtd">',
        '<score-partwise version="4.0">',
        "  <work><work-title>Twinkle Twinkle Little Star Sample</work-title></work>",
        '  <identification><creator type="composer">Traditional</creator><creator type="lyricist">Public domain fixture</creator><rights>Public domain melody rendered as VocalDive sample fixture.</rights></identification>',
        "  <part-list>",
        '    <score-part id="P1"><part-name>Voice</part-name></score-part>',
        "  </part-list>",
        '  <part id="P1">',
        *measure_blocks,
        "  </part>",
        "</score-partwise>",
        "",
    ])


def make_readme() -> str:
    return "\n".join([
        "# Twinkle Sample Pack",
        "",
        "This is a public-domain VocalDive demo fixture for OMR intake and phone-photo simulation.",
        "",
        "Files:",
        "- `twinkle_intact/twinkle-multipage.pdf`: primary print-and-photograph source",
        "- `twinkle_intact/twinkle-page-1.png` / `twinkle_intact/twinkle-page-2.png` / `twinkle_intact/twinkle-page-3.png`: page images exported from the same master layout",
        "- `../../musicxml/twinkle-multipage-ground-truth.musicxml`: ground-truth MusicXML for the same notation content",
        "- `twinkle_scanned/`: place for phone-photo or scanned variants used as robustness fixtures",
        "",
        "Suggested photo capture variations:",
        "- straight-on shot",
        "- slight perspective angle",
        "- mild shadow",
        "- weaker room light",
        "- gentle page curvature",
        "",
        "The page images and PDF are intentionally clean and do not include debug overlays or research labels.",
        "",
    ])


def main() -> None:
    SCORE_OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    INTACT_OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    MUSICXML_OUTPUT.parent.mkdir(parents=True, exist_ok=True)

    fonts = make_fonts()
    pages = [make_page(index, fonts) for index in range(TOTAL_PAGES)]

    for output_path, page in zip(PNG_OUTPUTS, pages, strict=True):
        page.save(output_path, format="PNG")

    pages[0].save(PDF_OUTPUT, save_all=True, append_images=pages[1:], resolution=300.0)
    MUSICXML_OUTPUT.write_text(make_musicxml(), encoding="utf-8")
    README_OUTPUT.write_text(make_readme(), encoding="utf-8")


if __name__ == "__main__":
    main()
