import { LitElement, html, css, nothing } from 'https://esm.sh/lit@3'
import './icons.js'

/** One icon-only control. Selection is a pressed state, not a colour change. */
export class SniToolButton extends LitElement {
  static properties = {
    icon: {},
    label: {},
    hint: {},
    selected: { type: Boolean },
    disabled: { type: Boolean },
    wide: { type: Boolean },
  }

  static styles = css`
    :host {
      display: inline-flex;
    }
    button {
      display: inline-flex;
      align-items: center;
      justify-content: center;
      gap: 7px;
      width: 34px;
      height: 30px;
      padding: 0;
      border: 0;
      border-radius: 7px;
      background: transparent;
      color: var(--sni-icon);
      font: inherit;
      cursor: default;
    }
    button.wide {
      width: auto;
      padding: 0 10px;
      font-size: 13px;
    }
    button:hover:not(:disabled) {
      background: rgba(255, 255, 255, 0.08);
    }
    button[aria-pressed='true'] {
      background: var(--sni-on);
      box-shadow: inset 0 0 0 1px var(--sni-on-edge);
    }
    button:active:not(:disabled) {
      background: rgba(255, 255, 255, 0.22);
    }
    button:disabled {
      color: rgba(228, 228, 232, 0.32);
    }
    button:focus-visible {
      outline: 2px solid var(--sni-accent);
      outline-offset: 1px;
    }
    .txt {
      white-space: nowrap;
    }
    @media (prefers-reduced-motion: no-preference) {
      button {
        transition: background var(--sni-fast) var(--sni-ease);
      }
    }
  `

  #emit = (name) => {
    this.dispatchEvent(new CustomEvent(name, { bubbles: true, composed: true }))
  }

  render() {
    const title = this.hint ? `${this.label} (${this.hint})` : this.label
    return html`
      <button
        class=${this.wide ? 'wide' : ''}
        title=${title}
        aria-label=${this.label}
        aria-pressed=${this.selected === undefined ? nothing : String(this.selected)}
        ?disabled=${this.disabled}
        @click=${() => this.#emit('action')}
      >
        <sni-icon name=${this.icon} size=${this.wide ? 16 : 19}></sni-icon>
        ${this.wide ? html`<span class="txt">${this.label}</span>` : null}
      </button>
    `
  }
}

/** A row of related controls. `capsule` draws the glass pill used in the title bar. */
export class SniToolGroup extends LitElement {
  static properties = { label: {}, capsule: { type: Boolean } }

  static styles = css`
    :host {
      display: inline-flex;
    }
    .grp {
      display: flex;
      align-items: center;
      gap: 1px;
    }
    .grp.capsule {
      padding: 3px;
      border-radius: 14px;
      background-image: var(--sni-glass);
      background-color: var(--sni-glass-base);
      border: 1px solid var(--sni-sep);
      box-shadow:
        inset 0 1px 0 rgba(255, 255, 255, 0.22),
        0 4px 16px rgba(0, 0, 0, 0.35);
    }
  `

  render() {
    return html`<div
      class="grp ${this.capsule ? 'capsule' : ''}"
      role="group"
      aria-label=${this.label ?? ''}
    >
      <slot></slot>
    </div>`
  }
}

/** Window chrome. Output actions live here because they act on the finished image, not on a tool. */
export class SniTitleBar extends LitElement {
  static properties = { title: {}, canSave: { type: Boolean } }

  static styles = css`
    :host {
      display: block;
    }
    .tb {
      display: flex;
      align-items: center;
      height: 52px;
      padding: 0 12px 0 14px;
      gap: 10px;
      background: var(--sni-bar);
      border-bottom: 1px solid #141416;
    }
    .lights {
      display: flex;
      gap: 8px;
    }
    .lights i {
      width: 12px;
      height: 12px;
      border-radius: 50%;
      display: block;
      background: #8e8e93;
      border: 1px solid rgba(0, 0, 0, 0.4);
    }
    .lights i.close {
      background: #ff5f57;
    }
    .title {
      font-size: 13px;
      font-weight: 600;
      color: #dcdce0;
      white-space: nowrap;
    }
    .grow {
      flex: 1;
    }
    .trail {
      display: flex;
      align-items: center;
      gap: 8px;
    }
  `

  #output = (action) =>
    this.dispatchEvent(
      new CustomEvent('output', { detail: { action }, bubbles: true, composed: true }),
    )

  render() {
    return html`
      <div class="tb">
        <span class="lights"><i class="close"></i><i></i><i></i></span>
        <span class="title">${this.title ?? 'Snimach'}</span>
        <span class="grow"></span>
        <span class="trail">
          <sni-tool-group label="Output" capsule>
            <sni-tool-button icon="close" label="Discard" hint="⌘⌫" @action=${() => this.#output('discard')}></sni-tool-button>
            <sni-tool-button icon="save" label="Save" hint="⌘S" @action=${() => this.#output('save')}></sni-tool-button>
            <sni-tool-button icon="copy" label="Copy" hint="⌘C" @action=${() => this.#output('copy')}></sni-tool-button>
          </sni-tool-group>
        </span>
      </div>
    `
  }
}

customElements.define('sni-tool-button', SniToolButton)
customElements.define('sni-tool-group', SniToolGroup)
customElements.define('sni-title-bar', SniTitleBar)
