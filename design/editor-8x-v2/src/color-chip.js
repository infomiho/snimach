import { LitElement, html, css } from 'https://esm.sh/lit@3'
import './icons.js'

/** Anchored above the accessory bar, only while the colour tool is active. */
export class SniColorChip extends LitElement {
  static properties = { hex: {}, copied: { type: Boolean } }

  static styles = css`
    :host {
      display: block;
    }
    button {
      display: flex;
      align-items: center;
      gap: 10px;
      padding: 8px 10px 8px 12px;
      border-radius: 10px;
      background: rgba(38, 38, 43, 0.94);
      border: 1px solid #55555c;
      box-shadow: 0 12px 32px rgba(0, 0, 0, 0.5);
      -webkit-backdrop-filter: blur(24px) saturate(180%);
      backdrop-filter: blur(24px) saturate(180%);
      color: var(--sni-ink);
      font: inherit;
      cursor: default;
    }
    .sw {
      width: 22px;
      height: 22px;
      border-radius: 6px;
      box-shadow: inset 0 0 0 1px rgba(0, 0, 0, 0.45);
    }
    .stack {
      display: grid;
      line-height: 1.25;
      text-align: left;
    }
    .hex {
      font-family: var(--sni-mono);
      font-size: 13px;
      font-weight: 600;
      letter-spacing: 0.02em;
      font-variant-numeric: tabular-nums;
    }
    .hint {
      font-size: 11px;
      color: var(--sni-muted);
    }
    .hint.copied {
      color: var(--sni-accent);
    }
    sni-icon {
      color: var(--sni-muted);
      margin-left: 2px;
    }
    button:hover sni-icon {
      color: var(--sni-icon);
    }
    button:focus-visible {
      outline: 2px solid var(--sni-accent);
      outline-offset: 1px;
    }
  `

  render() {
    return html`
      <button
        title="Copy colour"
        @click=${() => this.dispatchEvent(new CustomEvent('copy', { bubbles: true, composed: true }))}
      >
        <span class="sw" style=${`background:${this.hex}`}></span>
        <span class="stack">
          <span class="hex">${this.hex}</span>
          <span class="hint ${this.copied ? 'copied' : ''}">${this.copied ? 'Copied' : 'Tab to copy · Esc to exit'}</span>
        </span>
        <sni-icon name="copy" size=${16}></sni-icon>
      </button>
    `
  }
}

customElements.define('sni-color-chip', SniColorChip)
