//! Decorative illustrations for the home page bento tiles.
//!
//! SVG shapes need an explicit empty body (`rect {}`, not `rect;`): maud only
//! omits the closing tag for known HTML void elements, and an unclosed `<rect>`
//! makes the HTML parser nest the rest of the drawing inside it.

use std::time::{SystemTime, UNIX_EPOCH};

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

/// The hero demo: one capture, start to clipboard, as a CSS loop over a fake Mac.
///
/// Every element here is static markup; the stylesheet's `@keyframes` own the motion,
/// so removing them (reduced motion) leaves a composed poster. The card holds a copy
/// of the desktop scaled to the selection, which is why the window markup appears
/// twice: the thumbnail has to be the region the drag cut out, not an approximation.
pub fn hero_demo() -> Markup {
    html! {
        figure .shot {
            div .demo role="img"
                aria-label="Pressing Command Shift A dims the screen, a rectangle is dragged over a window, and the shot lands on the clipboard with a small preview card." {

                div .demo-wallpaper {}

                div .demo-menubar {
                    div .demo-menubar-side {
                        svg .demo-apple viewBox="0 0 24 24" aria-hidden="true" {
                            path d="M12.152 6.896c-.948 0-2.415-1.078-3.96-1.04-2.04.027-3.91 1.183-4.961 3.014-2.117 3.675-.546 9.103 1.519 12.09 1.013 1.454 2.208 3.09 3.792 3.039 1.52-.065 2.09-.987 3.935-.987 1.831 0 2.35.987 3.96.948 1.637-.026 2.676-1.48 3.676-2.948 1.156-1.688 1.636-3.325 1.662-3.415-.039-.013-3.182-1.221-3.22-4.857-.026-3.04 2.48-4.494 2.597-4.559-1.429-2.09-3.623-2.324-4.39-2.376-2-.156-3.675 1.09-4.61 1.09zM15.53 3.83c.843-1.012 1.4-2.427 1.245-3.83-1.207.052-2.662.805-3.532 1.818-.78.896-1.454 2.338-1.273 3.714 1.338.104 2.715-.688 3.559-1.701" {}
                        }
                        span .demo-menu-app { "Notes" }
                        span .demo-menu-item { "File" }
                        span .demo-menu-item { "Edit" }
                        span .demo-menu-item { "View" }
                        span .demo-menu-item { "Window" }
                        span .demo-menu-item { "Help" }
                    }
                    div .demo-menubar-side .demo-menubar-status {
                        svg .demo-mark viewBox="100 100 824 824" aria-hidden="true" {
                            path d="M 267.38 421.88 L 267.38 267.38 L 421.88 267.38" {}
                            path d="M 602.12 267.38 L 756.62 267.38 L 756.62 421.88" {}
                            path d="M 756.62 602.12 L 756.62 756.62 L 602.12 756.62" {}
                            path d="M 421.88 756.62 L 267.38 756.62 L 267.38 602.12" {}
                            path d="M 402.56 402.56 L 621.44 621.44" {}
                        }
                        span .demo-clock { (server_clock(SystemTime::now())) }
                    }
                }

                (window())

                div .demo-card {
                    div .demo-thumb {
                        div .demo-screen {
                            div .demo-wallpaper {}
                            (window())
                        }
                    }
                    div .demo-card-actions { i {} i {} i {} }
                }

                div .demo-dim {
                    i .l {} i .t {} i .r {} i .b {}
                }

                div .demo-cutout {
                    div .demo-edges {
                        i .et {} i .el {} i .er {} i .eb {}
                    }
                    div .demo-brackets {
                        span .bw .tl { svg viewBox="0 0 12 12" aria-hidden="true" { path d="M 1 9 L 1 1 L 9 1" {} } }
                        span .bw .tr { svg viewBox="0 0 12 12" aria-hidden="true" { path d="M 3 1 L 11 1 L 11 9" {} } }
                        span .bw .br { svg viewBox="0 0 12 12" aria-hidden="true" { path d="M 11 3 L 11 11 L 3 11" {} } }
                        span .bw .bl { svg viewBox="0 0 12 12" aria-hidden="true" { path d="M 9 11 L 1 11 L 1 3" {} } }
                    }
                    span .demo-size {}
                }

                div .demo-pointer {
                    div .demo-hand {
                        div .demo-guides {
                            i .demo-guide-h {}
                            i .demo-guide-v {}
                        }
                        svg .demo-arrow viewBox="0 0 12 16" aria-hidden="true" {
                            path d="M 1 1 L 1 13 L 4.3 10.3 L 6.6 15.2 L 8.8 14.2 L 6.6 9.6 L 11 9.6 Z" {}
                        }
                        svg .demo-crosshair viewBox="0 0 16 16" aria-hidden="true" {
                            path .halo d="M 8 0 V 5.5 M 8 10.5 V 16 M 0 8 H 5.5 M 10.5 8 H 16" {}
                            path d="M 8 0 V 5.5 M 8 10.5 V 16 M 0 8 H 5.5 M 10.5 8 H 16" {}
                        }
                    }
                }

                div .demo-narrator {
                    div .demo-keycaps {
                        kbd { "\u{2318}" }
                        kbd { "\u{21e7}" }
                        kbd { "A" }
                    }
                    div .demo-copied {
                        svg viewBox="44 15 30 38" aria-hidden="true" {
                            rect .board x="46" y="20" width="26" height="32" rx="4" {}
                            rect .tab x="53" y="17" width="12" height="6" rx="2" {}
                            path .check d="M 53 45 L 57 49 L 65 42" {}
                        }
                        span { "Copied" }
                    }
                }
            }
        }
    }
}

