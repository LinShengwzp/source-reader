const bookSource = {
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

export {
    bookSource
}
