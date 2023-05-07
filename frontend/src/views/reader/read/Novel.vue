<template>
    <div class="chapter-box">
        <div class="setting-box"></div>
        <div class="content-box" v-if="chapterInfo && chapterInfo.content">
            <pre class="content">
                {{ chapterInfo.content }}
            </pre>
        </div>
    </div>
</template>
<script>
export default {
    data() {
        return {
            chapterInfo: {}
        }
    },
    methods: {
        init(chapterInfo) {
            this.chapterInfo = chapterInfo
        }
    }
}
</script>
<style lang="less">
.chapter-box {
  .setting-box {

  }

  .content-box {
    .content {
      text-align: left;
    }
  }
}
</style>
