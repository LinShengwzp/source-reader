use crate::model::ApiOperate;

#[tauri::command]
pub fn index() -> String {
    format!("ok")
}

#[tauri::command]
pub fn operate(operate: ApiOperate<String>) -> String {
    format!("ok")
}
