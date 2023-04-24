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
     * 书源数据库操作
     * @param args
     * @returns {Promise<void>}
     */
    async bookSourceOperation(args) {
        const {service} = this;
        const paramsObj = args;
        const data = {
            action: paramsObj.action,
            result: null,
            all_list: []
        }
        const tableName = 'bookSource'
        switch (paramsObj.action) {
            case 'add' :
                data.result = await service.reader.addData(tableName, paramsObj.data);
                break;
            case 'del' :
                data.result = await service.reader.delData(tableName, paramsObj.data);
                break;
            case 'update' :
                data.result = await service.reader.modifyData(tableName, paramsObj.data);
                break;
            case 'get' :
                data.result = await service.reader.queryData(tableName, paramsObj.data);
                break;
            case 'saveOrUpdate':
                data.result = await service.reader.saveOrUpdate(tableName, paramsObj.data);
                break;
            case 'getDataDir' :
                data.result = await service.reader.getDataDir();
                break;
            case 'setDataDir' :
                data.result = await service.reader.setCustomDataDir(paramsObj.data_dir);
                break;
        }

        return data;
    }

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

    async bookSourceFileRead(args) {
        const {config} = this;
        const {filePath} = args
        return new Promise((resolve, reject) => {
            if (!filePath) {
                reject("None filePath!")
            }
            const fileAbstractPath = path.join(config.homeDir, filePath)
            this.readFile({
                filePath: fileAbstractPath
            }).then((res) => resolve(res)).catch((e) => reject(e))
        })
    }

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
                flag: flags|| 'r'
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

}

ReaderController.toString = () => '[class ReaderController]';
module.exports = ReaderController;
