<template>
    <a-form-item
            :label="label"
            :name="name"
            :rules="{rules}">
        <a-row>
            <a-col :span="20">
                <a-textarea v-if="type === 'text'"
                            :placeholder="placeholder"
                            :disabled="disabled"
                            v-model="model" @input="childInputChange"/>

                <a-input v-if="type === 'string'"
                         :placeholder="placeholder"
                         :disabled="disabled"
                         v-model="model" @input="childInputChange"/>

                <a-input-number v-if="type === 'number'" style="width: 100%;"
                                :placeholder="placeholder"
                                :disabled="disabled"
                                v-model="model" @input="childInputChange"/>

                <a-select v-if="type === 'select'"
                          :placeholder="placeholder"
                          :disabled="disabled"
                          v-model="model" @change="childInputChange">
                    <a-select-option v-for="option in options" :key="option.name" :value="option.name">
                        {{ option.label }}
                    </a-select-option>
                </a-select>

                <a-date-picker v-if="type === 'time'" format="YYYY-MM-DD HH:mm:ss" disabled
                               :show-time="{ defaultValue: moment('00:00:00', 'HH:mm:ss') }"/>

                <a-switch v-if="type === 'switch'"
                          :disabled="disabled"
                          v-model="model"
                          @change="childInputChange"/>
            </a-col>
            <a-col :span="1" :offset="1" v-show="help">
                <a-popover :title="label" placement="leftTop">
                    <template slot="content">
                        <pre>{{ help }}</pre>
                    </template>
                    <a-icon type="question-circle"/>
                </a-popover>
            </a-col>
        </a-row>
    </a-form-item>
</template>

<script>
export default {
    name: "EditorArea",
    props: {
        type: {
            type: String,
            require: true,
            default: () => 'text'
        },
        data: {
            type: String | Number | Boolean,
            require: true
        },
        label: {
            type: String,
            require: true,
            default: () => "label",
        },
        name: {
            type: String,
            require: true,
            default: () => "name",
        },
        placeholder: {
            type: String,
            require: false,
        },
        disabled: {
            type: Boolean,
            require: false,
            default: () => false
        },
        rules: {
            type: Array,
            require: false,
            default: () => []
        },
        options: {
            type: Array,
            require: false,
            default: () => [{value: "key", label: "请选择"}]
        },
        help: {
            type: String,
            require: false,
            default: () => ''
        }
    },
    watch: {
        data() {
            this.model = this.data
        }
    },
    data() {
        return {
            showHelp: false,
            model: this.data// 关联值
        }
    },
    methods: {
        childInputChange(e, v, a) {
            // 通过$emit触发childValueChange（model内定义）事件，将内部值传递给给父组件
            this.$emit('update:data', this.model) // 触发update:data将子组件值传递给父组件
        }
    }
}
</script>

<style scoped>
</style>
