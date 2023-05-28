<script setup lang="ts">

import {TypeInfo} from "@/utils/Models";
import {QuestionFilled} from "@element-plus/icons-vue";
import {ref, watch} from "vue";

const props = defineProps({
  type: {
    type: String,
    required: true,
    default: 'text',
    validator: (value: string) => {
      return ['text', 'string', 'number', 'select', 'select', 'select', 'switch'].includes(value)
    }
  },
  icon: {
    type: String,
    required: false
  },
  modelValue: {
    type: [String, Number, Boolean, Object],
    required: true,
  },
  label: {
    type: String,
    required: true,
    default: "label",
  },
  name: {
    type: String,
    required: true,
    default: "name",
  },
  placeholder: {
    type: String,
    required: false,
  },
  clearable: {
    type: Boolean,
    required: false,
    default: true
  },
  disabled: {
    type: Boolean,
    required: false,
    default: false
  },
  rules: {
    type: Array,
    required: false,
    default: []
  },
  options: {
    type: Array<TypeInfo>,
    required: false,
    default: [{name: "key", label: "请选择"}]
  },
  help: {
    type: String,
    required: false,
    default: ''
  }
})

const emits = defineEmits(['update:modelValue'])

const value = ref(props.modelValue);

// 监听父组件传入的 modelValue 的变化
watch(
    () => props.modelValue,
    (newValue) => {
      value.value = newValue;
    }
);

// 更新值并触发事件通知父组件
const updateValue = (newValue: string | boolean | number | undefined) => {
  value.value = newValue;
  emits('update:modelValue', newValue);
};
</script>

<template>
  <el-form-item :label="label" :prop="name" :rules="rules">
    <el-row>
      <el-col :span="20">
        <el-input type="textarea" style="width: 100%"
                  v-if="type === 'text'"
                  :placeholder="placeholder"
                  :disabled="disabled"
                  :clearable="clearable"
                  :value="modelValue" @input="updateValue"/>

        <el-input v-if="type === 'string'"
                  :placeholder="placeholder"
                  :disabled="disabled" clearable
                  :value="modelValue" @input="updateValue"/>

        <el-input-number v-if="type === 'number'" style="width: 100%;"
                         :placeholder="placeholder"
                         :disabled="disabled"
                         :clearable="clearable"
                         :value="modelValue" @input="updateValue"/>

        <el-select v-if="type === 'select'"
                   :placeholder="placeholder"
                   :disabled="disabled"
                   :clearable="clearable"
                   :value="modelValue" @change="updateValue($event.target.value)">
          <el-option v-for="option in options" :key="option.name" :value="option.name">
            {{ option.label }}
          </el-option>
        </el-select>

        <el-switch v-if="type === 'switch'"
                   :disabled="disabled"
                   :value="modelValue"
                   :clearable="clearable"
                   @change="updateValue($event.target.value)"/>
      </el-col>

      <el-col :span="1" :offset="1" v-show="help">
        <el-popover
            placement="top-end"
            :title="label"
            trigger="hover">
          <template #reference>
            <el-icon>
              <QuestionFilled/>
            </el-icon>
          </template>
          <pre>{{ help }}</pre>
        </el-popover>
      </el-col>
    </el-row>
  </el-form-item>
</template>

<style scoped lang="less">

</style>
