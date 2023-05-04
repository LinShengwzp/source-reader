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
                            {{ node.sourceName }}
                        </a-col>
                        <a-col :span="20">
                            <div class="book-container" v-for="book in node.result">
                                <div class="book-item">
                                    <img class="book-cover" :src="book.cover" :alt="book.bookName">
                                </div>
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
      .node-name {

      }

      .book-container {
        position: relative;
        display: inline-block;

        .book-item {
          width: 5rem;
          height: 8rem;
          margin: 1rem;

          .book-cover {
            width: 100%;
          }
        }
      }
    }
  }


}

</style>
