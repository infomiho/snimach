//! Decorative illustrations for the home page bento tiles.
//!
//! SVG shapes need an explicit empty body (`rect {}`, not `rect;`): maud only
//! omits the closing tag for known HTML void elements, and an unclosed `<rect>`
//! makes the HTML parser nest the rest of the drawing inside it.

use maud::{Markup, html};

const VIEW_WIDE: &str = "0 0 600 96";
const VIEW_NARROW: &str = "0 0 280 72";

/// Three captures: dimmed screens where the captured region lights up on hover.
pub fn capture() -> Markup {
    html! {
        svg .viz .viz-capture viewBox=(VIEW_WIDE) aria-hidden="true" {
            g .panel .panel-area {
                rect .screen x="12" y="6" width="180" height="72" rx="8" {}
                rect .dim x="12" y="6" width="180" height="72" rx="8" {}
                rect .cutout x="92" y="28" width="70" height="40" rx="2" {}
                rect .line x="24" y="18" width="56" height="4" rx="2" {}
                rect .line x="24" y="27" width="40" height="4" rx="2" {}
                rect .line x="24" y="36" width="120" height="4" rx="2" {}
                rect .line x="24" y="45" width="100" height="4" rx="2" {}
                rect .line x="24" y="54" width="60" height="4" rx="2" {}
                rect .target x="92" y="28" width="70" height="40" rx="2" {}
                g .brackets {
                    path d="M 92 36 L 92 28 L 100 28" {}
                    path d="M 154 28 L 162 28 L 162 36" {}
                    path d="M 162 60 L 162 68 L 154 68" {}
                    path d="M 100 68 L 92 68 L 92 60" {}
                }
                text .label x="102" y="90" { "640 × 400" }
            }

            g .panel .panel-window {
                rect .screen x="210" y="6" width="180" height="72" rx="8" {}
                rect .dim x="210" y="6" width="180" height="72" rx="8" {}
                rect .cutout x="282" y="17" width="96" height="50" rx="4" {}
                rect .line x="222" y="18" width="50" height="4" rx="2" {}
                rect .line x="222" y="27" width="36" height="4" rx="2" {}
                rect .line x="222" y="36" width="48" height="4" rx="2" {}
                rect .line x="222" y="45" width="40" height="4" rx="2" {}
                rect .line x="222" y="54" width="30" height="4" rx="2" {}
                ellipse .window-shadow cx="330" cy="68.5" rx="46" ry="3" {}
                rect .target x="282" y="17" width="96" height="50" rx="4" {}
                line .titlebar x1="282" y1="27" x2="378" y2="27" {}
                circle .dot cx="288" cy="22" r="1.5" {}
                circle .dot cx="293.5" cy="22" r="1.5" {}
                circle .dot cx="299" cy="22" r="1.5" {}
                rect .line x="292" y="35" width="56" height="4" rx="2" {}
                rect .line x="292" y="44" width="40" height="4" rx="2" {}
                rect .line x="292" y="53" width="48" height="4" rx="2" {}
                g .brackets {
                    path d="M 282 25 L 282 17 L 290 17" {}
                    path d="M 370 17 L 378 17 L 378 25" {}
                    path d="M 378 59 L 378 67 L 370 67" {}
                    path d="M 290 67 L 282 67 L 282 59" {}
                }
                text .label x="300" y="90" { "1280 × 832" }
            }

            g .panel .panel-screen {
                rect .screen x="408" y="6" width="180" height="72" rx="8" {}
                rect .dim x="408" y="6" width="180" height="72" rx="8" {}
                rect .cutout x="408" y="6" width="180" height="72" rx="8" {}
                rect .line x="420" y="18" width="56" height="4" rx="2" {}
                rect .line x="420" y="27" width="40" height="4" rx="2" {}
                rect .line x="420" y="36" width="120" height="4" rx="2" {}
                rect .line x="420" y="45" width="100" height="4" rx="2" {}
                rect .line x="420" y="54" width="60" height="4" rx="2" {}
                rect .target x="408" y="6" width="180" height="72" rx="8" {}
                g .brackets {
                    path d="M 413 19 L 413 11 L 421 11" {}
                    path d="M 575 11 L 583 11 L 583 19" {}
                    path d="M 583 65 L 583 73 L 575 73" {}
                    path d="M 421 73 L 413 73 L 413 65" {}
                }
                text .label x="498" y="90" { "Display 1" }
            }
        }
    }
}

