---
name: Spatial Form UI
colors:
  surface: '#111418'
  surface-dim: '#111418'
  surface-bright: '#36393e'
  surface-container-lowest: '#0b0e12'
  surface-container-low: '#191c20'
  surface-container: '#1d2024'
  surface-container-high: '#272a2f'
  surface-container-highest: '#32353a'
  on-surface: '#e1e2e8'
  on-surface-variant: '#c0c6d6'
  inverse-surface: '#e1e2e8'
  inverse-on-surface: '#2e3135'
  outline: '#8b91a0'
  outline-variant: '#414754'
  surface-tint: '#aac7ff'
  primary: '#aac7ff'
  on-primary: '#003064'
  primary-container: '#3e90ff'
  on-primary-container: '#002957'
  inverse-primary: '#005db8'
  secondary: '#7bd0ff'
  on-secondary: '#00354a'
  secondary-container: '#00a6e0'
  on-secondary-container: '#00374d'
  tertiary: '#c0c1ff'
  on-tertiary: '#1000a9'
  tertiary-container: '#8083ff'
  on-tertiary-container: '#0d0096'
  error: '#ffb4ab'
  on-error: '#690005'
  error-container: '#93000a'
  on-error-container: '#ffdad6'
  primary-fixed: '#d6e3ff'
  primary-fixed-dim: '#aac7ff'
  on-primary-fixed: '#001b3e'
  on-primary-fixed-variant: '#00468d'
  secondary-fixed: '#c4e7ff'
  secondary-fixed-dim: '#7bd0ff'
  on-secondary-fixed: '#001e2c'
  on-secondary-fixed-variant: '#004c69'
  tertiary-fixed: '#e1e0ff'
  tertiary-fixed-dim: '#c0c1ff'
  on-tertiary-fixed: '#07006c'
  on-tertiary-fixed-variant: '#2f2ebe'
  background: '#111418'
  on-background: '#e1e2e8'
  surface-variant: '#32353a'
typography:
  display-spatial:
    fontFamily: Inter
    fontSize: 40px
    fontWeight: '600'
    lineHeight: 48px
    letterSpacing: -0.02em
  headline-lg:
    fontFamily: Inter
    fontSize: 28px
    fontWeight: '600'
    lineHeight: 36px
    letterSpacing: -0.015em
  headline-md:
    fontFamily: Inter
    fontSize: 22px
    fontWeight: '600'
    lineHeight: 28px
    letterSpacing: -0.01em
  headline-sm:
    fontFamily: Inter
    fontSize: 18px
    fontWeight: '500'
    lineHeight: 24px
  body-lg:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  body-md:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  body-sm:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '400'
    lineHeight: 16px
  label-spatial:
    fontFamily: Inter
    fontSize: 11px
    fontWeight: '600'
    lineHeight: 14px
    letterSpacing: 0.06em
  telemetry-lg:
    fontFamily: JetBrains Mono
    fontSize: 14px
    fontWeight: '500'
    lineHeight: 18px
    letterSpacing: -0.01em
  telemetry-sm:
    fontFamily: JetBrains Mono
    fontSize: 11px
    fontWeight: '400'
    lineHeight: 14px
rounded:
  sm: 0.5rem
  DEFAULT: 1rem
  md: 1.5rem
  lg: 2rem
  xl: 3rem
  full: 9999px
spacing:
  gutter: 1rem
  gutter-spatial: 1.5rem
  margin: 2rem
  margin-spatial: 3rem
  space-xs: 0.25rem
  space-sm: 0.5rem
  space-md: 1rem
  space-lg: 1.5rem
  space-xl: 2.5rem
---

## Brand & Style

This design system establishes an ultra-dark spatial computing environment tailored for professional 3D authoring, mesh manipulation, and volumetric modeling. The design system bridges tactile industrial precision with visionOS volumetric principles, rooting the visual narrative in the infinite spatial void.

