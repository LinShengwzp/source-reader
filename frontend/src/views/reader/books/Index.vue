<template>
    <a-spin :spinning="loading" tip="加载中..." style="height: 100%">
        <div id="app-bookshelf" class="bookshelf-container">
            <a-card size="small" title="我的书架" class="card-container">
                <template #extra><a href="#" @click="handleClean">清空</a></template>
                <a-row v-show="bookData.completed" class="node-container">

                    <a-col :span="4" class="list-container">
                        <a-row class="menu-list">
                            <a-col :span="24">
                                <ul>
                                    <li v-for="item in bookData.bookGroup" :key="item.id"
                                        @click="handleGroupClick(item)"
                                        :class="['data-item-menu node-item', {'item-select': item.id === menuModel}]">
                                        {{ item.groupName }}
                                    </li>

                                    <li @click="handleGroupClick({id: 'groupConfig'})"
                                        :class="['data-item-menu node-item', {'item-select': 'groupConfig' === menuModel}]">
                                        管理分组
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

            </a-card>
            <a-modal v-model="groupConfig.showGroupConfigModal" width="70%" title="管理分组"
                     okText="确认" cancelText="取消" centered class="card-container">
                <a-row class="node-container">
                    <a-col :span="6" class="list-container">
                        <a-row class="menu-list">
                            <ul class="ul-container">
                                <li v-for="item in bookData.bookGroup" :key="item.id"
                                    @click="handleGroupItemClick(item)"
                                    :class="['data-item-menu node-item', {'item-select': item.id === menuModel}]">
                                    {{ item.groupName }}
                                </li>
                                <li @click="handleGroupItemClick('addGroup')"
                                    :class="['data-item-menu node-item', {'item-select': 'addGroup' === menuModel}]">
                                    添加分组
                                </li>
                            </ul>
                        </a-row>
                    </a-col>
                    <a-col :span="18">
                        <a-form :model="groupConfig.groupData"
                                name="groupForm" ref="groupForm"
                                :label-col="{ span: 4 }"
                                :wrapper-col="{ span: 20 }"
                                autocomplete="off">

                            <editor-area v-for="item in groupConfig.modifyGroupForm"
                                         :key="item.model"
                                         :type="item.type"
                                         :data.sync="groupConfig.groupData[item.model]"
                                         :label="item.label"
                                         :name="item.name"
                                         :options="item.options"
                                         :placeholder="item.placeholder"
                                         :disabled="item.disabled"
                                         :help="item.help"
                                         :rules="item.rules"></editor-area>
                        </a-form>
                    </a-col>
                </a-row>

                <template slot="footer">
                    <a-button key="back" @click="groupConfig.showGroupConfigModal = false">
                        取消
                    </a-button>
                    <a-button key="clean" type="danger" @click="handleRemoveGroup">
                        删除
                    </a-button>
                    <a-button key="submit" type="primary" @click="handleConfirmGroupConfig">
                        保存
                    </a-button>
                </template>

            </a-modal>
        </div>
    </a-spin>
</template>
<script>
import EditorArea from "@/components/EditorArea.vue";
import {ipcApiRoute} from "@/api/main";

export default {
    components: {EditorArea},
    data() {
        const groupName = {
            type: 'string',
            label: '分组名称',
            model: 'groupName',
            name: 'groupName',
            rules: [{required: true, message: '分组名称不能为空!'}]
        };
        const sourceType = {
            type: 'string',
            label: '分组类型',
            model: 'sourceType',
        };
        const enable = {
            type: 'switch',
            label: '是否可用',
            model: 'enable',
        };
        const sort = {
            type: 'number',
            label: '排序',
            model: 'sort',
        };
        return {
            loading: false,
            menuModel: '', // 选中分组
            contentLoading: true,
            bookData: {
                completed: true,
                bookGroup: [], // 书籍分组
            },
            groupConfig: {
                showGroupConfigModal: false,
                modifyGroupForm: [groupName, sourceType, enable, sort],
                groupData: {} // 存储分组编辑表单
            },
            groupForm: {}, // 表单，校验用
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
                    that.menuModel = 'groupConfig'
                    that.handleModifyGroupClick()
                    break
                default:
                    that.menuModel = group.id
                    break
            }
        },
        /**
         * 确认分组
         */
        async handleConfirmGroupConfig() {
            const that = this
            const submit = that.groupConfig.groupData
            that.groupForm.validateFields(async err => {
                if (!err) {
                    const res = await that.$ipc.invoke(ipcApiRoute.bookGroupOperation, {
                        action: 'saveOrUpdate',
                        data: that.groupConfig.groupData
                    })
                    if (res && res.code === 200) {
                        that.$message.success("操作成功")
                        that.handleModifyGroupClick()
                    }
                } else {
                    console.info(err);
                }
            });
        },
        /**
         * 打开分组编辑
         */
        async handleModifyGroupClick() {
            const that = this
            // 加载分组
            const res = await that.$ipc.invoke(ipcApiRoute.bookGroupOperation, {
                action: 'get',
                data: {
                    sort: {
                        query: false,
                        sort: 'asc'
                    }
                }
            })
            if (res.code === 200) {
                that.bookData.bookGroup = res.result
                that.groupForm = that.$form.createForm(this, {name: 'groupForm'})
                that.groupConfig.showGroupConfigModal = true
                if (res.result && res.result.length > 0) {
                    that.handleGroupItemClick(res.result[0])
                }
            }
        },
        /**
         * 弹窗中点击/编辑分组
         */
        handleGroupItemClick(item) {
            const that = this
            const type = typeof item
            let data = item
            let menuModel = ''
            if (type === 'string') {
                switch (item) {
                    case 'addGroup': {
                        menuModel = 'addGroup'
                        data = {
                            platform: 'StandarReader',
                            sourceType: 'text',
                            enable: true,
                            sort: that.bookData.bookGroup.length
                        }
                        break
                    }
                }
            }

            that.$nextTick(() => {
                that.menuModel = menuModel || data.id
                that.groupConfig.groupData = data
            })

        },
        async handleRemoveGroup() {
            const that = this
            if (that.groupConfig.groupData && that.groupConfig.groupData.id) {
                const res = await that.$ipc.invoke(ipcApiRoute.bookGroupOperation, {
                    action: 'del',
                    data: that.groupConfig.groupData
                })
                if (res && res.code === 200) {
                    that.$message.success("操作成功")
                    that.handleModifyGroupClick()
                }
            }
        }
    }
};
</script>
<style lang="less" scoped>
#app-bookshelf {
  padding: 10px 10px;
  text-align: left;
  width: 100%;

}

.card-container {
  width: 100%;
  height: 100%;
  position: relative;

  .node-container {
    position: relative;
    margin-top: 10px;

    .list-container {
      height: 100%;
      overflow-y: scroll;

      .menu-list {
        overflow-y: scroll;

        ul {
          list-style: none;
          padding: 0;
        }

        .ul-container {
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
</style>
