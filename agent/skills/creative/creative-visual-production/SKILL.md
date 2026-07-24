---
name: creative-visual-production
description: "Class-level creative visual artifact production: diagrams, HTML mockups, illustrations, comics, infographics, sketches, generative art, pixel art, and ASCII/video variants."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [Creative, Design, Visuals, HTML, Diagrams, Illustration, Infographics, Generative-Art]
---

# Creative Visual Production

Use this umbrella when the user asks for a visual artifact, browser demo, diagram, mockup, illustration, comic, infographic, generative sketch, pixel art, ASCII art/video, or one-off HTML design. Pick the subsection that matches the deliverable, then use any specialized surviving skill/package only when its large support library is required.

## Design and HTML artifacts

For landing pages, decks, prototypes, or throwaway mockups, produce single-file HTML/CSS unless the user asks otherwise. Offer 2-3 variants for exploratory mockups. Draw from real-world systems (Stripe, Linear, Vercel, etc.) when the user asks for polished web design.

## Architecture and diagramming

For infrastructure or architecture diagrams, use dark-themed SVG/HTML diagrams or Excalidraw-style JSON when a hand-drawn look is requested. Keep labels concise and visually grouped.

## Article illustrations, comics, and infographics

For explanatory visuals, decide whether the output should be: article hero/support illustration, knowledge comic/storyboard, or infographic/data-visual. Preserve consistency across type, style, palette, characters, and layout. The Baoyu packages contain large style/layout/reference libraries; keep or restore them when detailed presets are needed rather than flattening their support files.

## Generative and interactive art

Use p5.js or Pretext for browser-based generative art, shaders, kinetic typography, DOM-free text layout, or text-as-geometry demos. Produce single-file HTML by default and include controls when exploration matters.

## ASCII, pixel, and video treatments

Use ASCII art for text/image-to-ASCII treatments, ASCII video for colored ASCII MP4/GIF conversions, and pixel art for era-specific palettes such as NES, Game Boy, or PICO-8. For video or animation, prefer Manim for mathematical/algo explanations and TouchDesigner/ComfyUI for real-time or node-based media workflows.

## Absorbed package map

The following former narrow packages are archived intact under `.archive/` after this umbrella absorbed their trigger logic. Their support files were not flattened; restore/re-home the whole package if a task needs its full reference library.

### ASCII/video and animation

- `ascii-video`: colored ASCII MP4/GIF, audio-reactive ASCII visualizers, typography overlays, ffmpeg/Pillow/NumPy production pipeline, brightness/font/pipe-deadlock pitfalls.
- `manim-video`: Manim CE mathematical and algorithm explainer videos with plan/code/render/stitch/audio/review workflow, 3Blue1Brown-style pacing, LaTeX and scene QA pitfalls.

### Baoyu image-generation packages

- `baoyu-article-illustrator`: article illustration placement, Type × Style × Palette consistency, prompt-file-first reproducibility, reference-image trait extraction, and article-data label integrity.
- `baoyu-comic`: educational/knowledge comics with storyboard, character sheets, prompt records, art/tone/layout presets, partial workflows, and absolute-path download pitfalls.
- `baoyu-infographic`: infographic generation using layout × style combinations, faithful data preservation, structured-content intermediate files, and prompt assembly from layout/style references.

### Design, diagrams, and token specs

- `claude-design`: CLI/API-mode design process for high-fidelity local HTML artifacts, prototypes, decks, component labs, context-first design, and browser verification.
- `design-md`: Google DESIGN.md token-spec authoring, lint/diff/export through `@google/design.md`, WCAG contrast checks, token reference pitfalls, and Tailwind/DTCG exports.
- `excalidraw`: hand-drawn `.excalidraw` JSON diagrams, valid element/container bindings, arrow labels, color palettes, and optional share-link upload script.

### Browser creative coding and text demos

- `p5js`: single-file p5.js generative/interactive sketches, shaders, audio-reactive visuals, WebGL, export pipelines, and first-render creative standards.
- `pretext`: @chenglou/pretext DOM-free text layout demos, kinetic typography, text-as-geometry games, proportional-font measurement, and canvas performance pitfalls.

### Node/model-based visual systems

- `comfyui`: ComfyUI lifecycle, workflow execution, REST/WebSocket scripts, dependency checks, batch runs, local/cloud quirks, and workflow-template integrity.
- `touchdesigner-mcp`: TouchDesigner/twozero MCP setup, native TD tool workflow, operator parameter discovery, GLSL/audio-reactive network patterns, and real-time visual capture.

## Quality checklist

- Clarify target medium, aspect ratio, audience, and style references.
- Keep outputs directly usable: HTML file, SVG, JSON, prompt, or generated asset path.
- For visual variants, label differences clearly and avoid over-producing.
- When a task needs a full archived package's support library, restore/re-home all linked files instead of copying only its SKILL.md.
