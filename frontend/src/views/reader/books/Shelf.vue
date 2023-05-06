<template>
    <div class="bookshelf">
        <div v-if="bookshelf && bookshelf.length > 0" class="bookshelf-container">
            <div class="book-item-container" @click="handleBookInfo(book)"
                 v-for="book in bookshelf">
                <div class="book-item">
                    <img class="book-cover" :src="book.cover">
                    <div class="book-name">{{ book.bookName }}</div>
                </div>
            </div>
        </div>
        <a-empty v-else :description="false"/>

        <detail ref="bookDetail"/>
    </div>
</template>

<script>
import {ipcApiRoute} from "@/api/main";
import Detail from "@/views/reader/books/Detail.vue";

export default {
    name: 'shelf',
    components: {Detail},
    data() {
        return {
            groupId: '',
            bookshelf: [], // 书架
        }
    },
    mounted() {
    },
    methods: {
        clean() {
            const that = this
            that.bookshelf = []
        },
        async init(group) {
            const that = this
            if (group && group.id) {
                that.group = group
                // 加载书籍
                const res = await that.$ipc.invoke(ipcApiRoute.bookInfoOperation, {
                    action: 'get',
                    data: {
                        groupId: group.id
                    }
                })
                console.log("query books by groupId", res);
                if (res && res.result) {
                    that.bookshelf = res.result
                }
            }
        },
        handleBookInfo(bookInfo) {
            console.log(bookInfo)
            // 获取章节

        }
    }
}
</script>


<style lang="less">

.bookshelf {
  position: relative;
  height: 100%;

  .bookshelf-container {
    height: 100%;
    overflow-x: scroll;
    display: flex;

    .book-item-container {
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

.ant-empty {
  height: 100%;

  .ant-empty-image {
    height: 100%;
  }
}


</style>
