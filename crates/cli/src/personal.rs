//! Defaults compiled into this checkout's personal app and engine.
//! Run before creating threads or parsing any command line.

pub const ENABLED: bool = option_env!("ZERON_PERSONAL_BUILD").is_some();
pub const BUNDLE_ID: &str = "sh.zeron.app.personal";
pub const IPC_PORT: &str = "49778";

pub fn initialize() {
    if !ENABLED {
        return;
    }
    let home = std::env::var_os("HOME").expect("HOME is required by Zeron Personal");
    let data = std::path::PathBuf::from(home).join(".zeron-personal");
    // Always select the personal profile, even when launched from a shell or
    // agent that inherited the official app's ZERON_* environment.
    // SAFETY: both executable entry points call this before starting threads.
    unsafe {
        std::env::set_var("ZERON_DATA_DIR", data);
        std::env::set_var("ZERON_IPC_PORT", IPC_PORT);
        std::env::set_var("ZERON_AUTO_UPDATE", "0");
        std::env::remove_var("ZERON_INSTALLED_AT");
    }
}
