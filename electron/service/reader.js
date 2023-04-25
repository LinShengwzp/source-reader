'use strict';

const {Service} = require('ee-core');
const Storage = require('ee-core/storage');
const _ = require('lodash');
const path = require('path');

/**
 * 阅读相关
 */
class ReaderSourceStorageService extends Service {
    sqliteFile = ""
    demoSqliteDB = {}
    tableEntity = {
        bookSource: {
            id: {
                type: 'INTEGER',
                pk: true,
                notNull: true,
                autoIncrement: true,
                comment: '书源主键'
            },
            platform: {
                type: 'TEXT',
                notNull: true,
                comment: '书源平台'
            },
            sourceName: {
                type: 'TEXT',
                notNull: true,
                comment: '书源名称'
            },
            sourceType: {
                type: 'TEXT',
                comment: '书源类型'
            },
            sourceUrl: {
                type: 'TEXT',
                comment: '书源类型'
            },
            enable: {
                type: 'INT',
                default: 1,
                comment: '书源类型'
            },
            weight: {
                type: 'int',
                default: 1000,
                comment: '书源类型'
            },
            sourceJson: {
                type: 'TEXT',
                notNull: true,
                comment: '书源JSON文件位置'
            },
            authorId: {
                type: 'TEXT',
                comment: '作者'
            },
            desc: {
                type: 'TEXT',
                comment: '描述'
            },
            lastModifyTime: {
                type: 'TEXT',
                comment: '最后更新时间'
            },
            toTop: {
                type: 'TEXT',
                comment: '距离上一次'
            },
        }
    }

    constructor(ctx) {
        super(ctx);

        // 使用sqlite数据库
        this.sqliteFile = './reader.db';
        let sqliteOptions = {
            driver: 'sqlite',
            default: {
                timeout: 6000,
                verbose: console.log // 打印sql语法
            }
        }
        this.readerSqliteDB = Storage.connection(this.sqliteFile, sqliteOptions);

        // 检查实体表
        for (const tableName in this.tableEntity) {
            this.checkAndCreateTableSqlite(tableName, this.tableEntity[tableName]);
        }
    }

    /*
     * 检查并创建表 (sqlite)
     */
    async checkAndCreateTableSqlite(tableName = '') {
        if (_.isEmpty(tableName)) {
            throw new Error(`table name is required`);
        }
        // 检查表是否存在
        const tableExist = this.readerSqliteDB.db.prepare('SELECT * FROM sqlite_master WHERE type=? AND name = ?');
        const result = tableExist.get('table', tableName);
        const entity = this.tableEntity[tableName]
        //console.log('result:', result);
        if (result) {
            return entity;
        }

        if (!entity) {
            throw new Error(`Table Entity is required to create table`);
        }
        const buildColumns = () => {
            let cols = []
            for (const col in entity) {
                const column = entity[col]
                cols.push(`${col} ${column['type']} ${column['notNull'] ? 'not null' : ''} ${column['pk'] ? 'primary key' : ''} ${column['autoIncrement'] ? 'autoincrement' : ''} ${column['default'] ? `default '${column['default']}'` : ''}`)
            }
            return cols.join(',\n');
        }
        const createSql =
            `create table ${tableName}
             (
                 ${buildColumns()}
             )`
        console.log('execute sql to create table', createSql)
        this.readerSqliteDB.db.exec(createSql);
        return entity;
    }

