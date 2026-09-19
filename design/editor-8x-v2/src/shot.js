import { LitElement, html, css } from 'https://esm.sh/lit@3'

const SHOT_W = 900
const SHOT_H = 560

const paint = (canvas) => {
  const g = canvas.getContext('2d', { willReadFrequently: true })
  const { width: W, height: H } = canvas
  g.fillStyle = '#1e1e24'
  g.fillRect(0, 0, W, H)
  g.fillStyle = '#26262d'
  g.fillRect(0, 0, W, 34)
  g.fillStyle = '#ff5f57'
  g.beginPath()
  g.arc(20, 17, 6, 0, 7)
  g.fill()
  g.fillStyle = '#8e8e93'
  for (const x of [40, 60]) {
    g.beginPath()
    g.arc(x, 17, 6, 0, 7)
    g.fill()
  }
  g.fillStyle = '#17171b'
  g.fillRect(0, 34, 190, H - 34)
  g.fillStyle = '#242430'
  g.fillRect(20, 60, 150, 10)
  g.fillStyle = '#1c1c24'
  g.fillRect(20, 88, 120, 10)
  g.fillRect(20, 116, 140, 10)

  const lines = ['#c792ea', '#82aaff', '#7fdbca', '#f07178', '#ffcb6b', '#8e8e93']
  for (let r = 0; r < 18; r++) {
    let x = 216
    const y = 62 + r * 22
    for (let s = 0; s < 4; s++) {
      const w = 46 + ((r * 37 + s * 53) % 132)
      g.fillStyle = lines[(r + s) % lines.length]
      g.globalAlpha = 0.85
      g.fillRect(x, y, w, 9)
      x += w + 14
      if (x > W - 70) break
    }
  }
  g.globalAlpha = 1

  const ax0 = W * 0.42
  const ay0 = H * 0.72
  const ax1 = W * 0.74
  const ay1 = H * 0.4
  const ang = Math.atan2(ay1 - ay0, ax1 - ax0)
  const headLen = 30
  const bx = ax1 - headLen * 0.9 * Math.cos(ang)
  const by = ay1 - headLen * 0.9 * Math.sin(ang)
  g.strokeStyle = '#e8502a'
  g.lineWidth = 8
  g.lineCap = 'round'
  g.beginPath()
  g.moveTo(ax0, ay0)
  g.lineTo(bx, by)
  g.stroke()
  g.fillStyle = '#e8502a'
  g.beginPath()
  g.moveTo(ax1, ay1)
  g.lineTo(ax1 - headLen * Math.cos(ang - Math.PI / 7), ay1 - headLen * Math.sin(ang - Math.PI / 7))
  g.lineTo(ax1 - headLen * Math.cos(ang + Math.PI / 7), ay1 - headLen * Math.sin(ang + Math.PI / 7))
  g.closePath()
  g.fill()
}

const hexAt = (g, x, y) => {
  const px = Math.max(0, Math.min(x, g.canvas.width - 1))
  const py = Math.max(0, Math.min(y, g.canvas.height - 1))
  const [r, gg, b] = g.getImageData(px, py, 1, 1).data
  return `#${[r, gg, b].map((v) => v.toString(16).padStart(2, '0')).join('').toUpperCase()}`
}

/** A stand-in for the captured screenshot. Reads real pixels so the colour tool has something true to report. */
export class SniShot extends LitElement {
  static properties = { mini: { type: Boolean }, picking: { type: Boolean } }

  static styles = css`
    :host {
      display: block;
      line-height: 0;
    }
    canvas {
      display: block;
      width: 100%;
      height: auto;
      border-radius: 4px;
      background: #1e1e24;
    }
    :host([picking]) canvas {
      cursor: crosshair;
    }
    :host([picking]) {
      outline: 1.5px solid var(--sni-accent);
      outline-offset: -1px;
      border-radius: 4px;
    }
    .mock {
      border-radius: 4px;
      background: #1e1e24;
      padding: 10px 12px;
      display: grid;
      gap: 7px;
    }
    .mock i {
      display: block;
      height: 6px;
      border-radius: 3px;
      background: #4d4d57;
    }
    .mock i:nth-child(1) {
      width: 62%;
      background: #82aaff;
    }
    .mock i:nth-child(2) {
      width: 84%;
    }
    .mock i:nth-child(3) {
      width: 40%;
      background: #7fdbca;
    }
  `

  firstUpdated() {
    const canvas = this.renderRoot.querySelector('canvas')
    if (canvas) paint(canvas)
  }

  #onMove = (event) => {
    if (!this.picking) return
    const canvas = this.renderRoot.querySelector('canvas')
    if (!canvas) return
    const rect = canvas.getBoundingClientRect()
    const x = Math.round(((event.clientX - rect.left) / rect.width) * canvas.width)
    const y = Math.round(((event.clientY - rect.top) / rect.height) * canvas.height)
    const hex = hexAt(canvas.getContext('2d', { willReadFrequently: true }), x, y)
    this.dispatchEvent(new CustomEvent('pixel', { detail: { hex }, bubbles: true, composed: true }))
  }

  render() {
    if (this.mini) {
      return html`<div class="mock"><i></i><i></i><i></i></div>`
    }
    return html`<canvas
      width=${SHOT_W}
      height=${SHOT_H}
      @pointermove=${this.#onMove}
    ></canvas>`
  }
}

customElements.define('sni-shot', SniShot)
