import {DataTable} from "@/utils/Models";
// 书源
export const bookSource: DataTable = {
    tableName: 'bookSource',
    columns: [
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

    ],
}

// 分组
export const bookGroup: DataTable = {
    tableName: 'bookGroup',
    columns: [
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
    ]
}

// 书籍
export const bookInfo: DataTable = {
    tableName: 'bookInfo',
    columns: [
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
        }]
}

// 章节
export const bookChapter: DataTable = {
    tableName: 'bookChapter',
    columns: [
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
        }]
}

// 配置
export const appConfig: DataTable = {
    tableName: 'appConfig',
    columns: [
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
    ]
}

export const tables: any = {
    bookSource: bookSource,
    bookGroup: bookGroup,
    bookInfo: bookInfo,
    bookChapter: bookChapter,
    appConfig: appConfig,
}
