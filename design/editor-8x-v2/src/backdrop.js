import { LitElement, html, css } from 'https://esm.sh/lit@3'
import { PRESETS, gradient } from './tokens.js'
import './icons.js'

/** The named preset grid. Reached only through the backdrop button's disclosure affordance. */
export class SniBackdropPopover extends LitElement {
  static properties = { open: { type: Boolean }, preset: {}, active: { type: Boolean } }

  static styles = css`
    :host {
      display: block;
    }
    .pop {
      position: absolute;
      bottom: calc(100% + 10px);
      right: 0;
      width: min(240px, calc(100cqi - 72px));
      box-sizing: border-box;
      padding: 12px;
      border-radius: 12px;
      background: var(--sni-popover);
      border: 1px solid var(--sni-popover-border);
      box-shadow: 0 18px 48px rgba(0, 0, 0, 0.55);
      -webkit-backdrop-filter: blur(24px) saturate(180%);
      backdrop-filter: blur(24px) saturate(180%);
      transform: translateY(6px) scale(0.98);
      transform-origin: bottom center;
      opacity: 0;
      visibility: hidden;
      pointer-events: none;
    }
    .pop.open {
      opacity: 1;
      visibility: visible;
      pointer-events: auto;
      transform: translateY(0) scale(1);
    }
    @media (prefers-reduced-motion: no-preference) {
      .pop {
        transition:
          opacity var(--sni-fast) var(--sni-ease),
          transform var(--sni-fast) var(--sni-ease),
          visibility var(--sni-fast);
      }
    }
    .hd {
      font-size: 12px;
      font-weight: 600;
      color: var(--sni-ink);
      margin: 0 0 10px;
    }
    .grid {
      display: grid;
      grid-template-columns: repeat(4, 1fr);
      gap: 8px;
    }
    .sw {
      position: relative;
      aspect-ratio: 1;
      width: 100%;
      padding: 0;
      border: 0;
      border-radius: 9px;
      cursor: default;
      box-shadow: inset 0 0 0 1px rgba(0, 0, 0, 0.35);
    }
    .sw:focus-visible {
      outline: 2px solid var(--sni-accent);
      outline-offset: 3px;
    }
    .sw:hover {
      box-shadow:
        inset 0 0 0 1px rgba(0, 0, 0, 0.35),
        0 0 0 2px rgba(255, 255, 255, 0.55);
    }
    .sw[aria-pressed='true'] {
      box-shadow:
        inset 0 0 0 1px rgba(0, 0, 0, 0.35),
        0 0 0 2px var(--sni-accent);
    }
    .sw sni-icon {
      position: absolute;
      inset: 0;
      display: none;
      align-items: center;
      justify-content: center;
      color: #fff;
      filter: drop-shadow(0 1px 2px rgba(0, 0, 0, 0.7));
    }
    .sw[aria-pressed='true'] sni-icon {
      display: flex;
    }
    .ft {
      display: flex;
      align-items: baseline;
      justify-content: space-between;
      margin-top: 10px;
      font-size: 12px;
      color: var(--sni-ink);
    }
    .ft .k {
      color: var(--sni-muted);
      font-family: var(--sni-mono);
      font-size: 11px;
    }
    .ft .off {
      color: var(--sni-muted);
    }
  `

  #pick = (preset) => {
    this.dispatchEvent(
      new CustomEvent('preset', { detail: { preset }, bubbles: true, composed: true }),
    )
  }

  render() {
    return html`
      <div class="pop ${this.open ? 'open' : ''}" role="group" aria-label="Backdrop" aria-hidden=${this.open ? 'false' : 'true'}>
        <p class="hd">Backdrop</p>
        <div class="grid">
          ${PRESETS.map(
            (preset) => html`
              <button
                class="sw"
                style=${`background-image:${gradient(preset)}`}
                title=${preset.name}
                aria-label=${preset.name}
                aria-pressed=${preset.id === this.preset?.id ? 'true' : 'false'}
                @click=${() => this.#pick(preset)}
              >
                <sni-icon name="check" size=${18}></sni-icon>
              </button>
            `,
          )}
        </div>
        <div class="ft">
          <span class=${this.active ? '' : 'off'}>${this.active ? this.preset?.name : 'Transparent'}</span>
          <span class="k">K toggles</span>
        </div>
      </div>
    `
  }
}

/** One swatch you press, with a disclosure affordance for the preset grid. */
export class SniBackdropButton extends LitElement {
  static properties = { on: { type: Boolean }, preset: {}, open: { type: Boolean } }

  static styles = css`
    :host {
      display: inline-flex;
      position: relative;
    }
    .wrap {
      display: flex;
      align-items: center;
      border-radius: 10px;
      padding: 0 2px 0 0;
      gap: 1px;
    }
    .wrap:hover {
      background: rgba(255, 255, 255, 0.08);
    }
    button {
      display: inline-flex;
      align-items: center;
      gap: 8px;
      height: 30px;
      padding: 0;
      border: 0;
      background: transparent;
      color: var(--sni-icon);
      font: inherit;
      font-size: 13px;
      cursor: default;
    }
    .main {
      padding: 0 4px 0 8px;
    }
    .dot {
      width: 18px;
      height: 18px;
      border-radius: 50%;
      box-shadow: inset 0 0 0 1px rgba(0, 0, 0, 0.4);
      background: none;
      position: relative;
    }
    .dot::after {
      content: '';
      position: absolute;
      inset: 3px;
      border-radius: 50%;
      border: 1px dashed rgba(228, 228, 232, 0.55);
    }
    .wrap[data-on='true'] .dot::after {
      display: none;
    }
    @container (max-width: 450px) {
      .txt { display: none; }
    }
    .disc {
      width: 24px;
      height: 30px;
      justify-content: center;
      color: var(--sni-muted);
      border-radius: 6px;
    }
    .disc:hover {
      color: var(--sni-icon);
      background: rgba(255, 255, 255, 0.1);
    }
    button:focus-visible {
      outline: 2px solid var(--sni-accent);
      outline-offset: 1px;
    }
  `

  #emit = (name) => this.dispatchEvent(new CustomEvent(name, { bubbles: true, composed: true }))

  render() {
    const dotStyle = this.on ? `background-image:${gradient(this.preset)}` : ''
    return html`
      <span class="wrap" data-on=${this.on ? 'true' : 'false'}>
        <button
          class="main"
          aria-pressed=${this.on ? 'true' : 'false'}
          aria-label=${this.on ? `Backdrop on, ${this.preset.name}` : 'Backdrop off'}
          title=${this.on ? `${this.preset.name} · click to remove` : 'Add a backdrop'}
          @click=${() => this.#emit('backdrop-toggle')}
        >
          <span class="dot" style=${dotStyle}></span>
          <span class="txt">Backdrop</span>
        </button>
        <button
          class="disc"
          aria-label="Choose a backdrop"
          aria-expanded=${this.open ? 'true' : 'false'}
          title="Choose a backdrop"
          @click=${() => this.#emit('backdrop-menu')}
        >
          <sni-icon name="chevron" size=${13}></sni-icon>
        </button>
      </span>
      <sni-backdrop-popover
        .open=${this.open}
        .preset=${this.preset}
        .active=${this.on}
      ></sni-backdrop-popover>
    `
  }
}

customElements.define('sni-backdrop-popover', SniBackdropPopover)
customElements.define('sni-backdrop-button', SniBackdropButton)