    /**
     * 构建查询条件
     *
     * {
     *     columnName1: {
     *         comp: '=/like/>/<',
     *         sort: 'asc/desc',
     *         data: '123',
     *         query: true // 有数据即可
     *     }
     *     columnName2: '122',
     *     page: {
     *         index: 1, //从 第 1 页 开始
     *         size: 50,
     *     }
     * }
     *
     * @param entity 实体表
     * @param data 查询条件
     * @returns {string}
     */
    buildQuery = (entity, data) => {
        let cols = []
        let queryCols = []
        let sort = []
        let pageInfo = {
            index: 1,
            size: 50,
            close: false
        }

        for (const col in data) {
            if (entity[col]) {
                // 处理列
                const item = data[col]

                if (!item) {
                    continue
                }

                // 处理查询方式
                let comp = item['comp'];
                let dataSort = item['sort'];
                let query = item['query'];

                let needWhereData = true
                // 这里需要判断列里面是否包含内容，比如只有一个 query，表示查询所有数据，但是只需要这个列
                if (query) {
                    queryCols.push(col)

                    if (!item['data']) {
                        // 查询这个列和排序等，但是没有where匹配
                        needWhereData = false
                    }
                }

                let itemObj = {
                    cloumn: col,
                };
                if (needWhereData) {
                    // 如果没有设置查询方式、排序、查询列等情况
                    itemObj.data = item['data'] ? item['data'] : data[col];
                    itemObj.comp = comp ? comp : "=" // 比较方式 = > < like 等
                    switch (itemObj.comp) {
                        case 'like':
                            itemObj.data = `%${itemObj.data}%`;
                            break
                        case 'leftLike':
                            itemObj.data = `%${itemObj.data}`;
                            break
                        case 'rightLike':
                            itemObj.data = `${itemObj.data}%`;
                            break
                        case 'between':
                            let range = itemObj.data.split(',');
                            if (range && range.length === 2) {
                                itemObj.data = `${range[0]} and ${range[1]}`
                            } else {
                                throw new Error(`Query Between need a min and max range`);
                            }
                            break
                    }
                    cols.push(itemObj)
                }

                // 排序
                if (dataSort) {
                    switch (dataSort) {
                        case 'asc':
                        case 'desc':
                            sort.push({
                                cloumn: col,
                                order: dataSort
                            });
                            break
                        default:
                            sort.push({
                                cloumn: col,
                                order: 'asc'
                            });
                            break
                    }
                }
            }
        }
        const where = cols.map(i => ` ${i.cloumn} ${i.comp} @${i.cloumn} `).join(" and ");
        const order = sort.map(i => ` ${i.cloumn} ${i.order} `).join(' and ')
        let whereData = {}
        cols.forEach(col => {
            whereData[col.cloumn] = col.data
        })
        let page = data['page'];
        if (page) {
            pageInfo = {...pageInfo, ...page}
        }
        return {
            cols: (queryCols && queryCols.length > 0) ? queryCols.join(',') : "*",
            where: ` ${where ? ` where ${where}` : ''}`,
            sort: ` ${order ? ` order by ${order}` : ''}`,
            page: pageInfo.close ? '' : ` limit ${(pageInfo.index - 1) * (pageInfo.size)}, ${pageInfo.size} `,
            data: whereData
        }
    }

    /**
     * 插入数据
     * @param tableName 表名
     * @param data 数据
     * @param cover 写入覆盖
     * @returns {Promise<void>}
     */
    async addData(tableName, data, cover) {
        const entity = await this.checkAndCreateTableSqlite(tableName);
        // 检查是否有重复的数据
        const exist = await this.queryOne(tableName, {
            sourceName: data.sourceName
        })

        if (exist) {
            if (cover) {
                // 利用data覆盖exist
                const merge = {...exist, ...data}
                return {
                    result: await this.modifyData(tableName, merge),
                    message: 'cover'
                }
            }
            return {
                result: exist,
                message: 'exist'
            }
        }

        delete data['id']

        let pk = ''
        const buildColumns = () => {
            let cols = []

            for (const col in entity) {
                if (entity[col].pk) {
                    pk = col
                    break
                }
            }

            for (const col in data) {
                if (entity[col]) {
                    if (!(typeof data[col] === 'undefined')) {

                        if (typeof data[col] === 'boolean') {
                            data[col] = data[col] ? 1 : 0
                        }

                        cols.push(col)
                    }
                }
            }

            if (cols && cols.length >= 0) {
                return ` (${cols.join(',')}) values (${cols.map(i => `@${i}`).join(',')}) `
            } else {
                throw new Error(`Please provide the correct data`);
            }
        }

        let sql = `INSERT INTO ${tableName} ${buildColumns()}`;
        const insert = this.readerSqliteDB.db.prepare(sql);
        try {
            let run = insert.run(data);
            if (run && run['lastInsertRowid']) {
                data[pk] = run['lastInsertRowid']
                return {
                    result: data,
                    message: 'success'
                }
            }
        } catch (e) {
            throw e
        }
        throw new Error("insert data error")
    }

