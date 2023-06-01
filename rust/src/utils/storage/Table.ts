import {ColQueryInfo, DataBaseOperate, DataColQueryInfo, DataTable, TableColumnInfo} from "@/utils/Models";
import {count, exist, modify, query, queryOne, remove, save, saveBatch} from "@/utils/storage/Sqlite";

const table = <T extends object>(tableName: 'bookSource' | 'bookGroup' | 'bookInfo' | 'bookChapter' | 'appConfig', columns: Array<TableColumnInfo>): DataTable => {
    const voidFun = () => {
    }
    const table: DataTable = {
        tableName: tableName,
        IdKey: 'id',
        columns: columns,
        operates: {
            exist: voidFun,
            query: voidFun,
            one: voidFun,
            count: voidFun,
            save: voidFun,
            saveBatch: voidFun,
            modify: voidFun,
            remove: voidFun
        }
    }
    const operates: DataBaseOperate = {
        exist: (queryParams: ColQueryInfo[]): Promise<T | undefined> => exist(table, queryParams),
        query: (queryParams: DataColQueryInfo): Promise<Array<T>> => query(table, queryParams),
        one: (queryParams: ColQueryInfo[]): Promise<T> => queryOne<T>(table, queryParams),
        count: (queryParams: ColQueryInfo[]): Promise<number> => count<T>(table, queryParams),
        save: (data: T, cover: boolean = false): Promise<T> => save<T>(table, data, cover),
        saveBatch: (dataList: Array<T>, cover: boolean = false): Promise<Array<T>> => saveBatch<T>(table, dataList, cover),
        modify: (data: T): Promise<T> => modify<T>(table, data),
        remove: (ids: string[] | number[]): Promise<Array<T>> => remove<T>(table, ids)
    }
    return {
        ...table, ...{
            operates: operates
        }
    }
}

// 书源
export interface BookSource {

}

const bookSourceColumns: Array<TableColumnInfo> = [
    {
        name: 'id',
        type: 'INTEGER',
        pk: true,
        notNull: true,
        autoIncrement: true,
        comment: '书源主键'
    },
    {
        name: 'platform',
        type: 'TEXT',
        notNull: true,
        comment: '书源平台',
        union: true, // 唯一，查询重复用
    },
    {
        name: 'sourceName',
        type: 'TEXT',
        notNull: true,
        comment: '书源名称',
        union: true, // 唯一，查询重复用
    },
    {
        name: 'sourceType',
        type: 'TEXT',
        default: 'text',
        comment: '书源类型',
    },
    {
        name: 'sourceUrl',
        type: 'TEXT',
        comment: '书源url'
    },
    {
        name: 'enable',
        type: 'INT',
        default: 1,
        comment: '书源启用'
    },
    {
        name: 'weight',
        type: 'INT',
        default: 1000,
        comment: '书源权重'
    },
    {
        name: 'sourceJson',
        type: 'TEXT',
        notNull: true,
        comment: '书源JSON文件位置'
    },
    {
        name: 'authorId',
        type: 'TEXT',
        comment: '作者'
    },
    {
        name: 'desc',
        type: 'TEXT',
        comment: '描述'
    },
    {
        name: 'lastModifyTime',
        type: 'TEXT',
        comment: '最后更新时间'
    },
    {
        name: 'toTop',
        type: 'TEXT',
        comment: '距离上一次'
    },

];
export const bookSource: DataTable = table<BookSource>('bookSource', bookSourceColumns)

// 分组
export interface BookGroup {

}

const bookGroupColumns: Array<TableColumnInfo> = [
    {
        name: 'id',
        type: 'INTEGER',
        pk: true,
        notNull: true,
        autoIncrement: true,
        comment: '分组主键'
    },
    {
        name: 'platform',
        type: 'TEXT',
        notNull: true,
        comment: '分组平台',
        union: true // 唯一，查询重复用
    },
    {
        name: 'groupName',
        type: 'TEXT',
        notNull: true,
        comment: '分组名称',
        union: true // 唯一，查询重复用
    },
    {
        name: 'sourceType',
        type: 'TEXT',
        comment: '分组类型'
    },
    {
        name: 'bookCount',
        type: 'INT',
        default: 0,
        comment: '书本数量'
    },
    {
        name: 'enable',
        type: 'INT',
        default: 1,
        comment: '是否可用'
    },
    {
        name: 'sort',
        type: 'INT',
        default: 0,
        comment: '排序'
    }
];
export const bookGroup: DataTable = table<BookGroup>('bookGroup', bookGroupColumns)

// 书籍
export interface BookInfo {

}

