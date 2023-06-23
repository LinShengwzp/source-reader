/**
 * json转字符串并压缩
 *
 * @param {Object} jsonObj 包含空白字符（\t、\n、\s）的json字符串
 */
export const compressJson = (jsonObj: Object): string => {
    return parseJsonDeepToString(jsonObj, ['httpHeaders', 'moreKeys'])
        .replace(/\//g, '\\/')
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
 * 将其中几个成员还原成string
 * @param obj
 * @param keys
 * @returns {*}
 */
export const parseJson = (obj: any, keys: string[] = ['httpHeaders', 'moreKeys']): object => {
    if (obj) {
        for (const key in obj) {
            if (keys.indexOf(key) >= 0) {
                try {
                    const type = typeof obj[key]
                    if (type === 'string') {
                        if (obj[key]) {
                            obj[key] = JSON.parse(obj[key])
                        } else {
                            delete obj[key]
                        }
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
 * 处理整个json，转string
 * @param obj
 * @param keys
 */
export const parseJsonDeepToString = (obj: any, keys: string[]): string => {
    if (obj) {
        return JSON.stringify({...obj}, (key, value) => {
            // 处理两个问题
            if (key === 'weight') {
                value = value + ""
            }
            if (key === 'enable') {
                value = key ? 1 : 0
            }
            // 处理本该是 object的 string
            if (keys.indexOf(key) >= 0) {
                // 单独照看
                if (typeof value === 'string') {
                    // console.error(`current value [${value}] of key [${key}] must be an object rather then a string`)
                    value = JSON.parse(value)
                }
            }
            return value
        }, 2)
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
