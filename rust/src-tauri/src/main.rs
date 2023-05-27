// Prevents additional console window on Windows in release, DO NOT REMOVE!!
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

mod service;

// Learn more about Tauri commands at https://tauri.app/v1/guides/features/command
#[tauri::command]
fn greet(name: &str) -> String {
    format!("Hello, {}! You've been greeted from Rust!", name)
}

fn main() {
    tauri::Builder::default()
        // 这一步通过 generate_handler! 宏生成了一个处理函数 greet 的调用处理器。
        .invoke_handler(tauri::generate_handler![greet, service::index])
        // 这一步使用 generate_context! 宏生成了一个 Tauri 上下文，并将其传递给 run 方法。Tauri 上下文包含了应用程序的配置信息和其他运行时上下文。通过这一步，Tauri 应用程序开始运行，并等待前端的事件和调用。
        .run(tauri::generate_context!())
        // 这一步用于处理 Tauri 应用程序运行时可能发生的错误。如果在运行过程中出现错误，程序将打印错误信息并退出。
        .expect("error while running tauri application");
}
