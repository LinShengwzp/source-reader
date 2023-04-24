<template>
    <a-modal v-model="showModal" :title="title" width="90%" @ok="save" okText="保存" cancelText="取消">
        <a-form
                :model="dataForm"
                ref="dataForm"
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
                                 :data.sync="dataForm[item.model]"
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
    </a-modal>
</template>

<script>

import EditorArea from "@/components/EditorArea.vue";
import {parseJson, stringifyJson} from "@/utils/analyse/StrUtil";

export default {
    name: "DetailEditor",
    components: {
        EditorArea
    },
    data() {
        return {
            title: '',
            action: '',
            showModal: false,
            dataForm: {},
            formGroups: []
        }
    },
    methods: {
        init(detailForm, data) {
            const that = this
            if (!detailForm || !detailForm.action || !data) {
                return;
            }
            that.$nextTick(() => {
                const {title, action, formGroups} = detailForm
                that.title = title;
                that.action = action;
                that.formGroups = {...formGroups}; // 拷贝

                // 处理data
                that.dataForm = stringifyJson(data, ['requestInfo', 'httpHeaders', 'list', 'moreKeys'])
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
                console.log("current editor", that.formGroups, that.dataForm)
                that.showModal = true
            })
        },
        save() {
            const that = this
            // 数据压缩
            const parseKeys = ['httpHeaders', 'moreKeys']
            that.$emit('handleSaveConfig', parseJson({...that.dataForm}, parseKeys), that.action)
            that.showModal = false
        }
    }
}
</script>

<style scoped>

</style>
