import { LitElement, html, css } from 'https://esm.sh/lit@3'
import { presetById, gradient } from './tokens.js'
import './chrome.js'
import './shot.js'
import './accessory-bar.js'
import './color-chip.js'

const TOOL_KEYS = { a: 'arrow', n: 'number', r: 'rectangle', b: 'redact' }

/**
 * Layout composition: window chrome, the stage the shot lives on, and the floating edit surface.
 * The stage box never changes size, so toggling a backdrop never resizes the window.
 */
export class SniEditorWindow extends LitElement {
  static properties = {
    width: { type: Number },
    stageHeight: { type: Number, attribute: 'stage-height' },
    tool: {},
    presetId: { attribute: 'preset-id' },
    backdrop: { type: Boolean },
    picker: { type: Boolean },
    presetsOpen: { type: Boolean, attribute: 'presets-open' },
    overflow: { type: Boolean },
    compact: { state: true },
    narrow: { state: true },
    hex: {},
    copied: { type: Boolean },
  }

  static styles = css`
    :host {
      display: block;
    }
    *, *::before, *::after { box-sizing: border-box; }
    .win {
      width: 100%;
      max-width: var(--editor-width);
      container-type: inline-size;
      background: var(--sni-window);
      border: 1px solid #000;
      border-radius: var(--sni-radius);
      overflow: hidden;
      box-shadow: 0 20px 60px rgba(0, 0, 0, 0.55);
      outline: none;
    }
    .win:focus-visible {
      box-shadow:
        0 0 0 2px var(--sni-accent),
        0 20px 60px rgba(0, 0, 0, 0.55);
    }
    .stage {
      position: relative;
      display: grid;
      grid-template: minmax(0, 1fr) / minmax(0, 1fr);
      padding: var(--sni-stage-inset);
      height: max(300px, var(--stage-height));
      min-width: 0;
      min-height: 0;
    }
    .mat {
      grid-area: 1 / 1;
      min-width: 0;
      min-height: 0;
      position: relative;
      display: grid;
      place-items: center;
      padding: 0;
      border-radius: 6px;
      transition:
        padding var(--sni-slow) var(--sni-ease),
        border-radius var(--sni-slow) var(--sni-ease),
        box-shadow var(--sni-slow) var(--sni-ease);
    }
    .mat::before {
      content: '';
      position: absolute;
      inset: 0;
      border-radius: inherit;
      background-image: var(--mat-image, none);
      opacity: 0;
      transition: opacity var(--sni-slow) var(--sni-ease);
    }
    .mat.on {
      --mat-padding: clamp(16px, 4cqi, 34px);
      padding: var(--mat-padding);
      border-radius: 14px;
      box-shadow: 0 22px 50px rgba(0, 0, 0, 0.45);
    }
    .mat.on::before {
      opacity: 1;
    }
    .shot {
      position: relative;
      display: grid;
      place-items: center;
      width: min(100%, calc((max(300px, var(--stage-height)) - 2 * var(--sni-stage-inset) - 2 * var(--mat-padding, 0px)) * 900 / 560));
      aspect-ratio: 900 / 560;
      transition: width var(--sni-slow) var(--sni-ease);
      min-width: 0;
      min-height: 0;
      border-radius: 4px;
      overflow: hidden;
      box-shadow: 0 12px 30px rgba(0, 0, 0, 0.5);
    }
    sni-shot {
      width: 100%;
    }
    .float {
      position: absolute;
      left: 50%;
      bottom: var(--sni-stage-inset);
      transform: translateX(-50%);
      z-index: 3;
    }
    .chip {
      position: absolute;
      left: 50%;
      bottom: 78px;
      transform: translateX(-50%);
      z-index: 4;
    }
    @media (prefers-reduced-motion: reduce) {
      .mat,
      .mat::before,
      .shot {
        transition: none;
      }
    }
  `

  constructor() {
    super()
    this.width = 900
    this.stageHeight = 574
    this.tool = 'arrow'
    this.presetId = 'sierra7'
    this.backdrop = false
    this.picker = false
    this.presetsOpen = false
    this.overflow = false
    this.hex = '#1A1A1A'
    this.copied = false
  }

