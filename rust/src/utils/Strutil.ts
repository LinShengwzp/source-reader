/**
 * 压缩json并转字符串
 *
 * @param {Object} jsonObj 包含空白字符（\t、\n、\s）的json字符串
 */
export const compressJson = (jsonObj: Object): string => {
    return JSON.stringify({...jsonObj}, (key, value) => {
        const type = typeof value
        if (key === 'weight') {
            return value + ""
        }
        if (key === 'enable') {
            return key ? 1 : 0
        }
        return value
    }).replace(/\//g, '\\/')
        .replaceAll('\r', '')
        .replaceAll('\n', '')
        .replaceAll('\t', '')
        .replaceAll(': "', ':"');
}

/**
 * json对象中的某些对象成员转string并美化
 * @param obj
 * @param keys
 * @returns {*}
 */
export const stringifyJson = (obj: any, keys: string[]): object => {
    if (obj) {
        for (const key in obj) {
            obj[key] = keys.indexOf(key) >= 0 ? jsonStr(obj[key]) : obj[key]
        }
    }
    return obj
}

/**
 * 处理json内部的object
 * @param obj
 */
const jsonStr = (obj: any): any => {
    if (!obj) return ''
    const type = typeof obj
    switch (type) {
        case "function":
            return obj.toString();
        case "object":
            return JSON.stringify(obj, null, "\t");
        case "string":
            if (obj.indexOf('{\"') === 0) {
                return JSON.stringify(JSON.parse(obj), null, "\t")
            }
        default:
            return obj;
    }
}
