#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

#[tauri::command]
fn toggle_fullscreen(window: tauri::Window) -> Result<(), String> {
    let is_fs = window.is_fullscreen().map_err(|e| e.to_string())?;
    window.set_fullscreen(!is_fs).map_err(|e| e.to_string())?;
    Ok(())
}

fn main() {
    tauri::Builder::default()
        .invoke_handler(tauri::generate_handler![toggle_fullscreen])
        .setup(|_app| Ok(()))
        .run(tauri::generate_context!())
        .expect("error while running RGC-BASIC launcher");
}
