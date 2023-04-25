<template>
    <a-spin :spinning="loading" tip="加载中..." style="height: 100%">
        <div id="app-bookshelf" class="bookshelf-container">
            <a-card size="small" title="我的书架" class="card-container">
                <template #extra><a href="#" @click="handleClean">清空</a></template>
                <a-row>
                    <a-row v-show="bookData.completed" class="node-container">
                        <a-col :span="4" class="list-container">
                            <a-row class="menu-list">
                                <a-col :span="24">
                                    <ul>
                                        <li v-for="item in bookData.bookGroup" :key="item.id"
                                            @click="handleGroupClick(item)"
                                            :class="['data-item-menu node-item', {'item-select': item.id === menuModel}]">
                                            {{ item.shelfName }}
                                        </li>
                                    </ul>
                                </a-col>
                            </a-row>
                        </a-col>
                        <a-col :span="18" class="modify-container">
                            <a-spin :spinning="contentLoading" tip="加载中..." style="height: 100%;width: 100%">
                            </a-spin>
                        </a-col>
                    </a-row>
                </a-row>
            </a-card>
        </div>

        <a-modal v-model="groupConfig.showGroupConfigModal" title="管理分组"
                 okText="确认" cancelText="取消" centered
                 @ok="handleConfirmGroupConfig">
            <a-row>
                <a-col :span="20" :offset="2">
<!--                    <a-input v-model="addNodeName" placeholder="节点名称"/>-->
                </a-col>
            </a-row>
        </a-modal>

    </a-spin>
</template>
<script>
export default {
    data() {
        return {
            loading: false,
            menuModel: '', // 选中分组
            contentLoading: true,
            bookData: {
                completed: true,
                bookGroup: [{
                    id: 'groupConfig',
                    shelfName: '管理分组'
                }], // 书籍分组

            },
            groupConfig: {
                showGroupConfigModal: false,
            }
        };
    },
    methods: {
        /**
         * 初始化
         */
        init() {

        },
        /**
         * 数据重置
         */
        handleClean() {
            const that = this
            that.loading = false;
        },
        /**
         * 点击选中分组
         * @param group
         */
        handleGroupClick(group) {
            const that = this
            switch (group.id) {
                case 'groupConfig':
                    that.groupConfig.showGroupConfigModal = true;
                default:
                    that.menuModel = group.id
                    break
            }
        },
        /**
         * 确认分组
         */
        handleConfirmGroupConfig() {

        }
    }
};
</script>
<style lang="less" scoped>
#app-bookshelf {
  padding: 10px 10px;
  text-align: left;
  width: 100%;

  .card-container {
    width: 100%;
    height: 100%;
    position: relative;

    .node-container {
      position: relative;
      margin-top: 10px;

      .list-container {
        position: absolute;
        height: 100%;
        overflow-y: scroll;

        .menu-list {
          overflow-y: scroll;

          ul {
            list-style: none;
            padding: 0;
          }

          .data-item-menu {
            text-align: center;
            cursor: pointer;
          }

          .data-item-menu:hover {
            color: #07C160;
          }

          .item-select {
            background-color: #e6ffee;
            color: #07C160;
          }

          .node-item {
            height: 40px;
            line-height: 40px;
            overflow-x: hidden;
            white-space: nowrap;
            text-overflow: ellipsis;
            display: -webkit-box;
            -webkit-box-orient: vertical;
            -webkit-line-clamp: 3;
          }

        }
      }

      .modify-container {
        margin-left: 20%;
        min-height: 1080px;
      }
    }

  }
}
</style>