/// The desktop's one window, drawn twice: once on the desktop and once inside the
/// preview card, where it is scaled down to the region the selection cut out.
fn window() -> Markup {
    html! {
        div .demo-window {
            div .demo-lights { i .close {} i .minimise {} i .zoom {} }
            div .demo-sidebar {
                div .demo-sidebar-title { "Field notes" }
                ul .demo-sidebar-list {
                    li { "Overview" }
                    li .is-selected { "Capture" }
                    li { "Editor" }
                    li { "Export" }
                }
            }
            div .demo-pane {
                div .demo-toolbar {}
                article .demo-note {
                    h2 { "A quieter workspace" }
                    p .demo-note-meta { "Design notes / September 2026" }
                    section { h3 { "Capture what matters" } p { "Simple controls, thoughtful spacing, room to work." } }
                    section { h3 { "Keep the image in focus" } p { "Simple controls, thoughtful spacing, room to work." } }
                    section { h3 { "Make every action clear" } p { "Simple controls, thoughtful spacing, room to work." } }
                }
            }
        }
    }
}

/// The menu bar clock as the server sees it, in UTC, formatted the way macOS does.
/// `clock.js` replaces it with the visitor's own local time; this is the fallback a
/// reader without JavaScript sees, and the pages re-render every half hour.
fn server_clock(now: SystemTime) -> String {
    const WEEKDAYS: [&str; 7] = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
    const MONTHS: [&str; 12] = [
        "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
    ];

    let seconds = now
        .duration_since(UNIX_EPOCH)
        .map(|elapsed| elapsed.as_secs() as i64)
        .unwrap_or(0);
    let days = seconds.div_euclid(86_400);
    let time_of_day = seconds.rem_euclid(86_400);

    let (_, month, day) = civil_from_days(days);
    // 1 January 1970 was a Thursday.
    let weekday = (days + 4).rem_euclid(7) as usize;

    format!(
        "{} {} {}\u{2002}{:02}:{:02}",
        WEEKDAYS[weekday],
        day,
        MONTHS[(month - 1) as usize],
        time_of_day / 3600,
        (time_of_day % 3600) / 60,
    )
}

/// Days since the Unix epoch to a civil year, month and day. Howard Hinnant's
/// algorithm, which is exact for the whole proleptic Gregorian calendar.
fn civil_from_days(days: i64) -> (i64, u32, u32) {
    let shifted = days + 719_468;
    let era = shifted.div_euclid(146_097);
    let day_of_era = shifted.rem_euclid(146_097);
    let year_of_era =
        (day_of_era - day_of_era / 1460 + day_of_era / 36_524 - day_of_era / 146_096) / 365;
    let year = year_of_era + era * 400;
    let day_of_year = day_of_era - (365 * year_of_era + year_of_era / 4 - year_of_era / 100);
    let month_position = (5 * day_of_year + 2) / 153;
    let day = (day_of_year - (153 * month_position + 2) / 5 + 1) as u32;
    let month = if month_position < 10 {
        month_position + 3
    } else {
        month_position - 9
    } as u32;

    (year + i64::from(month <= 2), month, day)
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::time::Duration;

    fn at(seconds: u64) -> String {
        server_clock(UNIX_EPOCH + Duration::from_secs(seconds))
    }

    #[test]
    fn formats_the_clock_like_the_menu_bar() {
        // 1 January 1970 was a Thursday.
        assert_eq!(at(0), "Thu 1 Jan\u{2002}00:00");
        // 19 September 2026, 09:41 UTC
        assert_eq!(at(1_789_810_860), "Sat 19 Sep\u{2002}09:41");
    }

    #[test]
    fn handles_leap_days() {
        // 29 February 2024, 23:59 UTC
        assert_eq!(at(1_709_251_140), "Thu 29 Feb\u{2002}23:59");
    }
}
