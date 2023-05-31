import {invoke} from "@tauri-apps/api/tauri";
import {db} from "@/utils/storage/Sqlite";

export const service = async () => {
    const res = await invoke("")
}

export async function greet() {
    // Learn more about Tauri commands at https://tauri.app/v1/guides/features/command
    const res = await invoke("greet", {name: "2333"});
    console.log(res, db.path)
    return res
}
