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
                                            <p v-html="book.author"></p>
                                            <p v-html="book.desc"></p>
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

            <a-pagination v-show="searchData.searchList && searchData.searchList.length > 0"
                          show-size-changer
                          show-quick-jumper
                          :default-page-size="searchData.page.size"
                          :default-current="searchData.page.index"
                          :total="searchData.page.count"
                          @change="handlePageChange"
                          @showSizeChange="handleSizeChange"
            />
        </a-spin>

        <detail :group-id="groupId" ref="bookDetail"/>
    </div>
</template>

<script>
import EditorArea from "@/components/EditorArea.vue";
import Detail from "@/views/reader/books/Detail.vue";
import {SourcePlatform, SourceType} from "@/model/typeModel";
import {ipcApiRoute} from "@/api/main";

export default {
    name: 'search',
    components: {EditorArea, Detail},
    props: {
        groupId: Number,
    },
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
                    index: 1, //从 第 1 页 开始
                    size: 10,
                    count: 0
                }
            },
            bookDetail: {
                drawerTitle: "",
                showDrawer: false,
                sourceId: "",
                bookInfo: {},
                chapterList: []
            }
        }
    },
    mounted() {
        this.init()
    },
    methods: {
        init(type, search, platform, groupId) {
            const that = this
            that.searchData.type = type || 'text'
            that.searchData.search = search || '都市'
            that.searchData.platform = platform || 'StandarReader'
            console.log("groupid", that.groupId)
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
            const that = this
            if (!bookInfo || !bookInfo.detailUrl || !sourceId) {
                return
            }
            that.bookDetail = {
                drawerTitle: "",
                showDrawer: true,
                sourceId: sourceId,
                bookInfo: {},
                chapterList: []
            }
            const detail = await that.$ipc.invoke(ipcApiRoute.bookDetail, {
                sourceId: sourceId,
                queryInfo: bookInfo,
            })
            console.log("book detail", detail)
            if (detail && detail.code === 200) {
                bookInfo = {...bookInfo, ...detail.detail}
                that.$nextTick(() => {
                    that.bookDetail.drawerTitle = bookInfo.bookName
                    that.bookDetail.bookInfo = bookInfo
                    that.bookDetail.chapterList = detail.chapter.list
                    that.$refs['bookDetail'].init(that.bookDetail)
                })
            }
        },
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


</style>
