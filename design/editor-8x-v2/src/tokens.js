import { css } from 'https://esm.sh/lit@3'

export const tokens = css`
  :root {
    --sni-bg: #0c0c0d;
    --sni-window: #1e1e21;
    --sni-bar: #26262b;
    --sni-ink: #ececee;
    --sni-muted: #9a9aa0;
    --sni-icon: #e4e4e8;
    --sni-line: rgba(0, 0, 0, 0.45);
    --sni-sep: rgba(255, 255, 255, 0.14);
    --sni-on: rgba(255, 255, 255, 0.16);
    --sni-on-edge: rgba(255, 255, 255, 0.22);
    --sni-accent: #e8502a;
    --sni-glass: linear-gradient(rgba(255, 255, 255, 0.14), rgba(255, 255, 255, 0.05));
    --sni-glass-base: rgba(20, 20, 23, 0.66);
    --sni-stage-inset: 18px;
    --sni-popover: rgba(38, 38, 43, 0.96);
    --sni-popover-border: #55555c;
    --sni-radius: 10px;
    --sni-sans: system-ui, -apple-system, sans-serif;
    --sni-mono: ui-monospace, SFMono-Regular, monospace;
    --sni-ease: cubic-bezier(0.32, 0.72, 0, 1);
    --sni-fast: 140ms;
    --sni-slow: 320ms;
  }
`

export const PRESETS = [
  { id: 'gotham', name: 'Gotham', stops: [['#374151', 0], ['#111827', 55], ['#000000', 100]] },
  { id: 'arendelle', name: 'Arendelle', stops: [['#dbeafe', 0], ['#93c5fd', 55], ['#3b82f6', 100]] },
  { id: 'minimal4', name: 'Minimal 4', stops: [['#e7e6e6', 0], ['#cac8c4', 55], ['#c1bdb8', 100]] },
  { id: 'heather6', name: 'Heather 6', stops: [['#5f719b', 0], ['#557132', 55], ['#103211', 100]] },
  { id: 'sierra10', name: 'Sierra 10', stops: [['#b6d0e7', 0], ['#655851', 55], ['#363a37', 100]] },
  { id: 'sierra7', name: 'Sierra 7', stops: [['#d0e2ec', 0], ['#557189', 55], ['#2d5874', 100]] },
  { id: 'wetlands9', name: 'Wetlands 9', stops: [['#cdd3d0', 0], ['#97915c', 55], ['#252d0d', 100]] },
  { id: 'sierraMist', name: 'Sierra Mist', stops: [['#fef08a', 0], ['#bbf7d0', 55], ['#86efac', 100]] },
  { id: 'islandWaves', name: 'Island Waves', stops: [['#facc15', 0], ['#f9fafb', 55], ['#5eead4', 100]] },
  { id: 'twilight10', name: 'Twilight 10', stops: [['#dccebc', 0], ['#625e4e', 55], ['#0e1510', 100]] },
  { id: 'quartz8', name: 'Quartz 8', stops: [['#e1e7ed', 0], ['#c9d6e1', 55], ['#acbecc', 100]] },
]

export const presetById = (id) => PRESETS.find((p) => p.id === id) ?? PRESETS[0]

export const gradient = (preset) =>
  `linear-gradient(135deg, ${preset.stops.map(([hex, at]) => `${hex} ${at}%`).join(', ')})`

export const TOOLS = [
  { id: 'arrow', icon: 'arrow', label: 'Arrow', hint: 'A' },
  { id: 'number', icon: 'number', label: 'Number', hint: 'N' },
  { id: 'rectangle', icon: 'rect', label: 'Rectangle', hint: 'R' },
  { id: 'redact', icon: 'redact', label: 'Hide', hint: 'B' },
]

export const PRIMARY_TOOL_IDS = ['arrow', 'number']