The visual style fuses advanced Glassmorphism with deep spatial minimalism. Windows and control palettes do not behave as flat panels; they exist as suspended physical optical glass slabs that dynamically refract physical-world passthrough and synthetic dark matter. High-transmission frosted glass, specular ray edges, and subtle inner illuminations convey physical mass and optical depth without obscuring the user's primary modeling target. 

The emotional signature is precise, ethereal, and hyper-focused. Interactive elements remain weightless yet grounded, responding to ocular focus and pinch gestures with luminous radial blooms and fluid z-axis expansions.

## Colors

The palette is engineered around pure visual ergonomics in optical head-mounted environments, prioritizing low luminance fatigue alongside high specular edge contrast.

- **Spatial Void (Canvas & Background):** Deep cosmic blacks `#080B0F` grading to `#0D1117`. The void maintains true blacks to maximize OLED contrast ratios and eliminate pixel boundary distraction in spatial field-of-view.
- **Glass Matrix Materials:** 
  - Ultra-thin glass: `rgba(255, 255, 255, 0.05)`
  - Standard interactive glass: `rgba(255, 255, 255, 0.08)`
  - Concentrated hover/prominent glass: `rgba(255, 255, 255, 0.14)`
  - Surface specular highlights: `rgba(255, 255, 255, 0.20)` to `rgba(255, 255, 255, 0.35)` on top-facing boundaries.
- **Electric Sky Accent:** Primary actions, transform gizmos, and selected spatial anchors employ `#0A84FF` with secondary cyan `#38BDF8` handling vector axes and active spatial state nodes.
- **Telemetry & Orthogonal Accents:** Tertiary `#6366F1` denotes secondary 3D coordinate planes (Z-depth) and reference modifiers.
- **Typography & Content Hierarchy:**
  - High-tier emphasis: `#FFFFFF` (100% white specular purity)
  - Secondary readout & metadata: `#D4D4D8` (Zinc-300)
  - Inactive telemetry, structural labels: `#71717A` (Zinc-500)
  - Dividers & subtle structural lines: `rgba(255, 255, 255, 0.12)`

## Typography

Typography prioritizes sub-millimeter legibility under real-time stereoscopic rendering. `Inter` provides neutral, structurally balanced letterforms that eliminate fringing across variable focal lengths.

For 3D space vectors, transform coordinate readouts (X, Y, Z coordinates, rotation matrices, vertex indices), `JetBrains Mono` is enforced with strict tabular sizing. This prevents layout jitter during continuous pinch-drag transformations and real-time mesh telemetry updates.

All spatial headlines employ negative optical tracking to preserve compactness on wide spatial glass windows, while micro telemetry tags leverage positive tracking for fast ocular peripheral scanning.

## Layout & Spacing

Spatial layout is governed by visual field anchoring rather than strict 2D responsive grids. The core UI conforms to a floating multi-panel canvas:

- **Central Viewport Canvas:** Unconstrained fluid viewport with clear margin zones (`margin-spatial: 3rem`) preserving the central user foveal zone for 3D model interaction.
- **Peripheral Glass Docks:** 
  - Primary tool palette suspends vertically or horizontally along an anchored lower orbit.
  - Contextual parameter shelves float at a default 16px (`space-md`) gap from parent windows.
- **Ornaments:** Floating external controls pin themselves to standard offsets of 12px to 24px outside the structural glass bounds, floating slightly forward on the Z-axis.
- **Hit Target Buffering:** While visual elements maintain sleek spatial footprints, all ocular-interactive zones map to minimum physical collision boundaries of 44x44pt to accommodate eye tracking tolerance and micro-pinch gestures.

## Elevation & Depth

Spatial elevation relies on genuine physical optical separation, backdrop diffusion, and light refraction rather than static drop shadows:

