<template>
    <a-drawer
            :title="bookDetail.drawerTitle"
            placement="right"
            :closable="false"
            width="60%"
            @close="bookDetail.showDrawer = false"
            :visible="bookDetail.showDrawer">
        <div class="book-detail-container">
            <a-row class="book-info-container">
                <a-col :span="10" class="book-cover">
                    <div class="cover-box">
                        <img :src="bookDetail.bookInfo.cover" class="book-cover">
                    </div>
                </a-col>
                <a-col :span="14" class="info-box">
                    <div class="detail-info-item"><h2>{{ bookDetail.bookInfo.bookName }}</h2></div>
                    <div class="detail-info-item" v-if="bookDetail.bookInfo.author">作者:
                        {{ bookDetail.bookInfo.author }}
                    </div>
                    <div class="detail-info-item" v-if="bookDetail.bookInfo.desc">简介: {{
                        bookDetail.bookInfo.desc
                        }}
                    </div>
                    <div class="detail-info-item" v-if="bookDetail.bookInfo.status">状态:
                        {{ bookDetail.bookInfo.status }}
                    </div>
                    <div class="detail-info-item" v-if="bookDetail.bookInfo.wordCount">字数:
                        {{ bookDetail.bookInfo.wordCount }}
                    </div>
                    <div class="detail-info-item" v-if="bookDetail.bookInfo.lastChapterTitle">最新:
                        {{ bookDetail.bookInfo.lastChapterTitle }}
                    </div>
                </a-col>
            </a-row>

            <a-row v-if="bookDetail.chapterList" class="book-chapter-container">
                <h2>目录 ({{ bookDetail.chapterList.length }}章)</h2>
                <h3>最新章</h3>
                <div class="chapter-item" v-for="(chapter, index) in bookDetail.chapterList.slice(0, 5)"
                     @click="handleReadBook(bookDetail.chapterList.length - 1 - index)">
                    {{ bookDetail.chapterList[bookDetail.chapterList.length - 1 - index].title }}
                </div>
            </a-row>

            <a-row class="book-operate-container">
                <div v-if="bookDetail.bookInfo.id" class="book-operate-btn btn operate-shelf operate-out-bookshelf"
                     @click="handleOutOfBookshelf">移出书架
                </div>
                <div v-else class="book-operate-btn btn operate-shelf operate-into-bookshelf"
                     @click="handleIntoBookshelf">加入书架
                </div>
                <div class="book-operate-btn btn operate-read" @click="handleReadBook">开始阅读</div>
            </a-row>
        </div>
    </a-drawer>
</template>

<script>
import {ipcApiRoute} from "@/api/main";

export default {
    data() {
        return {
            bookDetail: {
                drawerTitle: "",
                showDrawer: false,
                sourceId: "",
                bookInfo: {},
                chapterList: []
            }
        }
    },
    methods: {
        init(bookDetail) {
            this.bookDetail = bookDetail
        },
        async handleOutOfBookshelf() {
            const that = this
            const {bookInfo, chapterList} = that.bookDetail
            if (bookInfo.id) {
                const res = await that.$ipc.invoke(ipcApiRoute.bookRemove, {bookId: bookInfo.id})
                if (res && res.code === 200) {
                    console.log("移出成功")
                    that.$nextTick(() => {
                        bookInfo.id = ""
                        console.log("book info", that.bookDetail.bookInfo)
                    })
                }
            }
        },
        /**
         * 加入书架
         * 搜索页面没有移出书架的操作
         * @returns {Promise<void>}
         */
        async handleIntoBookshelf() {
            const that = this
            const {bookInfo, chapterList} = that.bookDetail
            if (!bookInfo || !bookInfo.bookName || !chapterList || !(chapterList.length > 0)) {
                that.$message.error("书籍内容或章节缺失")
                return;
            }
            const res = await that.$ipc.invoke(ipcApiRoute.bookInfoSave, {
                groupId: that.groupId,
                sourceId: that.bookDetail.sourceId,
                detailUrl: bookInfo.detailUrl,
                bookInfo: bookInfo,
            })
            console.log("save book into booshelf", res)
            if (res && res.code === 200) {
                that.$nextTick(() => {
                    that.bookDetail.bookInfo = res.result
                    console.log("book info", that.bookDetail.bookInfo)
                })
            } else {
                that.$message.error(res.message)
            }
            return res;
        },
        /**
         * 开始阅读
         * @param index 章节下标;无参数则直接从头开始
         * @returns {Promise<void>}
         */
        async handleReadBook(index) {
            // 加入书架
            const that = this
            const res = await this.handleIntoBookshelf()
            // 唤起阅读界面
            console.log("read book")
        }
    }
}
</script>

<style scoped lang="less">

.book-detail-container {
    position: relative;

    .book-info-container {
        .book-cover {
            .cover-box {
                text-align: center;

                .book-cover {
                    width: 12rem;
                    height: 16rem;
                }
            }
        }

        .info-box {
            .detail-info-item {
                margin: 0.2rem;
            }
        }
    }

    .book-chapter-container {
        margin: 1rem;
        user-select: none;

        .chapter-item {
            cursor: pointer;
            margin: 0.1rem;
        }

        .chapter-item:hover {
            color: #4fdb89;
        }
    }

    .book-operate-container {
        position: absolute;
        margin: 0 1rem;
        border: 0.1rem;
        width: 96%;
        display: flex;
        cursor: pointer;
        user-select: none;

        .book-operate-btn {
            flex: 1;
            text-align: center;
            margin: 0.1rem;
            line-height: 1.5rem;
            border: 0.1rem solid #d7d7d7;
            border-radius: 0.1rem;
        }

        .book-operate-btn:hover {
            background-color: #4fdb89;
            color: white;
        }
    }
}
</style>
