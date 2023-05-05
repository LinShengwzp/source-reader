<template>
    <div class="search-container">
        <a-form :model="searchData" layout="inline"
                name="searchForm" ref="searchForm"
                :wrapper-col="{ span: 24 }"
                autocomplete="off">

            <a-form-item name="type">

            </a-form-item>

            <!--            <a-form-item name="platform">-->
            <!--                <a-select placeholder="平台"-->
            <!--                          v-model="searchData.platform" @change="childInputChange">-->
            <!--                    <a-select-option v-for="option in SourcePlatform" :key="option.name" :value="option.name">-->
            <!--                        {{ option.label }}-->
            <!--                    </a-select-option>-->
            <!--                </a-select>-->
            <!--            </a-form-item>-->

            <a-form-item name="search">
                <a-input placeholder="名称/作者" style="width: 30rem" allowClear
                         v-model="searchData.search" @input="childInputChange">
                    <a-select placeholder="类型" slot="addonBefore" style="width: 10rem"
                              v-model="searchData.type" @change="childInputChange">
                        <a-select-option v-for="option in SourceType" :key="option.name" :value="option.name">
                            {{ option.label }}
                        </a-select-option>
                    </a-select>
                </a-input>
            </a-form-item>

            <a-form-item name="search">
                <a-button type="primary" @click="handleSearchBook">
                    搜索
                </a-button>
            </a-form-item>

        </a-form>

        <a-spin :spinning="searchData.loading" tip="加载中..." style="height: 100%">
            <div class="search-result-container">
                <div class="result-container">
                    <div class="node-item" v-for="node in searchData.searchList">
                        <a-row>
                            <a-col :span="4" class="node-name">
                                <div>{{ node.sourceName }}</div>
                                <div>{{ node.result.length }}本</div>
                            </a-col>
                            <a-col :span="20" class="book-list">
                                <div class="book-container" @click="handleBookInfo(book, node.sourceId)"
                                     v-for="book in node.result">
                                    <a-popover :title="book.bookName" style="width: 4rem">
                                        <template slot="content">
                                            <p>{{ book.author }}</p>
                                            <p>{{ book.desc }}</p>
                                        </template>
                                        <div class="book-item">
                                            <img class="book-cover" :src="book.cover">
                                            <div class="book-name">{{ book.bookName }}</div>
                                        </div>
                                    </a-popover>
                                </div>
                            </a-col>
                        </a-row>
                    </div>
                </div>
            </div>

            <a-pagination
                    show-size-changer
                    show-quick-jumper
                    :default-page-size="searchData.page.size"
                    :default-current="searchData.page.index"
                    :total="searchData.page.count"
                    @change="handlePageChange"
                    @showSizeChange="handleSizeChange"
            />
        </a-spin>


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

                <a-row class="book-chapter-container">
                    <h2>目录</h2>
                </a-row>

                <a-row class="book-chapter-container">
                    <h2>停止更新</h2>
                </a-row>

                <a-row class="book-chapter-container">
                    <div>加入书架</div>
                    <div>移出书架</div>
                    <div>开始阅读</div>
                </a-row>
            </div>
        </a-drawer>

    </div>
</template>

<script>
import EditorArea from "@/components/EditorArea.vue";
import {SourcePlatform, SourceType} from "@/model/typeModel";
import {ipcApiRoute} from "@/api/main";

export default {
    name: 'search',
    components: {EditorArea},
    data() {
        return {
            SourceType,
            SourcePlatform,
            searchData: {
                loading: false,
                type: 'text',
                platform: 'StandarReader',
                search: '',
                searchList: [],
                page: {
                    index: 5, //从 第 1 页 开始
                    size: 1,
                    count: 0
                }
            },
            bookDetail: {
                drawerTitle: "",
                showDrawer: false,
                bookInfo: {},
            }
        }
    },
    mounted() {
        this.init()
    },
    methods: {
        init(type, search, platform) {
            const that = this
            that.searchData.type = type || 'video'
            that.searchData.search = search || '都市'
            that.searchData.platform = platform || 'StandarReader'
        },
        childInputChange() {

        },
        /**
         * 搜索
         */
        async handleSearchBook() {
            const that = this
            that.searchData.searchList = []
            that.searchData.loading = true
            const searchRes = await that.$ipc.invoke(ipcApiRoute.searchBook, that.searchData)
            console.log("search Result", searchRes)
            if (searchRes.result && searchRes.result.length > 0) {
                that.$nextTick(() => {
                    that.searchData.searchList = searchRes.result
                    that.searchData.page = searchRes.page
                    that.searchData.loading = false
                })
            } else {
                that.searchData.loading = false
                that.$message.error(searchRes.message)
            }
        },
        handleSizeChange(current, pageSize) {
            console.log(current, pageIndex);
            this.searchData.page.index = current
            this.searchData.page.size = pageSize
            this.handleSearchBook()
        },
        handlePageChange(page, pageIndex) {
            this.searchData.page.index = page
            this.handleSearchBook()
        },
        /**
         * 点击选中书籍
         * @param bookInfo
         * @param sourceId
         */
        async handleBookInfo(bookInfo, sourceId) {
            console.log(bookInfo, sourceId)
            const that = this

            if (!bookInfo || !bookInfo.detailUrl || !sourceId) {
                return
            }

            const detail = await that.$ipc.invoke(ipcApiRoute.bookDetail, {
                sourceId: sourceId,
                detailUrl: bookInfo.detailUrl,
                platform: "StandarReader"
            })

            if (bookInfo && bookInfo.bookName) {
                that.bookDetail.drawerTitle = bookInfo.bookName
                that.bookDetail.bookInfo = bookInfo
                that.bookDetail.showDrawer = true
            }
        }

    }
}
</script>

<style scoped lang="less">

.search-result-container {
  position: relative;
  margin: 1rem;
  height: 100%;
  overflow-y: scroll;

  .result-container {
    .node-item {
      border: 0.1rem solid #83e0b0;
      border-radius: 0.5rem;
      padding: 0.1rem;
      margin: 0.1rem;

      .node-name {
        padding: 1rem;
        text-align: center;
        line-height: 2rem;
      }

      .book-list {
        overflow-x: scroll;
        display: flex;

        .book-container {
          position: relative;
          display: inline-block;

          .book-item {
            position: relative;
            width: 5rem;
            height: 8rem;
            margin: 0.1rem 1rem;
            cursor: pointer;

            .book-cover {
              width: 5rem;
              height: 7rem;
              box-shadow: #9a9a9a 0.2rem 0.2rem 0.5rem 0.1rem;
            }

            .book-name {
              text-align: center;
              font-size: smaller;
              overflow: hidden;
              white-space: nowrap;
              text-overflow: ellipsis;
            }
          }
        }

      }
    }
  }

}

.book-detail-container {
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
}

</style>
