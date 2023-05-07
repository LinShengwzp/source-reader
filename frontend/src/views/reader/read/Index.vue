<template>
    <div class="content-box">
        <div class="content content-text" v-show="chapter.sourceType === 'text'">
            <novel ref="novel"/>
        </div>
        <div class="content content-comic" v-show="chapter.sourceType === 'comic'"></div>
        <div class="content content-audio" v-show="chapter.sourceType === 'audio'"></div>
        <div class="content content-video" v-show="chapter.sourceType === 'video'"></div>

    </div>
</template>

<script>
import {ipcApiRoute} from "@/api/main";

import Novel from "@/views/reader/read/Novel.vue";

export default {
    data() {
        return {
            chapter: {}
        }
    },
    components: {Novel},
    mounted() {
        const {params} = this.$router.currentRoute
        this.init(params.bookId, params.chapterId, params.index)
    },
    methods: {
        async init(bookId, chapterId, chapterIndex) {
            if (!bookId) {
                return;
            }
            const res = await this.$ipc.invoke(ipcApiRoute.bookContent, {
                bookId: bookId,
                index: chapterIndex,
                chapterId: chapterId
            })
            console.log("book content", res)
            if (res && res.code === 200) {
                const chapter = res.result
                if (chapter && chapter.sourceType) {
                    this.chapter = chapter
                    switch (chapter.sourceType) {
                        case "text": {
                            this.$refs.novel.init(chapter)
                        }
                    }
                }
            }
        }
    }
}
</script>
<style scoped lang="less">

</style>
