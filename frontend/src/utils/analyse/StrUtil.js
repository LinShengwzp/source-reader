const jsonStr = (obj) => {
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

/**
 * json对象中的某些对象成员转string并美化
 * @param obj
 * @param keys
 * @returns {*}
 */
const stringifyJson = (obj, keys) => {
    if (obj) {
        for (const key in obj) {
            obj[key] = keys.indexOf(key) >= 0 ? jsonStr(obj[key]) : obj[key]
        }
    }
    return obj
}

/**
 * 将其中几个成员还原成string
 * @param obj
 * @param keys
 * @returns {*}
 */
const parseJson = (obj, keys) => {
    if (obj) {
        for (const key in obj) {
            if (keys.indexOf(key) >= 0) {
                try {
                    const type = typeof obj[key]
                    if (type === 'string') {
                        obj[key] = JSON.parse(obj[key])
                    }
                } catch (e) {
                    throw new Error(`请提供正确的json格式: [${key}]`)
                }
            } else {
                obj[key] = obj[key]
            }
        }
    }
    return obj
}

/**
 * 压缩json并转字符串
 *
 * @param {Object} jsonStr 包含空白字符（\t、\n、\s）的json字符串
 */
const compressJson = (jsonStr) => {
    let s = JSON.stringify({...jsonStr}, (key, value) => {
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
    return s
}

const formatJsonStr = (json) => {
    return JSON.stringify(json, null, "\t");
}

export {
    jsonStr,
    compressJson,
    formatJsonStr,
    stringifyJson,
    parseJson
}
