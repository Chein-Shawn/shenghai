# SATB OMR Dataset Research

## Decision

No single public dataset found in this review provides a large, dedicated
collection of real SATB scanned pages paired with page-aligned MusicXML. The
first VocalDive target fixture is therefore the private `I stood on the river
of Jordan` score, while broader OMR datasets provide auxiliary training or
evaluation evidence.

## Candidate Roles

| Candidate | What it provides | VocalDive role | Decision |
| --- | --- | --- | --- |
| `I stood on the river of Jordan` | Real annotated SATB scan, clean PDF, MXL | Target-domain prototype and holdout | Use immediately |
| OpenScore String Quartets HF | IMSLP scans, clean renders, MusicXML | Multi-staff scan evaluation | Use; not SATB |
| OLiMPiC | Real score images paired with LMX/MusicXML | External OMR evaluation | Use; pianoform, not SATB |
| `zzsi/openscore` Lieder | Large voice-plus-piano rendered pages and MusicXML | Voice/staff layout pretraining | Use selectively; mostly rendered |
| OpenScore Lieder | Voice plus accompaniment symbolic source | Vocal layout and lyrics research | Use selectively |
| SEILS | Multi-voice historical score research | Structural research | Evaluate alignment before use |
| EwanB `satb-choral-dataset` | SATB audio/source-separation tensors | Voice/audio research only | Not an OMR image dataset |
| MusiCorpus | Historical/handwritten images with MusicXML and annotations | Robustness research | Not a first SATB target |

## Why The Jordan Score Is Valuable

It contains three scanned pages and three clean pages with the same 49-measure
SATB a cappella work. The scan includes handwritten annotations, lyrics,
multiple systems, dynamics, tempo markings, and multi-voice notation. This is
closer to VocalDive's actual user input than a clean renderer output.

The MXL has five MusicXML part IDs. The visual score presents two main staff
systems with SATB voices distributed through parts/voices, so the manifest must
preserve both the MusicXML part/voice structure and the visible two-staff
system structure. It must not assume that one MusicXML part equals one printed
staff.

## Data Policy For The Prototype

1. `scanned.pdf` is the model input and robustness test.
2. `clean.pdf` is a visual reference and preprocessing comparison.
3. `mxl` is the semantic ground truth.
4. Page breaks and system bounds are explicit metadata and may be manually
   corrected.
5. The first 12 system crops are a prototype/validation set, not a general
   training corpus.
6. New SATB scores should be added only when their scan/photo and MusicXML can
   be reliably paired and their part/voice structure is reviewed.

## Search Notes

- The Hugging Face OpenScore String Quartets dataset explicitly separates real
  IMSLP scans from clean MuseScore renders and includes MusicXML, making it a
  strong OMR evaluation source but not a choir corpus.
- `zzsi/openscore` offers large page-level paired resources, but the Lieder
  portion is voice-plus-piano rather than SATB. Its quartet page labels also
  have documented empty-label failures, so quartet pages should not be used
  blindly for supervised training.
- The Hugging Face `satb-choral-dataset` result is audio/source-separation
  data, not score images paired with MusicXML, so it does not solve the OMR
  training requirement.
- Public choral libraries may provide score files, but availability and page
  alignment are inconsistent. They should be treated as candidate source
  discovery, not as a ready-made training dataset.

## Next Dataset Requirement

The next useful addition is not another arbitrary score. It is 5-10 more real
SATB works with different publishers/layouts, each containing:

```text
scanned or photographed PDF/image
clean reference if available
MusicXML or equivalent semantic source
part/voice mapping
page/system/measure mapping
```

Until those pairs exist, model accuracy should be reported only on the Jordan
fixture and the auxiliary OMR datasets, not as general SATB accuracy.
