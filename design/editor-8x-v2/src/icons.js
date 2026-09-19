import { LitElement, html, css } from 'https://esm.sh/lit@3'

const ICONS = {
  arrow: '<path d="M6 18 18 6M18 15V6H9"/>',
  number: '<path d="M10 3 5 21"/><path d="M19 3 14 21"/><path d="M22 9H4"/><path d="M20 16H2"/>',
  rect: '<path d="M2 12C2 7.3 2 4.9 3.5 3.5 4.9 2 7.3 2 12 2c4.7 0 7.1 0 8.5 1.5C22 4.9 22 7.3 22 12c0 4.7 0 7.1-1.5 8.5-1.4 1.5-3.8 1.5-8.5 1.5-4.7 0-7.1 0-8.5-1.5C2 19.1 2 16.7 2 12Z"/>',
  redact:
    '<path d="M2 12C2 7.3 2 4.9 3.5 3.5 4.9 2 7.3 2 12 2c4.7 0 7.1 0 8.5 1.5C22 4.9 22 7.3 22 12c0 4.7 0 7.1-1.5 8.5-1.4 1.5-3.8 1.5-8.5 1.5-4.7 0-7.1 0-8.5-1.5C2 19.1 2 16.7 2 12Z"/><g fill="currentColor" stroke="none"><rect x="6" y="6" width="3.4" height="3.4"/><rect x="14.6" y="6" width="3.4" height="3.4"/><rect x="10.3" y="10.3" width="3.4" height="3.4"/><rect x="6" y="14.6" width="3.4" height="3.4"/><rect x="14.6" y="14.6" width="3.4" height="3.4"/></g>',
  undo: '<path d="M4 7h11c1.9 0 2.8 0 3.5.4.5.3.9.7 1.1 1.1.4.7.4 1.6.4 3.5s0 2.8-.4 3.5c-.2.5-.6.9-1.1 1.1-.7.4-1.6.4-3.5.4H8M7 10 4 7l3-3"/>',
  redo: '<path d="M20 7H9c-1.9 0-2.8 0-3.5.4-.5.3-.9.7-1.1 1.1C4 9.2 4 10.1 4 12s0 2.8.4 3.5c.2.5.6.9 1.1 1.1.7.4 1.6.4 3.5.4h7M17 10l3-3-3-3"/>',
  save: '<path d="M3.5 20.5C4.9 22 7.3 22 12 22c4.7 0 7.1 0 8.5-1.5C22 19.1 22 16.7 22 12c0-.3 0-.5 0-.7-.1-.8-.4-1.6-.9-2.2-.1-.1-.2-.3-.5-.5L15.4 3.4c-.2-.2-.4-.4-.5-.5-.6-.5-1.4-.8-2.2-.9-.2 0-.4 0-.7 0-4.7 0-7.1 0-8.5 1.5C2 4.9 2 7.3 2 12c0 4.7 0 7.1 1.5 8.5Z"/><path d="M17 22v-1c0-1.9 0-2.8-.6-3.4-.6-.6-1.5-.6-3.4-.6h-2c-1.9 0-2.8 0-3.4.6-.6.6-.6 1.5-.6 3.4v1"/><path d="M7 8h6"/>',
  copy: '<path d="M6 11c0-2.8 0-4.2.9-5.1C7.8 5 9.2 5 12 5h3c2.8 0 4.2 0 5.1.9.9.9.9 2.3.9 5.1v5c0 2.8 0 4.2-.9 5.1-.9.9-2.3.9-5.1.9h-3c-2.8 0-4.2 0-5.1-.9-.9-.9-.9-2.3-.9-5.1v-5Z"/><path d="M6 19c-1.7 0-3-1.3-3-3v-6c0-3.8 0-5.7 1.2-6.8C5.3 2 7.2 2 11 2h4c1.7 0 3 1.3 3 3"/>',
  close: '<circle cx="12" cy="12" r="10"/><path d="M14.5 9.5 9.5 14.5M9.5 9.5l5 5"/>',
  dots: '<g fill="currentColor" stroke="none"><circle cx="5" cy="12" r="1.7"/><circle cx="12" cy="12" r="1.7"/><circle cx="19" cy="12" r="1.7"/></g>',
  pick: '<path d="M4 20l1.4-4.4 8.6-8.6 3 3-8.6 8.6L4 20Z"/><path d="M14 8l1.8-1.8a2.5 2.5 0 0 1 3.5 3.5L17.5 11.5"/>',
  chevron: '<path d="m6 15 6-6 6 6"/>',
  check: '<path d="M5 13l4 4L19 7"/>',
}

/**
 * Inline paths rather than `<use href="#id">`: a `use` reference is resolved inside the
 * element's own tree scope, so it cannot see a sprite that lives in the outer document.
 */
export class SniIcon extends LitElement {
  static properties = { name: {}, size: { type: Number } }

  static styles = css`
    :host {
      display: inline-flex;
      color: inherit;
    }
    svg {
      display: block;
      width: var(--icon-size, 20px);
      height: var(--icon-size, 20px);
      fill: none;
      stroke: currentColor;
      stroke-width: 1.5;
      stroke-linecap: round;
      stroke-linejoin: round;
    }
  `

  constructor() {
    super()
    this.size = 20
  }

  updated() {
    const svg = this.renderRoot.querySelector('svg')
    if (svg && svg.dataset.icon !== this.name) {
      svg.innerHTML = ICONS[this.name] ?? ''
      svg.dataset.icon = this.name
    }
  }

  render() {
    return html`<svg
      viewBox="0 0 24 24"
      aria-hidden="true"
      style=${`--icon-size:${this.size}px`}
    ></svg>`
  }
}

customElements.define('sni-icon', SniIcon)
