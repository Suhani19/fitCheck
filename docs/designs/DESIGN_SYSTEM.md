# Precision Studio — FitCheck Design System

## Overview & Brand Philosophy
**FitCheck** is an engineered AI interview simulation and screening platform designed for high-stakes technical and behavioral interviews.
The design language, **Precision Studio**, blends the cognitive clarity of high-end developer workstations with the real-time telemetry aesthetic of professional audio mixing consoles.

- **Theme Mode**: Dark Studio Mode (`#101419` base)
- **Primary Typography**: [Inter](https://fonts.google.com/specimen/Inter)
- **Telemetry / Monospace Typography**: [JetBrains Mono](https://fonts.google.com/specimen/JetBrains+Mono)
- **Iconography**: Google Material Symbols Outlined
- **Border Radius**: Crisp, engineered soft radius (4px standard buttons/inputs, 8px outer panels)

---

## Color Tokens

### Surface Hierarchy
| Token | Hex | Usage |
| :--- | :--- | :--- |
| `surface-canvas` | `#0B0F14` | Deepest canvas background, edge frame |
| `surface` / `surface-dim` | `#101419` | Default body and viewport background |
| `surface-container-lowest` | `#0A0E13` | Deep inset panels, terminal wells |
| `surface-container-low` | `#181C21` | Sidebar, persistent rails, header bars |
| `surface-container` | `#1C2025` | Cards, standard container modules |
| `surface-container-high` | `#262A30` | Hover states, active list items, highlighted cards |
| `surface-container-highest`| `#31353B` | Floating modals, flyouts, segmented control tracks |
| `surface-bright` | `#36393F` | Top-level elevated elements |

### Accent & Telemetry Palette
| Token | Hex | Semantic Meaning |
| :--- | :--- | :--- |
| `primary` | `#5CE2F6` / `#35C6D9` | **Studio Cyan**: Live recording state, waveform peaks, primary action CTA, active microphone |
| `secondary` | `#CEBDFF` / `#A78BFA` | **Studio Lavender**: AI reasoning traces, speech-to-text intelligence, insight chips |
| `tertiary` (Success) | `#5AE9AC` / `#10B981` | **Muted Emerald**: High readiness score, positive articulation, nominal latency |
| `warning` | `#F59E0B` | **Warm Amber**: Filler words flagged, pacing drift, unstable jitter |
| `error` | `#FFB4AB` / `#EF4444` | **Studio Coral**: Critical delivery alert, audio clip, hardware disconnect |

### Text & Hairline Neutrals
| Token | Hex | Usage |
| :--- | :--- | :--- |
| `on-surface` | `#E0E2EA` / `#F3F6FA` | Primary headlines, metric values, high contrast copy |
| `on-surface-variant` | `#BBC9CB` / `#9AA8BC` | Subheaders, meta descriptions, secondary metrics |
| `outline` | `#869395` | Secondary icons, inactive indicators, subtle dividers |
| `outline-variant` | `#3C494B` / `#223046` | Standard 1px structural hairline borders |

---

## Typography Scale

- **Display Large**: `40px` / Line Height `48px` / Letter Spacing `-0.02em` / Inter SemiBold (600)
- **Headline XL**: `32px` / Line Height `40px` / Letter Spacing `-0.02em` / Inter SemiBold (600)
- **Headline Large**: `24px` / Line Height `32px` / Letter Spacing `-0.015em` / Inter SemiBold (600)
- **Headline Medium**: `20px` / Line Height `28px` / Letter Spacing `-0.01em` / Inter Medium (500)
- **Body Large**: `16px` / Line Height `24px` / Letter Spacing `-0.005em` / Inter Regular (400)
- **Body Medium**: `14px` / Line Height `20px` / Letter Spacing `0em` / Inter Regular (400)
- **Body Small**: `13px` / Line Height `18px` / Letter Spacing `0em` / Inter Regular (400)
- **Metric Display**: `28px` / Line Height `32px` / Letter Spacing `-0.02em` / JetBrains Mono SemiBold (600)
- **Label Medium**: `12px` / Line Height `16px` / Letter Spacing `0.02em` / JetBrains Mono Medium (500)
- **Label Small**: `11px` / Line Height `14px` / Letter Spacing `0.04em` / JetBrains Mono Medium (500)

---

## Spacing & Grid System

- **Base Rhythm**: 4px micro-grid, 8px component rhythm
- `space-xxs`: `0.125rem` (2px)
- `space-xs`: `0.25rem` (4px)
- `space-sm`: `0.5rem` (8px)
- `space-md`: `0.75rem` (12px)
- `space-lg`: `1rem` (16px)
- `space-xl`: `1.5rem` (24px)
- `space-2xl`: `2rem` (32px)
- `space-3xl`: `3rem` (48px)
- `gutter`: `1.25rem` (20px) | `gutter-desktop`: `1.5rem` (24px)
- `margin`: `1rem` (16px) | `margin-desktop`: `2rem` (32px)

---

## Component Standards

### 1. Primary Action & Recording Buttons
- Standard Height: 36px (interface), 44px (session controller)
- Background: `#35C6D9` (Studio Cyan)
- Foreground: `#00363D` / `#0B0F14` SemiBold 600
- Border Radius: `4px`
- Hover: `#55D2E2` / Active Scale: `0.98`

### 2. Audio Visualizer Equalizer
- Width per bar: `2px` to `3px`, gap: `1.5px`
- Dynamic gradient fill from `#35C6D9` to `#A78BFA` based on real-time amplitude
- Inactive bars rest at `#223046`
- Telemetry badge overlay showing decibels (`-18.4 dB`) and pacing (`142 WPM`)

### 3. Metric Telemetry Cards
- Surface: `#181C21` / `#1C2025` with 1px `#3C494B` border
- Label: Uppercase `label-sm` (11px JetBrains Mono)
- Metric: `metric-display` (28px JetBrains Mono)
- Trend indicator: Small green/cyan badge (e.g., `+12% vs last drill`)