    /**
     * 新增或者修改数据
     * @param tableName
     * @param data
     */
    async saveOrUpdate(tableName, data) {
        const entity = await this.checkAndCreateTableSqlite(tableName);

        return this.addData(tableName, data, true)

    }

    /**
     * 根据主键修改
     * @param tableName 表名
     * @param data 数据
     * @returns {Promise<boolean>}
     */
    async modifyData(tableName, data) {
        const entity = await this.checkAndCreateTableSqlite(tableName);
        let pkCol = ''
        const buildColumns = () => {
            let cols = []
            for (const col in data) {
                if (typeof data[col] === 'undefined') {
                    data[col] = null
                }
                if (entity[col]) {
                    if (entity[col].pk) {
                        pkCol = col
                    } else {
                        cols.push(col)
                    }

                    if (typeof data[col] === 'boolean') {
                        data[col] = data[col] ? 1 : 0
                    }

                }
            }

            if (cols && cols.length >= 0 && pkCol) {
                return ` set ${cols.map(i => ` ${i} = @${i} `).join(',')} where ${pkCol} = @${pkCol} `
            } else {
                throw new Error(`Please provide the correct data`);
            }
        }

        let sql = `UPDATE ${tableName} ${buildColumns()}`;
        const update = this.readerSqliteDB.db.prepare(sql);
        let run = update.run(data);
        if (run && run.changes > 0) {
            return data;
        }
    }

    /**
     * 删除数据
     * @param tableName 表名
     * @param data 数据条件
     * @returns {Promise<void>}
     */
    async delData(tableName, data) {
        const entity = await this.checkAndCreateTableSqlite(tableName);
        let querySql = this.buildQuery(entity, data);
        let sql = `DELETE
                   FROM ${tableName} ${querySql.where}`;
        const del = this.readerSqliteDB.db.prepare(sql);
        del.run(querySql.data);
    }

    /**
     * 查询数据
     * @param tableName 表名
     * @param data 数据条件
     * @returns {Promise<void>}
     */
    async queryData(tableName, data) {
        const entity = await this.checkAndCreateTableSqlite(tableName);
        let querySql = this.buildQuery(entity, data);
        let sql = `SELECT ${querySql.cols}
                   FROM ${tableName} ${querySql.where} ${querySql.sort} ${querySql.page} `;
        const query = this.readerSqliteDB.db.prepare(sql)
        return query.all(querySql.data)
    }

    /**
     * 查询数据
     * @param tableName 表名
     * @param data 数据条件
     * @returns {Promise<void>}
     */
    async queryOne(tableName, data) {
        const array = await this.queryData(tableName, data)
        if (array && array.length === 1) {
            return array[0]
        }
        return null
    }

    /**
     * 获取db数据路径
     * @returns {Promise<*>}
     */
    async getDataDir() {
        const dir = this.readerSqliteDB.getStorageDir();

        return dir;
    }

    /**
     * 设置db路径
     * @param dir
     * @returns {Promise<void>}
     */
    async setCustomDataDir(dir) {
        if (_.isEmpty(dir)) {
            return;
        }

        // the absolute path of the db file
        const dbFile = path.join(dir, this.sqliteFile);
        const sqliteOptions = {
            driver: 'sqlite',
            default: {
                timeout: 6000,
                verbose: console.log
            }
        }
        this.readerSqliteDB = Storage.connection(dbFile, sqliteOptions);

        return;
    }
}

ReaderSourceStorageService.toString = () => '[class ReaderSourceStorageService]';

module.exports = ReaderSourceStorageService;