  #resizeObserver = new ResizeObserver(([entry]) => {
    this.compact = entry.contentRect.width < 450
    this.narrow = entry.contentRect.width < 340
  })

  firstUpdated() {
    this.#resizeObserver.observe(this.renderRoot.querySelector('.win'))
  }

  #docBound = false

  #onDocPointer = (event) => {
    if (event.composedPath().includes(this)) return
    this.presetsOpen = false
  }

  updated() {
    if (this.presetsOpen && !this.#docBound) {
      document.addEventListener('pointerdown', this.#onDocPointer, true)
      this.#docBound = true
    } else if (!this.presetsOpen && this.#docBound) {
      document.removeEventListener('pointerdown', this.#onDocPointer, true)
      this.#docBound = false
    }
  }

  disconnectedCallback() {
    super.disconnectedCallback()
    this.#resizeObserver.disconnect()
    clearTimeout(this.#copyTimer)
    if (this.#docBound) {
      document.removeEventListener('pointerdown', this.#onDocPointer, true)
      this.#docBound = false
    }
  }

  #toggleBackdrop = () => {
    this.backdrop = !this.backdrop
    if (!this.backdrop) this.presetsOpen = false
  }

  #togglePicker = () => {
    this.picker = !this.picker
    if (this.picker) this.presetsOpen = false
  }

  #togglePopover = () => {
    this.presetsOpen = !this.presetsOpen
    if (this.presetsOpen) this.picker = false
  }

  #onStagePointer = (event) => {
    if (!event.composedPath().some((node) => node.localName === 'sni-accessory-bar')) this.presetsOpen = false
  }

  #onTool = (event) => {
    this.tool = event.detail.id
    this.picker = false
  }

  #onPreset = (event) => {
    this.presetId = event.detail.preset.id
    this.backdrop = true
    this.presetsOpen = false
    this.#focusPresetButton()
  }

  #focusPresetButton() {
    this.renderRoot.querySelector('sni-accessory-bar')?.shadowRoot
      .querySelector('sni-backdrop-button')?.shadowRoot.querySelector('.disc').focus()
  }

  #onPixel = (event) => {
    this.hex = event.detail.hex
    this.copied = false
  }

  #copyHex = async () => {
    const hex = this.hex
    try {
      await navigator.clipboard.writeText(hex)
    } catch {
      this.dispatchEvent(new CustomEvent('copy-failed', { bubbles: true, composed: true }))
      return
    }
    this.copied = true
    clearTimeout(this.#copyTimer)
    this.#copyTimer = setTimeout(() => (this.copied = false), 1400)
    this.dispatchEvent(new CustomEvent('copied', { detail: { hex }, bubbles: true, composed: true }))
  }

  #copyTimer

  #onKeydown = (event) => {
    if (event.metaKey || event.ctrlKey || event.altKey) return
    const key = event.key.toLowerCase()
    if (key === 'escape') {
      if (this.presetsOpen) this.#focusPresetButton()
      this.picker = false
      this.presetsOpen = false
      return
    }
    if (key === 'tab' && this.picker && event.composedPath()[0] === this.renderRoot.querySelector('.win')) {
      event.preventDefault()
      this.#copyHex()
      return
    }
    if (key === 'k') return this.#toggleBackdrop()
    if (key === 'i') return this.#togglePicker()
    const tool = TOOL_KEYS[key]
    if (tool) {
      this.tool = tool
      this.picker = false
    }
  }

  render() {
    const preset = presetById(this.presetId)
    return html`
      <article
        class="win"
        style=${`--editor-width:${this.width}px;--stage-height:${this.stageHeight / this.width * 100}cqi`}
        tabindex="0"
        aria-label="Snimach editor"
        @keydown=${this.#onKeydown}
      >
        <sni-title-bar
          @output=${(event) =>
            this.dispatchEvent(new CustomEvent(event.detail.action, { bubbles: true, composed: true }))}
        ></sni-title-bar>
        <div class="stage" @pointerdown=${this.#onStagePointer}>
          <div
            class="mat ${this.backdrop ? 'on' : ''}"
            style=${`--mat-image:${gradient(preset)}`}
          >
            <div class="shot">
              <sni-shot
                ?picking=${this.picker}
                @pixel=${this.#onPixel}
              ></sni-shot>
            </div>
          </div>
          <div class="float">
            <sni-accessory-bar
              .tool=${this.tool}
              .preset=${preset}
              .backdrop=${this.backdrop}
              .picker=${this.picker}
              .presetsOpen=${this.presetsOpen}
              .overflow=${this.overflow || this.compact}
              .narrow=${this.narrow}
              @tool=${this.#onTool}
              @backdrop-toggle=${this.#toggleBackdrop}
              @backdrop-menu=${this.#togglePopover}
              @preset=${this.#onPreset}
              @picker=${this.#togglePicker}
            ></sni-accessory-bar>
          </div>
          ${this.picker
            ? html`<div class="chip">
                <sni-color-chip .hex=${this.hex} .copied=${this.copied} @copy=${this.#copyHex}></sni-color-chip>
              </div>`
            : null}
        </div>
      </article>
    `
  }
}

customElements.define('sni-editor-window', SniEditorWindow)