const bookInfoColumns: Array<TableColumnInfo> = [
    {
        name: "id",
        type: "INTEGER",
        pk: true,
        notNull: true,
        autoIncrement: true,
        comment: "书籍主键"
    },
    {
        name: "platform",
        type: "TEXT",
        notNull: true,
        comment: "书籍平台",
        union: true
    }, {
        name: "sourceType",
        type: "TEXT",
        comment: "书籍类型"
    },
    {
        name: "groupId",
        type: "INTEGER",
        notNull: true,
        comment: "书籍分组"
    },
    {
        name: "originFrom",
        type: "TEXT",
        notNull: true,
        comment: "书源来源，本地/网络"
    },
    {
        name: "detailUrl",
        type: "TEXT",
        comment: "书源网络地址"
    },
    {
        name: "sourceId",
        type: "INTEGER",
        comment: "所属书源"
    },
    {
        name: "sourceSearch",
        type: "TEXT",
        comment: "书源搜索的id记录，逗号分割"
    },
    {
        name: "bookName",
        type: "TEXT",
        notNull: true,
        comment: "书籍名称",
        union: true
    },
    {
        name: "cover",
        type: "TEXT",
        notNull: true,
        comment: "书籍封面",
        union: true
    },
    {
        name: "author",
        type: "TEXT",
        comment: "作者"
    },
    {
        name: "wordCount",
        type: "TEXT",
        comment: "字数/页数/时长"
    },
    {
        name: "desc",
        type: "TEXT",
        comment: "描述"
    },
    {
        name: "cat",
        type: "TEXT",
        comment: "类型"
    },
    {
        name: "updateTime",
        type: "TEXT",
        comment: "最新章更新时间"
    },
    {
        name: "updateStatus",
        type: "TEXT",
        comment: "更新状态，最新章"
    },
    {
        name: "readStatus",
        type: "TEXT",
        comment: "阅读状态，xx章未读/已读完"
    },
    {
        name: "currReadStatus",
        type: "TEXT",
        comment: "章节阅读进度，这三个存储格式一致"
    },
    {
        name: "currReadContent",
        type: "TEXT",
        comment: "字数/页数/时长/阅读进度"
    },
    {
        name: "config",
        type: "TEXT",
        comment: "阅读设置，字体/背景等"
    },
    {
        name: "enable",
        type: "INT",
        default: 1,
        comment: "是否可用"
    }];
export const bookInfo: DataTable = table<BookInfo>('bookInfo', bookInfoColumns)

// 章节
export interface BookChapter {

}

const bookChapterColumns: Array<TableColumnInfo> = [
    {
        name: "id",
        type: "INTEGER",
        pk: true,
        notNull: true,
        autoIncrement: true,
        comment: "章节主键"
    },
    {
        name: "bookId",
        type: "INTEGER",
        notNull: true,
        comment: "所属书籍"
    },
    {
        name: "sourceId",
        type: "INTEGER",
        notNull: true,
        comment: "所属书籍"
    },
    {
        name: "platform",
        type: "TEXT",
        notNull: true,
        comment: "所属平台",
        union: true
    },
    {
        name: "sourceType",
        type: "TEXT",
        comment: "书籍类型"
    },
    {
        name: "cached",
        type: "INT",
        default: 0,
        comment: "是否缓存"
    },
    {
        name: "content",
        type: "TEXT",
        comment: "书籍内容"
    },
    {
        name: "title",
        type: "TEXT",
        notNull: true,
        comment: "章节名称"
    },
    {
        name: "url",
        type: "TEXT",
        notNull: true,
        comment: "章节地址"
    },
    {
        name: "desc",
        type: "TEXT",
        comment: "描述"
    },
    {
        name: "wordCount",
        type: "TEXT",
        comment: "字数/页数/时长"
    },
    {
        name: "currReadContent",
        type: "TEXT",
        comment: "字数/页数/时长/阅读进度"
    },
    {
        name: "enable",
        type: "INT",
        default: 1,
        comment: "是否可用"
    },
    {
        name: "sort",
        type: "INT",
        default: 0,
        comment: "排序,也是下标"
    }];
export const bookChapter: DataTable = table<BookChapter>('bookChapter', bookChapterColumns)

// 配置
export interface AppConfig {

}

const appConfigColumns: Array<TableColumnInfo> = [
    {
        name: 'id',
        type: 'INTEGER',
        pk: true,
        notNull: true,
        autoIncrement: true,
        comment: '配置主键'
    },
    {
        name: 'name',
        type: 'TEXT',
        notNull: true,
        comment: '配置名称，比如字体大小，阅读背景，搜索历史、选择的书源等都可以放这里等',
    },
    {
        name: 'value',
        type: 'TEXT',
        notNull: true,
        comment: '配置内容',
    },
    {
        name: 'setDef',
        type: 'INT',
        default: 0,
        comment: '是否默认配置，同种配置只能有一个是默认'
    },
];
export const appConfig: DataTable = table<AppConfig>('appConfig', appConfigColumns)

export const tables: any = {
    bookSource: bookSource,
    bookGroup: bookGroup,
    bookInfo: bookInfo,
    bookChapter: bookChapter,
    appConfig: appConfig,
}

export const getTable = (tableName: 'bookSource' | 'bookGroup' | 'bookInfo' | 'bookChapter' | 'appConfig'): DataTable => {
    return tables[tableName]
}
