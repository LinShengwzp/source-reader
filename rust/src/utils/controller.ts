import {invoke} from "@tauri-apps/api/tauri";

export const service = async () => {
    const res = await invoke("")
}

async function greet() {
    // Learn more about Tauri commands at https://tauri.app/v1/guides/features/command
    const res = await invoke("greet", {name: "2333"});
}
