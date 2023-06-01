#[tauri::command]
pub fn index() -> String {
    format!("ok")
}