/// Clipboard first: the glyph already holds the shot, the preview card slides in second.
pub fn clipboard() -> Markup {
    html! {
        svg .viz .viz-clipboard viewBox=(VIEW_NARROW) aria-hidden="true" {
            defs {
                clipPath id="snimach-viz-clipboard-screen" {
                    rect x="124" y="6" width="150" height="60" rx="8" {}
                }
            }
            g .clipboard {
                rect .board x="46" y="20" width="26" height="32" rx="4" {}
                rect .tab x="53" y="17" width="12" height="6" rx="2" {}
                rect .held x="51" y="27" width="16" height="12" rx="2" {}
                path .check d="M 53 45 L 57 49 L 65 42" {}
            }
            rect .screen x="124" y="6" width="150" height="60" rx="8" {}
            rect .line x="136" y="18" width="70" height="4" rx="2" {}
            rect .line x="136" y="27" width="50" height="4" rx="2" {}
            rect .line x="136" y="36" width="60" height="4" rx="2" {}
            g clip-path="url(#snimach-viz-clipboard-screen)" {
                g .card {
                    rect .card-body x="224" y="26" width="44" height="34" rx="6" {}
                    rect .thumb x="229" y="31" width="34" height="16" rx="3" {}
                    g .card-actions {
                        circle cx="234" cy="53.5" r="2.5" {}
                        circle cx="246" cy="53.5" r="2.5" {}
                        circle cx="258" cy="53.5" r="2.5" {}
                    }
                }
            }
        }
    }
}

/// Annotate: four tools placed in ink, committing to the accent in tool order.
pub fn annotate() -> Markup {
    html! {
        svg .viz .viz-annotate viewBox=(VIEW_NARROW) aria-hidden="true" {
            rect .shot x="8" y="6" width="264" height="60" rx="8" {}
            rect .line x="20" y="16" width="150" height="4" rx="2" {}
            rect .line x="20" y="27" width="92" height="4" rx="2" {}
            rect .line x="20" y="38" width="120" height="4" rx="2" {}
            rect .line x="20" y="49" width="70" height="4" rx="2" {}
            g .arrow {
                line .arrow-shaft x1="200" y1="58" x2="245" y2="26.7" {}
                path .arrow-head d="M 239 26.6 L 246 26 L 243 32.3" {}
            }
            rect .frame x="76" y="23" width="52" height="13" rx="2" {}
            g .badge {
                circle cx="131" cy="22" r="7" {}
                text x="131" y="22" { "1" }
            }
            g .pixels {
                rect .cell-a x="172" y="11" width="5" height="5" {}
                rect .cell-b x="177" y="11" width="5" height="5" {}
                rect .cell-a x="182" y="11" width="5" height="5" {}
                rect .cell-b x="187" y="11" width="5" height="5" {}
                rect .cell-b x="172" y="16" width="5" height="5" {}
                rect .cell-a x="177" y="16" width="5" height="5" {}
                rect .cell-b x="182" y="16" width="5" height="5" {}
                rect .cell-a x="187" y="16" width="5" height="5" {}
                rect .cell-a x="172" y="21" width="5" height="5" {}
                rect .cell-b x="177" y="21" width="5" height="5" {}
                rect .cell-a x="182" y="21" width="5" height="5" {}
                rect .cell-b x="187" y="21" width="5" height="5" {}
            }
        }
    }
}

