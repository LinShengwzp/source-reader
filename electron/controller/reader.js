'use strict';

const path = require('path');
const _ = require('lodash');
const {Controller} = require('ee-core');
const {
    app: electronApp,
} = require('electron');
const fs = require("fs");

class ReaderController extends Controller {
    constructor(ctx) {
        super(ctx);
    }

    /**
     * 请求错误
     * @param msg 错误消息
     * @param code 错误码
     * @param resData 错误结果
     * @returns {{result: {}, code: number, action: string, message: string}}
     */
    error(msg, code, resData) {
        return {
            code: code || 500,
            result: resData || {},
            message: msg || "failure"
        }
    }

    /**
     * 请求成功
     * @param resData 成功结果
     * @param msg 成功消息
     * @param code 响应码
     * @returns {{result: {}, code: number, action: string, message: string}}
     */
    success(resData, msg, code) {
        return {
            code: code || 200,
            result: resData || {},
            message: msg || "success"
        }
    }

    //<editor-fold desc="数据库操作">

    serv = this.service
    reader = this.serv.reader
    utils = this.serv.utils
    xbs = this.serv.xbsTools

    /**
     * 书源数据库操作
     * @param args
     * @returns {Promise<void>}
     */
    async bookSourceOperation(args) {
        return this.dataOperator('bookSource', args.action, args.data, args.cover)
    }

    /**
     * 书籍分组数据库操作
     * @param args
     * @returns {Promise<{result: {}, action, message: string}>}
     */
    async bookGroupOperation(args) {
        return this.dataOperator('bookGroup', args.action, args.data, args.cover)
    }

    /**
     * 书籍数据库操作
     * @param args
     * @returns {Promise<{result: {}, action, message: string}>}
     */
    async bookInfoOperation(args) {
        return this.dataOperator('bookInfo', args.action, args.data, args.cover)
    }

    /**
     * 数据库操作
     * @param tableName 数据库表
     * @param action 操作
     * @param data 数据项
     * @param cover (修改)是否覆盖
     * @returns {Promise<{result: {}, action, message: string}>}
     */
    async dataOperator(tableName, action, data, cover) {
        const {service} = this

        if (!action) {
            return this.error("error action")
        }
        if (service.utils.nullObj(data)) {
            return this.error("null data")
        }
        const reader = service.reader
        switch (action) {
            case 'add' :
                const res = await reader.addData(tableName, data, cover);
                return this.success(res.result, res.message)
            case 'del' :
                return this.success(await reader.delData(tableName, data))
            case 'update' :
                return this.success(await reader.modifyData(tableName, data))
            case 'get' :
                return this.success(await reader.queryData(tableName, data))
            case 'saveOrUpdate':
                const {result} = await reader.saveOrUpdate(tableName, data);
                return this.success(result)
            case 'getDataDir' :
                return this.success(await reader.getDataDir());
            case 'setDataDir' :
                return this.success(await reader.setCustomDataDir(data));
            default:
                return this.error(`error action: ${action}`)
        }
    }

    //</editor-fold>

    //<editor-fold desc="书源节点文件操作">

    /**
     *
     * @param args
     * @returns {Promise<void>}
     */
    async bookSourceFileSave(args) {
        const {config} = this;
        const {fileName, content} = args
        return new Promise((resolve, reject) => {
            if (!fileName || !content) {
                reject("None fileName or none content!")
            }
            const saveDir = path.join(config.homeDir, '/data/StandarReader/bookSource')
            if (!fs.existsSync(saveDir)) {
                fs.mkdirSync(saveDir, {
                    recursive: true
                })
            }
            const savePath = path.join(saveDir, fileName)
            this.writeFile({savePath: savePath, content: content})
                .then(res => resolve(`/data/StandarReader/bookSource/${fileName}`))
                .catch((e) => reject(e));
        })
    }


    /**
     * 打开书源文件并写入到数据库中
     * @param args
     * @returns {Promise<unknown>}
     */
    async bookSourceFileRead(args) {
        const {config} = this;
        const {filePath, cover, bufArr, hasSetCover} = args
        const realPath = path.join(filePath)
        try {
            const jsonUint8Array = this.xbs.XBS2Json(Buffer.from(bufArr))
            const nodeArr = this.xbs.uint8Array2JsonObj(jsonUint8Array)
            // 存储
            let addList = []
            for (const node in nodeArr) {
                const data = nodeArr[node]
                const dataItem = {}
                dataItem[node] = data
                const sourceJson = this.xbs.compressJson(dataItem);
                // 节点写入
                const res = await this.bookSourceOperation({
                    action: 'add',
                    cover: cover || false,
                    data: {
                        platform: 'StandarReader',
                        sourceName: data['sourceName'],
                        sourceType: data['sourceType'],
                        sourceUrl: data['sourceUrl'],
                        enable: data['enable'],
                        weight: data['weight'],
                        sourceJson: sourceJson,
                        authorId: data['authorId'],
                        desc: data['desc'],
                        lastModifyTime: data['lastModifyTime'],
                        toTop: data['toTop'],
                    }
                })
                if (res && res.message) {
                    switch (res.message) {
                        case 'success':
                        case 'cover':
                            addList.push({
                                id: res.result.id,
                                sourceName: node
                            })
                            break
                        case 'exist':
                            if (hasSetCover) {
                                addList.push({
                                    id: res.result.id,
                                    sourceName: node
                                })
                            } else {
                                return this.error(`已存在相同命名的节点[${node}]`, 'exist')
                            }
                            break
                        default:
                            return this.error(`节点保存失败[${node}]`, res.message)
                    }
                } else {
                    return this.error(`节点保存失败[${node}]`, 'error')
                }
            }
            return this.success(addList, '文件解析成功', 'success')
        } catch (e) {
            return this.error(e.message)
        }
    }

