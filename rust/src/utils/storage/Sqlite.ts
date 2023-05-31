import Database from "tauri-plugin-sql-api";
import {DataTable} from "@/utils/Models";
import {tables} from "@/utils/storage/Table";

// sqlite. The path is relative to `tauri::api::path::BaseDirectory::App`.
const db: Database = await Database.load("sqlite:reader.db");
// mysql
// const db = await Database.load("mysql://user:pass@host/database");
// postgres
// const db = await Database.load("postgres://postgres:password@localhost/test");


export const checkAndCreateTableSqlite = async (tableName: string): Promise<DataTable> => {
    if (!tableName) {
        throw new Error(`table name is required`);
    }
    // 检查表是否存在
    const tableExist = await db.select(
        'SELECT * FROM sqlite_master WHERE type=$1 AND name = $2',
        ["table", tableName]);
    console.log(tableName, tableExist, "你是个啥？？？")
    return tables['bookInfo'];
}