/// Backdrops: a thin ink gradient peeks around the shot and grows to full padding.
pub fn backdrop() -> Markup {
    html! {
        svg .viz .viz-backdrop viewBox=(VIEW_NARROW) aria-hidden="true" {
            defs {
                linearGradient id="snimach-viz-backdrop-gradient" x1="0" y1="0" x2="1" y2="1" {
                    stop .stop-start offset="0" {}
                    stop .stop-end offset="1" {}
                }
            }
            rect .backdrop x="76" y="9" width="128" height="54" rx="8" {}
            ellipse .shadow cx="140" cy="60" rx="50" ry="3" {}
            rect .shot x="80" y="13" width="120" height="46" {}
            rect .line x="90" y="23" width="64" height="4" rx="2" {}
            rect .line x="90" y="32" width="44" height="4" rx="2" {}
            rect .line x="90" y="41" width="56" height="4" rx="2" {}
        }
    }
}

/// Color inspector: a loupe over the shot and a readout pill that fills with the picked hex.
pub fn inspect() -> Markup {
    html! {
        svg .viz .viz-inspect viewBox=(VIEW_NARROW) aria-hidden="true" {
            defs {
                clipPath id="snimach-viz-loupe-lens" {
                    circle cx="100" cy="38" r="16" {}
                }
            }
            rect .shot x="8" y="6" width="140" height="60" rx="8" {}
            rect .line x="20" y="18" width="60" height="4" rx="2" {}
            rect .line x="20" y="27" width="44" height="4" rx="2" {}
            rect .line x="20" y="36" width="52" height="4" rx="2" {}
            rect .line x="20" y="50" width="100" height="4" rx="2" {}
            g .loupe {
                g clip-path="url(#snimach-viz-loupe-lens)" {
                    g .grid {
                        rect .g2 x="85" y="23" width="6" height="6" {}
                        rect .g1 x="91" y="23" width="6" height="6" {}
                        rect .g3 x="97" y="23" width="6" height="6" {}
                        rect .g1 x="103" y="23" width="6" height="6" {}
                        rect .g2 x="109" y="23" width="6" height="6" {}
                        rect .g1 x="85" y="29" width="6" height="6" {}
                        rect .g3 x="91" y="29" width="6" height="6" {}
                        rect .g2 x="97" y="29" width="6" height="6" {}
                        rect .g2 x="103" y="29" width="6" height="6" {}
                        rect .g1 x="109" y="29" width="6" height="6" {}
                        rect .g3 x="85" y="35" width="6" height="6" {}
                        rect .g2 x="91" y="35" width="6" height="6" {}
                        rect .g1 x="97" y="35" width="6" height="6" {}
                        rect .g3 x="103" y="35" width="6" height="6" {}
                        rect .g2 x="109" y="35" width="6" height="6" {}
                        rect .g2 x="85" y="41" width="6" height="6" {}
                        rect .g1 x="91" y="41" width="6" height="6" {}
                        rect .g3 x="97" y="41" width="6" height="6" {}
                        rect .g1 x="103" y="41" width="6" height="6" {}
                        rect .g3 x="109" y="41" width="6" height="6" {}
                        rect .g1 x="85" y="47" width="6" height="6" {}
                        rect .g3 x="91" y="47" width="6" height="6" {}
                        rect .g2 x="97" y="47" width="6" height="6" {}
                        rect .g1 x="103" y="47" width="6" height="6" {}
                        rect .g2 x="109" y="47" width="6" height="6" {}
                    }
                }
                rect .pixel x="97" y="35" width="6" height="6" {}
                circle .ring cx="100" cy="38" r="17" {}
            }
            g .readout {
                rect .pill x="178" y="25" width="96" height="22" rx="11" {}
                rect .swatch x="186" y="30" width="12" height="12" rx="3" {}
                text .hex .hex-rest x="204" y="36" { "#8F8A81" }
                text .hex .hex-live x="204" y="36" { "#E8502A" }
                rect .copy-back x="252" y="30" width="7" height="7" rx="1.5" {}
                rect .copy-front x="256" y="34" width="7" height="7" rx="1.5" {}
            }
        }
    }
}
