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

        <div class="search-result-container">
            <div class="result-container">
                <div class="node-item" v-for="node in searchData.searchList">
                    <a-row>
                        <a-col :span="4" class="node-name">
                            <div>{{ node.sourceName }}</div>
                            <div>{{ node.result.length }}本</div>
                        </a-col>
                        <a-col :span="20" class="book-list">
                            <div class="book-container" v-for="book in node.result">
                                <a-popover :title="book.bookName" style="width: 4rem">
                                    <template slot="content">
                                        <p>{{ book.author }}</p>
                                        <p>{{ book.desc}}</p>
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
    </div>
</template>

<script>
import EditorArea from "@/components/EditorArea.vue";
import {SourceType, SourcePlatform} from "@/model/typeModel";
import {ipcApiRoute} from "@/api/main";

export default {
    name: 'search',
    components: {EditorArea},
    data() {
        return {
            SourceType,
            SourcePlatform,
            searchData: {
                type: 'text',
                platform: 'StandarReader',
                search: '',
                searchList: []
            },
        }
    },
    mounted() {
        this.init()
    },
    methods: {
        init(type, search, platform) {
            const that = this
            that.searchData.type = type || 'text'
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
            const searchRes = await that.$ipc.invoke(ipcApiRoute.searchBook, that.searchData)
            console.log("search result", searchRes)
            if (searchRes && searchRes.length > 0) {
                that.searchData.searchList = [...that.searchData.searchList, ...searchRes]
            } else {
                that.$message.error(searchRes.message)
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
