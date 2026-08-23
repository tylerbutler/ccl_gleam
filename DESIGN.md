---
name: CCL Gleam
description: Source-preserving documentation presented as a continuous-form printer proof.
colors:
  correction-pink: "#ff62c7"
  correction-pink-dark: "#a91d78"
  carbon-ink: "#171717"
  fanfold-paper: "#f4f1e8"
  fanfold-paper-deep: "#e8e3d7"
  proof-white: "#fffef9"
  registration-gray: "#b8b3a7"
  muted-ink: "#68655d"
typography:
  display:
    fontFamily: "Barlow Condensed, sans-serif"
    fontSize: "clamp(4.3rem, 7.6vw, 7.5rem)"
    fontWeight: 700
    lineHeight: 0.81
    letterSpacing: "-0.025em"
  headline:
    fontFamily: "Barlow Condensed, sans-serif"
    fontSize: "clamp(3.6rem, 7vw, 7rem)"
    fontWeight: 700
    lineHeight: 0.87
    letterSpacing: "-0.025em"
  title:
    fontFamily: "Barlow Condensed, sans-serif"
    fontSize: "2.25rem"
    fontWeight: 700
    lineHeight: 1
    letterSpacing: "-0.025em"
  body:
    fontFamily: "Atkinson Hyperlegible Next Variable, sans-serif"
    fontSize: "1.05rem"
    fontWeight: 400
    lineHeight: 1.68
  label:
    fontFamily: "Fira Code Variable, monospace"
    fontSize: "0.72rem"
    fontWeight: 700
    lineHeight: 1.35
    letterSpacing: "0.06em"
rounded:
  square: "0"
  perforation: "50%"
spacing:
  tight: "0.75rem"
  compact: "1.25rem"
  content: "2rem"
  section-block: "clamp(4rem, 8vw, 8rem)"
  section-inline: "clamp(2rem, 6vw, 6rem)"
components:
  action-primary:
    backgroundColor: "{colors.correction-pink}"
    textColor: "{colors.carbon-ink}"
    rounded: "{rounded.square}"
    padding: "0.7rem 1.1rem"
    height: "3.25rem"
  action-secondary:
    backgroundColor: "transparent"
    textColor: "{colors.carbon-ink}"
    rounded: "{rounded.square}"
    padding: "0.7rem 1.1rem"
    height: "3.25rem"
  action-hover:
    backgroundColor: "{colors.carbon-ink}"
    textColor: "{colors.proof-white}"
    rounded: "{rounded.square}"
  sequence-tab:
    backgroundColor: "{colors.fanfold-paper}"
    textColor: "{colors.carbon-ink}"
    typography: "{typography.label}"
    rounded: "{rounded.square}"
    padding: "0.8rem"
    height: "5.25rem"
  sequence-tab-selected:
    backgroundColor: "{colors.correction-pink}"
    textColor: "{colors.carbon-ink}"
    typography: "{typography.label}"
    rounded: "{rounded.square}"
---

# Design System: CCL Gleam

## Overview

**Creative North Star: "Fanfold Proof"**

CCL Gleam turns source preservation into a physical proofing system. Warm continuous-form paper, carbon-black rules, tractor perforations, registration marks, and correction pink make edits look inspected rather than merely highlighted. The system is technical and direct, but its print-shop materiality keeps the documentation distinct from generic developer cards.

Large compressed headings carry the argument; hyperlegible body copy explains it; monospaced registration text annotates evidence. Dense ruled structures organize tasks and reference material, while generous section fields keep the reading path clear.

**Key Characteristics:**
- Warm paper layers bounded by crisp one-pixel carbon rules.
- Correction pink is both the action color and the visual proof of change.
- Condensed display type, highly legible prose, and monospaced technical labels have separate jobs.
- Proof sheets, perforations, stamps, line numbers, and registration copy express source fidelity.
- Square controls and containers preserve the mechanical print-shop character.

## Colors

The palette is a warm neutral proofing stock interrupted by one high-chroma correction color.

### Primary
- **Correction Pink:** The sole emphatic field for primary actions, selected navigation, edited values, links, and selection.
- **Dark Correction Pink:** Carries pink meaning when text, outlines, focus, or small marks need stronger contrast.

### Neutral
- **Carbon Ink:** Primary text, dark code fields, structural borders, and inverse footer surfaces.
- **Fanfold Paper:** The default page and control stock.
- **Deep Fanfold Paper:** Sidebars and secondary section fields.
- **Proof White:** Reading panes and the proof sheet face.
- **Registration Gray:** Hairlines, line numbers, and low-emphasis dividers.
- **Muted Ink:** Supporting copy and proof annotations.

### Named Rules

**The One Correction Rule.** Correction pink is the only chromatic accent; use it to mark action, selection, or a changed source fact.

**The Paper Stack Rule.** Separate regions with fanfold paper, deep paper, proof white, and carbon rules before adding depth effects.

## Typography

**Display Font:** Barlow Condensed (with sans-serif fallback)  
**Body Font:** Atkinson Hyperlegible Next Variable (with sans-serif fallback)  
**Label/Mono Font:** Fira Code Variable (with monospace fallback)

**Character:** Compressed headings resemble printer headlines without compromising scan speed. The open body face supports long technical reading, while mono type is reserved for code, identifiers, registration data, and compact navigation labels. Code surfaces enable Fira Code's contextual programming ligatures.

