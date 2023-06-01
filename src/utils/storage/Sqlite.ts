import Database from "tauri-plugin-sql-api";
import {ColQueryInfo, DataColQueryInfo, DataTable, TableColumnInfo} from "@/utils/Models";

// sqlite. The path is relative to `tauri::api::path::BaseDirectory::App`.
const db: Database = await Database.load("sqlite:reader.db");
// mysql
// const db = await Database.load("mysql://user:pass@host/database");
// postgres
// const db = await Database.load("postgres://postgres:password@localhost/test");

interface QueryBuild {
    cols: string,
    where: string,
    sort: string,
    page: string,
    data: any
}

interface ColumnsSort {
    colName: string,
    order: 'asc' | 'desc'
}

/**
 * 检查表是否创建
 * @param table
 */
const checkAndCreateTableSqlite = async (table: DataTable): Promise<DataTable> => {
    const {tableName, columns} = table
    if (!tableName) {
        throw new Error(`table name is required`);
    }
    try {
        // 检查表是否存在
        const tableExist: Array<any> = await db.select(
            'SELECT * FROM sqlite_master WHERE type=$1 AND name = $2',
            ["table", tableName]);
        if (tableExist && tableExist.length === 1) {
            return table
        } else {
            const buildColumns = (columns: TableColumnInfo[]): string => {
                let cols: string[] =
                    columns.map(col => `${col['name']} ${col['type']} ${col['notNull'] ? 'not null' : ''} ${col['pk'] ? 'primary key' : ''} ${col['autoIncrement'] ? 'autoincrement' : ''} ${col['default'] ? `default '${col['default']}'` : ''}`)
                return cols.join(',\n\t');
            }
            const createSql: string =
                `create table ${tableName}
                 (
                     ${buildColumns(columns)}
                 )`
            console.log('execute sql to create table: \n', createSql)
            let res = await db.execute(createSql);
            console.log(`table [${tableName}] created result : [rowsAffected:${res.rowsAffected}, lastInsertId:${res.lastInsertId}`)
            return table
        }
    } catch (e: any) {
        throw new Error(`ceate table failure: ${table}:[${columns.keys()}]: ${e}`)
    }
}

/**
 * 构建查询条件
 *
 * {
 *     columnName1: {
 *         comp: '=/like/>/<',
 *         sort: 'asc/desc',
 *         data: '123',
 *         query: true // 有数据即可，表示这个列需要被查询
 *     }
 *     columnName2: '122',
 *     page: {
 *         index: 1, //从 第 1 页 开始
 *         size: 50,
 *     }
 * }
 *
 * @param table 实体表
 * @param query 查询条件
 * @returns {string}
 */
const buildQuery = (table: DataTable, query: DataColQueryInfo): QueryBuild => {
    const cols: ColQueryInfo[] = [] // 存储查询条件
    const queryCols: string[] = [] // 存储查询列
    const sorts: ColumnsSort[] = [] // 存储排序列
    const whereData: string[] | number[] = []
    const {page} = query

    query.columns.forEach((col: ColQueryInfo) => {
        const {columns} = table
        const {colName, comp, sort, data, query} = col
        const tableColNames: string[] = columns.map(c => c.name)
        if (tableColNames.indexOf(colName)) {
            // 是否作为查询列
            if (query) {
                queryCols.push(colName)
            }

            // 是否排序
            if (sort) {
                sorts.push({
                    colName: colName,
                    order: sort
                })
            }

            // 是否需要作为查询条件
            if (data !== undefined) {
                let itemObj: ColQueryInfo = {
                    colName: colName,
                    data: data,
                    comp: comp || "=",
                };
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
                        let range: string[] = (data as string).split(',');
                        if (range && range.length === 2) {
                            itemObj.data = `${range[0]} and ${range[1]}`
                        } else {
                            throw new Error(`Query Between need a min and max range`);
                        }
                        break
                    case '=':
                    case '>':
                    case '<':
                    case '>=':
                    case '<=': {
                        // 直接写上去就行
                        break
                    }
                }
                if (itemObj.data !== undefined) {
                    cols.push(itemObj)
                    // @ts-ignore
                    whereData.push(itemObj.data)
                }
            }
        }
    })
    const where = cols.map((i, index) => ` ${i.colName} ${i.comp} $${index} `).join(" and ");
    const order = sorts.map(i => ` ${i.colName} ${i.order} `).join(' , ')
    return {
        cols: (queryCols && queryCols.length > 0) ? queryCols.join(',') : "*",
        where: ` ${where ? ` where ${where}` : ''}`,
        sort: ` ${order ? ` order by ${order}` : ''}`,
        page: page.close ? '' : ` limit ${((page.index || 1) - 1) * ((page.size || 100))}, ${page.size} `,
        data: whereData
    }
}
/**
 * 存储数据sql
 * @param data
 */
