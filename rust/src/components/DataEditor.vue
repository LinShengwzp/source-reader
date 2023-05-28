<script setup lang="ts">

import {computed, ref, watch} from "vue";
import {TypeInfo} from "@/utils/Models";
import {QuestionFilled} from "@element-plus/icons-vue";

const props = defineProps({
  type: {
    type: String,
    required: true,
    default: 'text',
    validator: (value: string) => {
      return ['text', 'string', 'number', 'select', 'select', 'select', 'switch'].includes(value)
    }
  },
  modelValue: {
    type: [String, Number, Boolean, Object],
    required: true,
  },
  name: {
    type: String,
    required: true,
    default: "name",
  },
  label: {
    type: String,
    required: false,
  },
  icon: {
    type: String,
    required: false
  },
  placeholder: {
    type: String,
    required: false,
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

const emits = defineEmits(["input", "update:modelValue", "onChange"])

const internalValue = ref(props.modelValue);


const labelValue = computed(
    () => {
      console.log(props.label, props.name)
      return props.label || props.name
    }
)

// 监听外部传入的 modelValue 变化
watch(
    () => props.modelValue,
    (newValue) => {
      internalValue.value = newValue;
    }
);

const handleInput = (value: any) => {
  internalValue.value = value;
  emits('update:modelValue', value); // 触发内部的 v-model 更新事件
  emits('input', value); // 触发内部的 v-model 更新事件
};

const handleChange = (e: any) => {
  emits('onChange', e); // 触发自定义的 change 事件
}

</script>

<template>
  <el-form-item :label="labelValue" :prop="name" :rules="rules">
    <el-row style="width: 100%">
      <el-col :span="20">

        <el-input type="textarea" style="width: 100%"
                  v-if="type === 'text'" v-bind="$attrs"
                  :placeholder="placeholder"
                  :disabled="disabled"
                  v-model="internalValue" @input="handleInput"/>

        <el-input v-if="type === 'string'" v-bind="$attrs"
                  v-model="internalValue" @input="handleInput"
                  :disabled="disabled"
                  :placeholder="placeholder"/>
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