### Hierarchy
- **Display:** Extra-large, tightly led condensed type for the homepage claim.
- **Headline:** Large compressed section statements; short lines and balanced wrapping are preferred.
- **Title:** Compact documentation and panel headings.
- **Body:** Comfortable technical prose, normally constrained to about 70 characters per line.
- **Label:** Small monospaced registration text with modest tracking; uppercase is used for proof metadata and sidebar groups.

### Named Rules

**The Three Registers Rule.** Barlow Condensed argues, Atkinson explains, and Fira Code records; do not interchange their roles for novelty.

**The Short Headline Rule.** Display headings stay compressed and narrow enough to form visible blocks rather than long sentences.

## Layout

The system uses ruled registers rather than floating cards. The homepage begins with a three-part header, then pairs a narrow claim register with a wider proof stage. Reading sections use asymmetric two-column grids; guide links become a ruled list. Documentation pages use a deep-paper navigation rail, a proof-white reading pane capped at 48rem, and an optional contents rail.

Section spacing is fluid and generous, while component spacing is compact. At 64rem, split homepage regions stack and internal vertical rules become horizontal rules. At 43rem, navigation reduces to the primary path, the hero becomes a single reading column, proof details collapse, four tabs become a two-by-two grid, and guide rows reduce to three columns. At 50rem, the documentation reading pane drops its registration line.

**The Register Rule.** Every major region belongs to a clear column, row, or ruled sheet; avoid free-floating content islands.

**The Mobile Proof Rule.** Preserve the proof itself on small screens, but remove explanatory furniture before shrinking the evidence below legibility.

## Elevation & Depth

The system is flat by default. Paper tone and one-pixel rules establish most hierarchy. Soft ambient shadows are reserved for the physical proof sheet and dark code panels, where they clarify that an artifact sits above its stock rather than making every container float.

### Shadow Vocabulary
- **Proof lift** (`0 24px 55px rgb(23 23 23 / 20%)`): Used only beneath the large source proof.
- **Code lift** (`0 16px 34px rgb(23 23 23 / 14%)`): Used beneath interactive journey code panels.
- **Documentation code lift** (`0 12px 30px rgb(23 23 23 / 10%)`): Used beneath Starlight code blocks.

### Named Rules

**The Physical Artifact Rule.** Add a shadow only when a sheet or code specimen is meant to read as an object placed on paper.

## Shapes

Controls, code blocks, asides, pagination links, and content containers have square corners. Circles belong only to tractor holes, status dots, and other registration mechanics. One-pixel carbon or registration-gray rules define edges; the rotated two-pixel safety stamp is the only intentionally imperfect outline.

**The Press-Cut Rule.** Interactive and reading surfaces are rectangular and square-cornered; circles signal print mechanics, not generic decoration.

## Components

### Buttons
- **Shape:** Square, one-pixel carbon outline, compact horizontal padding, and a minimum touch height.
- **Primary:** Correction-pink stock with carbon text.
- **Secondary:** Transparent paper stock with the same carbon outline.
- **Hover / Focus:** Both variants invert to carbon with proof-white text. Keyboard focus uses a three-pixel dark-pink outline offset by four pixels.

### Cards / Containers
- **Corner Style:** Square.
- **Background:** Proof white for reading artifacts; fanfold paper for controls; deep paper for secondary regions.
- **Shadow Strategy:** Flat unless the container is a physical proof or code specimen.
- **Border:** One-pixel carbon for strong edges; registration gray for internal rules.
- **Internal Padding:** Compact inside controls and fluid inside page regions.

### Navigation
- **Style:** Homepage navigation is a ruled horizontal register with semibold body labels. Documentation navigation uses monospaced uppercase group labels over plain body links.
- **State:** Underline hover marks use dark correction pink; current documentation links fill with correction pink.
- **Mobile:** Keep the primary Start path and API link; hide lower-priority homepage links rather than wrapping the header.

### Sequence Tabs

Four numbered monospaced tabs form one ruled strip. The selected tab uses correction pink; unselected tabs sit on fanfold paper and deepen on hover. Tab panels reveal with a 420ms top-to-bottom proof-settle animation; reduced-motion preference removes the transition.

### Source Proof

The signature container combines a proof-white sheet, tractor-feed rail, registration header, ruled source excerpt, changed-value annotation, before/after record, and rotated read-back stamp. The changed line remains in context: correction pink marks the value, never replaces the surrounding source evidence.

### Guide Rows

Guide links are full-width ruled rows containing a mono guide code, condensed title, muted explanation, and line arrow. Hover fills the entire row with correction pink and restores supporting copy to carbon ink.

## Do's and Don'ts

### Do:
- **Do** use correction pink to connect actions, active states, and source changes.
- **Do** keep examples in visible context with line numbers, comments, or surrounding entries when preservation is the claim.
- **Do** use paper tones and rules as the first level of hierarchy.
- **Do** preserve the three type registers and the 70-character reading measure.
- **Do** honor keyboard focus and reduced-motion behavior on every interactive pattern.

### Don't:
- **Don't** introduce another accent hue or distribute pink as unstructured decoration.
- **Don't** round cards, controls, code blocks, or navigation items.
- **Don't** apply shadows to ordinary sections, navigation, or list rows.
- **Don't** replace ruled layouts with generic detached card grids.
- **Don't** hide changed source from its unchanged context.
