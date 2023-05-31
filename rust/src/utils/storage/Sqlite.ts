import Database from "tauri-plugin-sql-api";
import {ColQueryInfo, DataColQueryInfo, DataQueryPage, DataTable, TableColumnInfo} from "@/utils/Models";
import {getTable, tables} from "@/utils/storage/Table";

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
export const exist = async (table: DataTable, queryParams: ColQueryInfo[]): Promise<boolean> => {
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
                queryExistParams.push(param)
            }
        }
    })
    const queryRes = await queryOne(table, queryExistParams)
    return !!queryRes
}
export const query = async <T>(table: DataTable, query: ColQueryInfo[]): Promise<Array<T>> => {
    return []
}
export const queryOne = async <T>(table: DataTable, query: ColQueryInfo[]): Promise<T> => {
    return {} as any;
}
export const count = async (table: DataTable, query: ColQueryInfo[]): Promise<number> => {
    return 0;
}
export const save = async <T>(table: DataTable, dataList: Array<any>, cover: boolean = true): Promise<T> => {
    return {} as any;
}
export const modify = async <T>(table: DataTable, data: object): Promise<T> => {
    return {} as any;
}
export const remove = async <T>(table: DataTable, query: ColQueryInfo[]): Promise<T> => {
    return {} as any;
}
