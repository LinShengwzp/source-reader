
<template>
    <div class="bookshelf">
        <div v-if="bookshelf && bookshelf.length > 0" class="bookshelf-container">
            <div class="book-item-container">
                <div class="book-item">
                    书籍
                </div>
            </div>
        </div>
        <a-empty v-else :description="false" />
    </div>
</template>

<script>
export default {
    name: 'shelf',
    data() {
        return {
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
        init(group) {
            const that = this
            if (group && group.id) {
                // 加载书籍
            }
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

    }

}

.ant-empty {
    height: 100%;
    .ant-empty-image {
        height: 100%;
    }
}


</style>
