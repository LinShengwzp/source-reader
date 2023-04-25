<template>
    <a-modal v-model="showModal" :title="title" width="90%" @ok="save" okText="保存" cancelText="取消">
        <a-tabs :activeKey="activateTab" default-active-key="classify_1" type="editable-card" @edit="handleEditTab"
                @change="handleChangeTab">
            <a-tab-pane v-for="pane in tabList" :key="pane.key" :tab="pane.title" :closable="pane.closable">
                <a-form
                        :model="pane.content"
                        :name="`dataForm_${pane.key}`"
                        :label-col="{ span: 6 }"
                        :wrapper-col="{ span: 18 }"
                        autocomplete="off">
                    <a-row v-for="group in formGroups" :key="group.title">
                        <a-divider orientation="center">{{ group.title }}</a-divider>
                        <a-timeline class="timeline-tips" v-if="group.tips && group.tips.length > 0">
                            <a-timeline-item v-for="(tip, index) in group.tips" :key="index">{{ tip }}</a-timeline-item>
                        </a-timeline>

                        <a-col :span="20" v-for="item in group.items" :key="item.model">
                            <editor-area :type="item.type"
                                         :data.sync="pane.content[item.model]"
                                         :label="item.label"
                                         :name="item.name"
                                         :options="item.options"
                                         :placeholder="item.placeholder"
                                         :disabled="item.disabled"
                                         :help="item.help"
                                         :rules="item.rules"></editor-area>
                        </a-col>
                    </a-row>
                </a-form>
            </a-tab-pane>
        </a-tabs>

        <a-modal
                v-model="showAddTabName" title="输入新的分组名称" okText="确认" cancelText="取消" centered @ok="addTab">
            <a-row>
                <a-col :span="20" :offset="2">
                    <a-input v-model="addTabName" placeholder="分组名称"/>
                </a-col>
            </a-row>
        </a-modal>

        <a-modal
                v-model="showDelTabGroup" title="确认删除分组" okText="确认" cancelText="取消" centered @ok="removeTab">
            <a-alert
                    message="是否确认删除分组"
                    description="删除分组后该分组数据不能恢复"
                    type="warning"
                    show-icon
            />
        </a-modal>

    </a-modal>
</template>

<script>
import {parseJson, stringifyJson} from "@/utils/analyse/StrUtil";
import EditorArea from "@/components/EditorArea.vue";

export default {
    name: "GroupEditor",
    components: {EditorArea},
    data() {
        return {
            tabList: [],
            activateTab: 'classify_1',
            title: '',
            action: '',
            showModal: false,
            formGroups: [],
            showAddTabName: false,
            showDelTabGroup: false,
            addTabName: '',
            removeTabKey: '',
        }
    },
    methods: {
        init(groupForm, data) {
            const that = this

            if (!groupForm || !groupForm.action || !data) {
                return;
            }
            that.$nextTick(() => {
                const {title, action, formGroups} = groupForm
                that.title = title;
                that.action = action;
                that.formGroups = {...formGroups}; // 拷贝

                // 处理data
                that.tabList = []
                let defaultTab = false
                for (const key in data) {
                    const dataItem = stringifyJson(data[key], ['httpHeaders', 'moreKeys'])
                    that.tabList.push({
                        title: key,
                        content: dataItem,
                        key: `classify_${key}`,
                    })
                    if (!defaultTab) {
                        that.activateTab = `classify_${key}`
                        defaultTab = true
                    }
                }

                // 处理formItem
                // 处理formItem
                that.formGroups = formGroups.map(group => {
                    if (!group || !group.title) {
                        return null
                    }
                    // 处理表单项
                    if (group.items && group.items.length >= 0) {
                        group.items = group.items.map(item => {
                            if (!item.model) {
                                return null
                            }

                            if (item.type === 'select') {
                                if (!item.options || item.options.length <= 0) {
                                    return null
                                }
                            }

                            return {
                                ...{
                                    type: 'string',
                                    label: item.model,
                                    name: item.model,
                                    placeholder: item.label || item.model,
                                    disabled: false,
                                    options: [],
                                    rules: []
                                }, ...item
                            }
                        }).filter(i => i)
                    }
                    return group
                }).filter(i => i)
                console.log("current editor", that.action, that.formGroups, that.tabList)
                that.showModal = true
            })
        },
        save() {
            const that = this
            let submit = {}
            const parseKeys = ['httpHeaders', 'moreKeys']
            that.tabList.forEach(tab => {
                // 拷贝问题
                submit[tab.title] = parseJson({...tab['content']}, parseKeys)
            })
            that.$emit('handleSaveConfig', submit, that.action)
            that.showModal = false
        },
        handleChangeTab(activeKey) {
            const that = this
            that.$nextTick(() => {
                that.addTabName = ''
                that.removeTabKey = ''
                that.activateTab = activeKey
            })
        },
        addTab() {
            const that = this
            const panes = that.tabList;
            if (that.addTabName) {
                console.log("add new group", that.addTabName)

                let exist = that.tabList.filter(pane => pane.key === `classify_${that.addTabName}`);
                if (exist && exist.length > 0) {
                    this.$message.error('当前分组已存在');
                    return
                }

                const activeKey = `classify_${that.addTabName}`;
                panes.push({
                    title: that.addTabName, content: {
                        actionID: that.action,
                        parserID: "DOM",
                        _sIndex: that.tabList.length
                    }, key: activeKey
                });

                // 回设
                that.$nextTick(() => {
                    that.tabList = panes;
                    that.showAddTabName = false;
                    that.handleChangeTab(activeKey)
                })
            }
        },
        removeTab() {
            const that = this
            let newList = that.tabList.filter(pane => pane.key !== that.removeTabKey);
            // 回设
            that.$nextTick(() => {
                // 移除分组
                that.tabList = [...newList];
                console.log("remove group", that.removeTabKey, that.tabList)
                that.showDelTabGroup = false;
                if (that.tabList && that.tabList.length > 0) {
                    that.handleChangeTab(that.tabList[0].key)
                }
            })
        },
        handleEditTab(targetKey, action) {
            const that = this
            switch (action) {
                case 'add':
                    that.showAddTabName = true
                    break;
                case 'remove':
                    that.removeTabKey = targetKey;
                    that.showDelTabGroup = true
                    break
                default:
                    break
            }
        }
    }
}
</script>

<style scoped>

</style>