    //</editor-fold>

    /**
     * 搜索书籍
     * @param args
     * @returns {Promise<void>}
     */
    async searchBook(args) {
        const {service} = this

        if (service.utils.nullObj(args)) {
            return this.error("null data")
        }

        const {type, search, platform, page} = args
        if (!type || !search || !platform) {
            return this.error("error search params")
        }
        const sourcePage = {
            ...{
                index: 1, //从 第 1 页 开始
                size: 10,
            }, ...page
        }

        const reader = service.reader

        return new Promise(async (resolve, reject) => {
            let searchResult = []
            let pageInfo = {...sourcePage}
            switch (platform) {
                case 'StandarReader': {
                    //
                    // 获取所有的符合条件的源
                    const sourceList = await reader.queryData('bookSource', {
                        platform: 'StandarReader',
                        sourceType: type,
                        enable: 1,
                        page: sourcePage
                    })
                    // 获取count
                    const count = await reader.queryData('bookSource', {
                        id: {
                            query: true,
                        },
                        platform: {
                            query: false,
                            data: 'StandarReader',
                        },
                        sourceType: {
                            query: false,
                            data: type
                        },
                        enable: {
                            query: false,
                            data: 1
                        },
                        page: {
                            close: true
                        }
                    })
                    pageInfo.count = count.length
                    if (sourceList && sourceList.length > 0) {
                        // 处理源
                        for (const sourceIndex in sourceList) {
                            const source = sourceList[sourceIndex]
                            if (source.hasOwnProperty('sourceJson')) {
                                const sourceJson = JSON.parse(source['sourceJson'])
                                console.log(`source node [${source.sourceName}] search for keyword [${search}] `)
                                try {
                                    const res = await this.xbs.searchBook(sourceJson, search, type || "text")
                                    if (res && res.result) {
                                        if (res.result.list) {
                                            console.log(`source node [${source.sourceName}] search for keyword [${search}] success: count [${res.result.list.length}] `)
                                            searchResult.push({
                                                code: 200,
                                                sourceId: source.id,
                                                sourceName: source.sourceName,
                                                result: res.result.list,
                                            })
                                        } else {
                                            searchResult.push({
                                                code: 200,
                                                sourceId: source.id,
                                                sourceName: source.sourceName,
                                                result: [],
                                            })
                                        }
                                    }
                                } catch (e) {
                                    console.error(`source node [${source.sourceName}] search for keyword [${search}] failure: [${e}] `)
                                    searchResult.push({
                                        code: 500,
                                        error: e,
                                        sourceId: source.id,
                                        sourceName: source.sourceName,
                                        result: [],
                                    })
                                }
                            }
                        }
                    }
                    break
                }
            }
            resolve({
                page: pageInfo,
                result: searchResult
            })
        })

    }

    //<editor-fold desc="文件操作">
    readFile(args) {
        const {filePath, encoding, flags} = args
        return new Promise((resolve, reject) => {
            if (!filePath) {
                reject("None filePath!")
            }

            if (!fs.existsSync(filePath)) {
                reject(`file [${filePath}] doesn't exist!`)
            }

            fs.readFile(filePath, {
                encoding: encoding || 'utf-8',
                flag: flags || 'r'
            }, (err, data) => {
                if (err) {
                    reject(err)
                }
                resolve(data)
            })
        })
    }

    /**
     * 存储写入文件
     * @param args
     * @returns {Promise<unknown>}
     */
    writeFile(args) {
        const {savePath, content, encoding} = args
        return new Promise((resolve, reject) => {
            if (!savePath || !content) {
                reject("None fileName or none content!")
            }
            let wstream = fs.createWriteStream(savePath);
            wstream.write(content);
            wstream.end();
            wstream.on('finish', function () {
                resolve(savePath)
            });
            wstream.on('error', function (err) {
                reject(err)
            });
        })
    }

    //</editor-fold>

}

ReaderController.toString = () => '[class ReaderController]';
module.exports = ReaderController;
