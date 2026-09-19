import { tokens } from './tokens.js'

import './chrome.js'
import './backdrop.js'
import './shot.js'
import './accessory-bar.js'
import './color-chip.js'
import './editor-window.js'

export { PRESETS, presetById, gradient, TOOLS } from './tokens.js'

const sheet = document.createElement('style')
sheet.textContent = tokens.cssText
document.head.append(sheet)
