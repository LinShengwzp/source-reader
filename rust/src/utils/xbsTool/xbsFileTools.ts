import {Buffer} from 'buffer';
// @ts-ignore
import {XBS2Json, Json2XBS, byteTools} from "./xbsTools";


export const analyseXbsFile = async (file?: File): Promise<Object> => {
    return new Promise((resolve, reject) => {
        if (!file) {
            reject(new Error("empty file"))
        }
        const reader = new FileReader();
        reader.readAsArrayBuffer((file as any));
        reader.onload = (e: ProgressEvent<FileReader>) => {
            if (!e || !e.currentTarget || !(e.currentTarget as any).result) {
                reject(new Error("open file failure"))
            }
            try { //获取数据
                const res = XBS2Json(Buffer.from((e.currentTarget as any).result));
                const data = byteTools.uint8Array2JsonObj(res)
                // 存储
                resolve(data)
            } catch (e) {
                reject(new Error(`analyse file failure: ${e}`))
            }
        }
        reader.onerror = (e) => {
            reject(new Error(`analyse file failure: ${e}`))
        }
    })

}

export const analyseJsonFile = (file?: File) => {

}