const buildSaveColumns = <T extends object>(data: T): string => {
    const cols: string[] = []

    Object.keys(data).forEach(key => {
        const dataItem: string | number = (data as any)[key]
        cols.push(key)
    })
    return ` (${cols.join(',')}) values (${cols.map((i, index) => `?${index + 1}`).join(',')}) `
}
/**
 * 创建数据库表
 * @param table
 */
export const create = async (table: DataTable): Promise<DataTable> => {
    if (table && table.tableName && table.columns.length > 0) {
        return checkAndCreateTableSqlite(table)
    }
    throw new Error(`table info error: ${table.tableName}`)
}

/**
 * 判断数据是否存在
 * @param table
 * @param queryParams
 */
export const exist = async <T>(table: DataTable, queryParams: ColQueryInfo[]): Promise<T | undefined> => {
    create(table)
    const tableCols: any = {}
    table.columns.forEach(q => {
        tableCols[q.name] = q
    })
    const queryExistParams: ColQueryInfo[] = []
    queryParams.forEach(param => {
        if (tableCols.hasOwnProperty(param.colName)) {
            const col: TableColumnInfo = tableCols[param.colName]
            if (col.pk || col.union) {
                // TODO 之后需要将 col.union 替换为索引判断
                queryExistParams.push(param)
            }
        }
    })
    return await queryOne(table, queryExistParams)
}
export const query = async <T>(table: DataTable, query: DataColQueryInfo): Promise<Array<T>> => {
    create(table)
    const querySql: QueryBuild = buildQuery(table, query)
    const sql: string = `SELECT ${querySql.cols}
                         FROM ${table.tableName} ${querySql.where} ${querySql.sort} ${querySql.page} `;
    console.log(`execute query sql: [${sql}]`)
    return await db.select<Array<T>>(sql)
}
export const queryOne = async <T>(table: DataTable, queryParams: ColQueryInfo[]): Promise<T> => {
    const queryRes = await query<T>(table, {
        columns: queryParams,
        page: {
            close: true,
        }
    })
    if (queryRes) {
        if (queryRes.length === 1) {
            return queryRes[0]
        }
        throw new Error(`params for query one but more than one results: [${queryParams.length}]`)
    }
    return {} as any;
}
export const count = async <T>(table: DataTable, queryParams: ColQueryInfo[]): Promise<number> => {
    const queryRes = await query<T>(table, {
        columns: queryParams,
        page: {
            close: true,
        }
    })
    return queryRes.length;
}
export const save = async <T extends object>(table: DataTable, data: T, cover: boolean = true): Promise<T> => {
    create(table)
    // 组合查重条件
    const queryCols: ColQueryInfo[] = Object.keys(data).map(key => {
        return {
            colName: key,
            data: (data as any)[key]
        }
    })
    try {
        const existEntity = await exist<T>(table, queryCols)
        if (existEntity) {
            // 不覆盖数据，将已存储的数据直接回写到list
            if (cover) {
                return modify<T>(table, existEntity)
            } else {
                return existEntity;
            }
        }
        // 数据不存在，需要存储
        // 开启事务
        db.execute('BEGIN TRANSACTION');
        const sql: string = `INSERT INTO ${table.tableName} ${buildSaveColumns(data)}`;
        const saveRes = await db.execute(sql, Object.keys(data).map(key => (data as any)[key]));
        db.execute('COMMIT');
        if (saveRes.rowsAffected) {
            (data as any)[table.IdKey] = saveRes.lastInsertId
            return data;
        } else {
            throw new Error(`save data [${data}] failue`)
        }
    } catch (e) {
        throw new Error(`save data [${data}] failue: ${e}`)
    }
}
export const saveBatch = async <T extends object>(table: DataTable, dataList: Array<T>, cover: boolean = true): Promise<Array<T>> => {
    create(table)
    let saveEntityList: Array<T> = []
    if (!cover) {
        // 如果不覆盖，需要查询重复
        for (let index = 0; index < dataList.length; index++) {
            const data = dataList[index]
            // 组合查重条件
            const queryCols: ColQueryInfo[] = Object.keys(data).map(key => {
                return {
                    colName: key,
                    data: (data as any)[key]
                }
            })

            const existEntity = await exist<T>(table, queryCols)
            if (existEntity) {
                // 不覆盖数据，将已存储的数据直接回写到list
                dataList[index] = existEntity
            } else {
                // 数据不存在，需要存储
                saveEntityList.push(data)
            }
        }
    } else {
        // 覆盖数据，直接复制
        saveEntityList = dataList
    }
    try {
        // 批量存储
        // 开启事务
        db.execute('BEGIN TRANSACTION');
        saveEntityList.forEach(async (data: T) => {
            let sql: string = `INSERT INTO ${table.tableName} ${buildSaveColumns(data)}`;
            let saveRes = await db.execute(sql, Object.keys(data).map(key => (data as any)[key]));
            if (saveRes.rowsAffected) {
                (data as any)[table.IdKey] = saveRes.lastInsertId
            }
        })
        db.execute('COMMIT');
    } catch (e) {
        throw new Error(`save data failure: ${e}`)
    }

    // 全部回写
    return dataList;
}
export const modify = async <T extends object>(table: DataTable, data: T): Promise<T> => {
    create(table)
    if (data.hasOwnProperty(table.IdKey)) {
        const tableCols = table.columns.map(col => col.name);
        const cols: string[] = []
        Object.keys(data).filter((key, index) => {
            if (typeof (data as any)[key] === 'undefined') {
                (data as any)[key] = null
            }
        })
        try {
            const buildColumns: string[] = Object.keys(data)
                .map((key, index) => ` ${key}=$` + index)
            db.execute('BEGIN TRANSACTION');
            let sql: string = `UPDATE ${table.tableName}
                               set ${buildColumns.join(' ,')}
                               where ${table.IdKey} = ${(data as any)[table.IdKey]}`;
            let modifyRes = await db.execute(sql, Object.keys(data).map(key => (data as any)[key]))
            db.execute('COMMIT');
            if (modifyRes.rowsAffected > 0) {
                return data
            } else {
                throw new Error(`Modify data [${data}] failure.`)
            }
        } catch (e) {
            throw new Error(`Modify data [${data}] failure: ${e}`)
        }
    } else {
        throw new Error("Modify data without key property.")
    }
}
export const remove = async <T>(table: DataTable, ids: string[] | number[]): Promise<Array<T>> => {
    create(table)
    const removeItems: Array<T> = []
    const removeItem = async (id: string | number) => {
        const sql: string = `DELETE
                             FROM ${table.tableName}
                             where ${table.IdKey} = $1`;
        try {
            db.execute('BEGIN TRANSACTION');
            const removeRes = await db.execute(sql, [id])
            db.execute('COMMIT');
            if (removeRes.rowsAffected === 0) {
                throw new Error(`remove data [id:${id}]`)
            }
        } catch (e) {
            throw e
        }
    }
    ids.forEach(async id => {
        try {
            const query = await queryOne<T>(table, [{
                colName: table.IdKey,
                data: id,
            }])
            if (query) {
                removeItems.push(query)
                removeItem(id)
            }
        } catch (e) {
            throw new Error(`remove data [id:${id}] failure: ${e}`)
        }

    })
    return removeItems;
}
