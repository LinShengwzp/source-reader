import {invoke} from "@tauri-apps/api/tauri";
import {create} from "@/utils/storage/Sqlite";
import {getTable} from "@/utils/storage/Table";

export const service = async () => {
    const res = await invoke("")
}

export async function greet() {
    // Learn more about Tauri commands at https://tauri.app/v1/guides/features/command
    // const res = await invoke("greet", {name: "2333"});
    // console.log(res, create(getTable('bookInfo')))
    // return res
}
