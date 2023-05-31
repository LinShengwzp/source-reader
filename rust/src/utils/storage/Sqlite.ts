import Database from "tauri-plugin-sql-api";

// sqlite. The path is relative to `tauri::api::path::BaseDirectory::App`.
export const db:Database = await Database.load("sqlite:test2333.db");
// mysql
// const db = await Database.load("mysql://user:pass@host/database");
// postgres
// const db = await Database.load("postgres://postgres:password@localhost/test");

