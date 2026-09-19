import { LitElement, html, css } from 'https://esm.sh/lit@3'
import { TOOLS, PRIMARY_TOOL_IDS } from './tokens.js'
import './chrome.js'
import './backdrop.js'

/** The floating edit surface. Tools, history, and image controls, grouped by job. */
export class SniAccessoryBar extends LitElement {
  static properties = {
    tool: {},
    canUndo: { type: Boolean },
    canRedo: { type: Boolean },
    backdrop: { type: Boolean },
    preset: {},
    picker: { type: Boolean },
    presetsOpen: { type: Boolean, attribute: 'presets-open' },
    overflow: { type: Boolean },
    menu: { type: Boolean },
    narrow: { type: Boolean },
  }

  static styles = css`
    :host {
      display: block;
    }
    *, *::before, *::after { box-sizing: border-box; }
    .bar {
      display: flex;
      align-items: center;
      gap: 6px;
      padding: 5px 7px;
      border-radius: 20px;
      background-image: var(--sni-glass);
      background-color: var(--sni-glass-base);
      border: 1px solid var(--sni-sep);
      box-shadow:
        inset 0 1px 0 rgba(255, 255, 255, 0.22),
        0 12px 40px rgba(0, 0, 0, 0.45);
      -webkit-backdrop-filter: blur(24px) saturate(180%);
      backdrop-filter: blur(24px) saturate(180%);
    }
    .sep {
      width: 1px;
      height: 20px;
      background: var(--sni-sep);
      flex: none;
    }
    .anchor {
      position: relative;
      display: inline-flex;
    }
    .menu {
      position: absolute;
      bottom: calc(100% + 10px);
      left: -3px;
      min-width: 176px;
      padding: 5px;
      border-radius: 10px;
      background: rgba(44, 44, 48, 0.96);
      border: 1px solid #55555c;
      box-shadow: 0 12px 40px rgba(0, 0, 0, 0.5);
      opacity: 0;
      visibility: hidden;
      pointer-events: none;
      transform: translateY(6px);
    }
    .menu.open {
      opacity: 1;
      visibility: visible;
      pointer-events: auto;
      transform: translateY(0);
    }
    @media (prefers-reduced-motion: no-preference) {
      .menu {
        transition:
          opacity var(--sni-fast) var(--sni-ease),
          transform var(--sni-fast) var(--sni-ease),
          visibility var(--sni-fast);
      }
    }
    .mi {
      display: flex;
      align-items: center;
      gap: 9px;
      width: 100%;
      padding: 5px 9px;
      border: 0;
      border-radius: 6px;
      background: transparent;
      color: var(--sni-icon);
      font: inherit;
      font-size: 13px;
      cursor: default;
      text-align: left;
    }
    .mi:hover {
      background: rgba(255, 255, 255, 0.1);
    }
    .mi[aria-pressed='true'] {
      background: var(--sni-on);
    }
    .mi .key {
      margin-left: auto;
      color: var(--sni-muted);
      font-family: var(--sni-mono);
      font-size: 12px;
    }
    .mi:focus-visible {
      outline: 2px solid var(--sni-accent);
      outline-offset: -2px;
    }
  `

  constructor() {
    super()
    this.menu = false
    this.canUndo = false
    this.canRedo = false
  }

  #docBound = false

  #emit = (name, detail) =>
    this.dispatchEvent(new CustomEvent(name, { detail, bubbles: true, composed: true }))

  #onDocPointer = (event) => {
    if (event.composedPath().includes(this)) return
    this.menu = false
  }

  updated() {
    if (this.menu && !this.#docBound) {
      document.addEventListener('pointerdown', this.#onDocPointer, true)
      this.#docBound = true
    } else if (!this.menu && this.#docBound) {
      document.removeEventListener('pointerdown', this.#onDocPointer, true)
      this.#docBound = false
    }
  }

  disconnectedCallback() {
    super.disconnectedCallback()
    if (this.#docBound) {
      document.removeEventListener('pointerdown', this.#onDocPointer, true)
      this.#docBound = false
    }
  }

  /** The selected tool stays visible even when the bar is tight, exactly like AppKit's overflow. */
  #visibleTools() {
    if (!this.overflow) return TOOLS
    if (this.narrow) return [TOOLS.find((tool) => tool.id === this.tool) ?? TOOLS[0]]
    const visible = TOOLS.filter((tool) => PRIMARY_TOOL_IDS.includes(tool.id))
    const selected = TOOLS.find((tool) => tool.id === this.tool)
    if (selected && !visible.includes(selected)) visible[visible.length - 1] = selected
    return visible
  }

  #hiddenTools() {
    const visible = this.#visibleTools().map((tool) => tool.id)
    return TOOLS.filter((tool) => !visible.includes(tool.id))
  }

  #onKeydown = (event) => {
    if (event.key === 'Escape' && this.menu) {
      this.menu = false
      this.renderRoot.querySelector('.anchor sni-tool-button')?.shadowRoot.querySelector('button').focus()
    }
  }

  render() {
    const toolButton = (tool) => html`
      <sni-tool-button
        icon=${tool.icon}
        label=${tool.label}
        hint=${tool.hint}
        .selected=${!this.picker && this.tool === tool.id}
        @action=${() => this.#emit('tool', { id: tool.id })}
      ></sni-tool-button>
    `

    return html`
      <div class="bar" @keydown=${this.#onKeydown} role="group" aria-label="Editor">
        <sni-tool-group label="Tools">
          ${this.#visibleTools().map(toolButton)}
          ${this.overflow
            ? html`
                <span class="anchor">
                  <sni-tool-button
                    icon="dots"
                    label="More tools"
                    .selected=${this.menu}
                    @action=${() => (this.menu = !this.menu)}
                  ></sni-tool-button>
                  <div class="menu ${this.menu ? 'open' : ''}" role="group" aria-label="More tools">
                    ${this.#hiddenTools().map(
                      (tool) => html`
                        <button
                          class="mi"
                          
                          aria-pressed=${this.tool === tool.id ? 'true' : 'false'}
                          @click=${() => {
                            this.menu = false
                            this.#emit('tool', { id: tool.id })
                          }}
                        >
                          <sni-icon name=${tool.icon} size=${17}></sni-icon>
                          ${tool.label}
                          <span class="key">${tool.hint}</span>
                        </button>
                      `,
                    )}
                  </div>
                </span>
              `
            : null}
        </sni-tool-group>

        <span class="sep" aria-hidden="true"></span>

        <sni-tool-group label="History">
          <sni-tool-button
            icon="undo"
            label="Undo"
            hint="⌘Z"
            .disabled=${!this.canUndo}
            @action=${() => this.#emit('undo')}
          ></sni-tool-button>
          <sni-tool-button
            icon="redo"
            label="Redo"
            hint="⇧⌘Z"
            .disabled=${!this.canRedo}
            @action=${() => this.#emit('redo')}
          ></sni-tool-button>
        </sni-tool-group>

        <span class="sep" aria-hidden="true"></span>

        <sni-tool-group label="Image">
          <sni-backdrop-button
            .on=${this.backdrop}
            .preset=${this.preset}
            .open=${this.presetsOpen}
          ></sni-backdrop-button>
          <sni-tool-button
            icon="pick"
            label="Colour picker"
            hint="I"
            .selected=${this.picker}
            @action=${() => this.#emit('picker')}
          ></sni-tool-button>
        </sni-tool-group>
      </div>
    `
  }
}

customElements.define('sni-accessory-bar', SniAccessoryBar)
