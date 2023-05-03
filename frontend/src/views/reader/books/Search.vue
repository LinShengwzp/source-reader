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
                    <a-select placeholder="类型"  slot="addonBefore" style="width: 10rem"
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
    </div>
</template>

<script>
import EditorArea from "@/components/EditorArea.vue";
import {SourceType, SourcePlatform} from "@/model/typeModel";

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
            that.searchData.search = search || ''
            that.searchData.platform = platform || 'StandarReader'
        },
        childInputChange() {

        },
        /**
         * 搜索
         */
        handleSearchBook() {

        }
    }
}
</script>

<style scoped lang="less">

</style>