- **Base Window Layer (Z-0):** Background blur `backdrop-filter: blur(40px) saturate(160%)`. Ambient surface `rgba(255, 255, 255, 0.06)`, framed by a continuous `1px` translucent specular outline `rgba(255, 255, 255, 0.15)` with a directional top rim light of `rgba(255, 255, 255, 0.28)`.
- **Raised Controls & Hover Plates (Z-1 / +8mm spatial offset):** Background blur `blur(24px)`. Surface fills step up to `rgba(255, 255, 255, 0.12)`. Casts a diffused volumetric ambient occlusion shadow: `0 16px 32px -8px rgba(0, 0, 0, 0.6)`.
- **Modal Panels & Inspector Glass (Z-2 / +24mm spatial offset):** Dynamic surface brightness boost (`rgba(255, 255, 255, 0.16)`). Deep spatial shadow: `0 24px 60px -12px rgba(0, 0, 0, 0.85)`. Border brightens to `rgba(255, 255, 255, 0.3)`.
- **Gaze Dynamic Highlight (The Hover State):** When the user fixes their gaze on an interactable item, a dynamic radial specular glow (`radial-gradient(circle at cursor, rgba(255,255,255,0.2) 0%, transparent 70%)`) subtly tracks across the interior surface of the glass.

## Shapes

The design system embraces curvature tokens derived from visionOS hardware profiles:

- **Main Panels & Shelves:** High-radius continuous curvature (`rounded-xl` / 32px to 40px radius), avoiding sharp geometry that triggers optic convergence artifacts.
- **Toolbars & Ornaments:** Unibody continuous pills (`roundedness: 3` / 9999px border-radius) for quick motor selection and comfortable visual anchoring.
- **Control Inputs & Telemetry Cells:** Uniform pill and high-curvature squircle forms (10px to 14px radius) embedded directly into the glass substrate.
- **Specular Border Geometry:** Internal specular highlights follow exact corner contours with dual-stroke simulation (outer 1px dark rim, inner 1px translucent reflective light).

## Components

### Floating Spatial Pill Bars
Horizontal or vertical continuous glass rails (`rgba(255, 255, 255, 0.08)`, `backdrop-blur-2xl`). Houses tool modules, view mode switchers, and viewport cameras. Tools sit inside circular or rounded touch capsules that gently illuminate upon gaze fixation.

### Circular Icon Buttons with Luminous Rings
Circular 44px gaze anchors.
- **Resting:** Subdued translucent glass, icon at `#D4D4D8`.
- **Ocular Hover:** Inner surface shifts to `rgba(255, 255, 255, 0.18)`, icon transitions to `#FFFFFF`, surrounded by an exterior optical luminous ring in `#0A84FF` with an 8px diffuse glow.
- **Pinch Active:** Button scales down by 4% on the spatial Z-axis with high-intensity cyan `#38BDF8` ring fill.

### visionOS Ornaments
Subordinate control capsules tethered to the bottom or sides of parent windows. Ornaments float 16px offset along the Z-axis, housing rapid playback, viewport shading modes, and undo/redo operations without occluding the primary canvas area.

### 3D Viewport Spatial Telemetry Cards
Ultra-minimal, semi-transparent data tiles displaying real-time polygon counts, active transform coordinates (X, Y, Z), and camera focal depth. Rendered in `JetBrains Mono` with individual axis markers color-coded:
- X-Axis: `#EF4444` (Coral Red)
- Y-Axis: `#22C55E` (Emerald Green)
- Z-Axis: `#38BDF8` (Sky Blue)
Values update dynamically without re-flowing layout metrics.

### Curving Inspector Windows
Auxiliary parameter panels featuring a subtle visual concavity towards the user's focal point. Segmented controls, transform scrubbers, and sliders are recessed with negative visual depth (`rgba(0, 0, 0, 0.35)` background pockets).

### Input Fields & Steppers
Numeric transform scrubbers allow continuous pinch-drag adjustments. Surface is a dark recessed pill with crisp white mono values. Active editing casts an inner border glow in `#0A84FF`.

### Toggles & Segmented Selectors
Sliding glass capsules where the selected indicator is a self-illuminating white-frosted puck that smoothly slides across options, carrying a discrete drop reflection.