# Score Annotation Research

Date: 2026-06-06

## Goal

VocalDive score annotation should behave more like GoodNotes / Notability than a low-resolution pixel overlay. When a score is zoomed or exported/printed as PDF, handwritten markings should remain clear.

## Key Decision

Use vector ink data, not bitmap drawing.

The app should store annotation strokes as paths:

- normalized points on the score page
- color
- opacity
- line width
- layer / page / measure reference

During display, redraw those paths at the current zoom. During PDF export, convert the paths to PDF ink annotations or vector page graphics.

## Why Not PNG / Bitmap Annotation

A PNG-like overlay is easy to implement, but it has a fixed pixel resolution. If the user zooms in or prints at higher resolution, the stroke edges can become blurry or blocky. This is especially bad for sheet music because singers may zoom into a dense measure, handwritten solfege, breath marks, or intonation notes.

## Recommended Architecture

### In-App Display

- Use a vector stroke model for the score page.
- Render strokes with SwiftUI `Canvas`, PencilKit, or another vector drawing layer.
- Store stroke points in normalized page coordinates, so the same annotation can follow the page as it is zoomed, resized, cropped, or shown on iPad/macOS.
- Keep score content and annotations as separate layers.

### Apple Pencil Capture

MVP:

- SwiftUI `DragGesture` captures points.
- Works with touch/mouse and can be tested immediately.

Better iPad implementation:

- Use PencilKit `PKCanvasView` to get better Apple Pencil pressure, tilt, hover, tool picker, and natural inking.
- Store `PKDrawing.dataRepresentation()` for lossless app-side persistence.
- For PDF export, convert strokes into PDF ink paths or flatten them as high-quality vector drawing.

### PDF Export

Preferred route:

1. Generate or load the score PDF.
2. Map normalized VocalDive annotation points to PDF page coordinates.
3. Create PDFKit ink annotations with `PDFAnnotationSubtype.ink`.
4. Add Bezier paths to the annotation.
5. Save the annotated `PDFDocument`.

Important coordinate detail:

- SwiftUI screen coordinates usually place the origin at top-left.
- PDF page coordinates usually place the origin at bottom-left.
- Export must flip the y-axis: `pdfY = pageHeight - normalizedY * pageHeight`.

### Layer Strategy

Suggested annotation layers:

- Practice notes: solfege, breath, text, conductor marks.
- OMR correction: wrong note, wrong rhythm, uncertain measure.
- Pitch feedback: app-generated red marks for repeated intonation errors.
- Teacher comments: future external-review layer.

## Feasibility

Feasible now.

The current implementation adds a vector annotation prototype in `ScoreWorkspaceView.swift`:

- annotation mode toggle
- pen
- highlighter
- eraser
- line width slider
- undo
- clear
- normalized vector stroke storage
- Canvas rendering that remains clear when zooming

Limitations:

- It is not persisted yet.
- It does not yet export to PDF.
- It does not yet use PencilKit pressure/tilt.
- It annotates the current rendered score page, not a real imported PDF page.

## Next Engineering Steps

1. Move `ScoreAnnotationStroke` into a durable model.
2. Save annotations in `ScoreDocument` or a parallel `ScoreAnnotationDocument`.
3. Add page IDs / measure IDs to every stroke.
4. Add PencilKit on iPad for natural Apple Pencil inking.
5. Add PDFKit export:
   - MusicXML score -> PDF page
   - annotation strokes -> PDF ink annotations
   - output annotated PDF
6. Add per-layer controls, like forScore-style layers.

## Product Notes from Similar Apps

forScore supports layers so users can separate annotations and manage them without destroying the score. It also supports Apple Pencil workflows such as automatic annotation mode, preventing finger drawing, and hover previews on newer iPads.

forScore's guide also warns that copying PDF page content as an image can become pixelated when zooming vector PDF files. This supports VocalDive's decision to avoid a bitmap-first annotation system for archival markings.

## Sources

- Apple PDFKit `PDFAnnotation`: https://developer.apple.com/documentation/pdfkit/pdfannotation
- Apple PDFKit ink subtype: https://developer.apple.com/documentation/pdfkit/pdfannotationsubtype/ink
- Apple PDFKit add Bezier path to ink annotation: https://developer.apple.com/documentation/pdfkit/pdfannotation/add%28_%3A%29
- Apple PDFKit custom PDF graphics: https://developer.apple.com/documentation/pdfkit/adding-custom-graphics-to-a-pdf
- Apple PencilKit: https://developer.apple.com/documentation/pencilkit
- Apple PencilKit drawing data representation: https://developer.apple.com/documentation/pencilkit/pkdrawingreference/datarepresentation%28%29
- forScore annotation guide: https://forscore.co/documentation/annotation/
- forScore 15 guide: https://forscore.co/forScore15-0.pdf
