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
