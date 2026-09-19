use std::collections::hash_map::DefaultHasher;
use std::hash::{Hash, Hasher};

pub const STYLESHEET: &str = include_str!("../static/style.css");
pub const LOGO: &[u8] = include_bytes!("../static/snimach-mark.svg");
pub const SCREENSHOT: &[u8] = include_bytes!("../static/snimach.webp");
pub const OG_IMAGE: &[u8] = include_bytes!("../static/og.png");
pub const WALLPAPER_LIGHT: &[u8] = include_bytes!("../static/wallpaper-light.webp");
pub const WALLPAPER_DARK: &[u8] = include_bytes!("../static/wallpaper-dark.webp");
pub const CLOCK_SCRIPT: &str = include_str!("../static/clock.js");

pub const LOGO_PATH: &str = "/snimach-mark.svg";
pub const SCREENSHOT_PATH: &str = "/snimach.webp";
pub const STYLESHEET_PATH: &str = "/style.css";
pub const OG_IMAGE_PATH: &str = "/og.png";
pub const CLOCK_SCRIPT_PATH: &str = "/clock.js";

/// The hero demo's desktop. Referenced from the stylesheet rather than the markup,
/// so the URL carries no fingerprint: a new wallpaper needs a new filename.
pub const WALLPAPER_LIGHT_PATH: &str = "/wallpaper-light.webp";
pub const WALLPAPER_DARK_PATH: &str = "/wallpaper-dark.webp";

/// Cache-busting token derived from the embedded assets. Asset URLs carry it as
/// `?v=`, so the files can be served as immutable while a new deployment busts
/// the cache automatically.
pub struct Fingerprint(u64);

impl Fingerprint {
    pub fn new() -> Self {
        let mut hasher = DefaultHasher::new();
        for asset in [
            STYLESHEET.as_bytes(),
            CLOCK_SCRIPT.as_bytes(),
            LOGO,
            SCREENSHOT,
            OG_IMAGE,
            WALLPAPER_LIGHT,
            WALLPAPER_DARK,
        ] {
            asset.hash(&mut hasher);
        }
        Self(hasher.finish())
    }

    pub fn url(&self, path: &str) -> String {
        format!("{path}?v={:016x}", self.0)
    }
}
