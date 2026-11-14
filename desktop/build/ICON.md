# App icon

The CCA icon is three stacked account cards on a teal tile. The master is
`icon-master.svg`; `icon.png` and `icon.ico` are generated from it and must not
be edited by hand.

## Provenance and licence

Original artwork drawn for CCA on 2026-11-14, MIT like the rest of the repo. It
replaces an earlier icon built from Apple's SF Symbol `person.2.fill`, which
Apple's guidelines do not allow in app icons.

## Regenerate

    node desktop/scripts/make-icons.js

Options: `--out <dir>` writes elsewhere, `--preview <dir>` also writes each size.
The script uses Node only and gives identical bytes on every run with Node 20 or later (checked on 20, 22, 24 and 26). Very old Node versions compress the files differently but draw the same pixels.

## SVG subset

The script parses only what the master documents: root `<svg viewBox>`,
comments, `<rect>`, `<circle>` (fill `#RRGGBB`, `fill-opacity`) and
`<g data-min-px="N">` (drawn only when the output is at least N px wide).
Anything else makes it stop with an error.

## Where each file is used

electron-builder makes the macOS `.icns` from `icon.png`. The Windows exe,
installer and tray use `icon.ico` and `icon.png`.
