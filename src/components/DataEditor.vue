<script setup lang="ts">

import {computed, ref, watch} from "vue";
import {NodeSourceType, TypeInfo} from "@/utils/Models";
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
    type: [String, Number, Boolean],
    required: true,
    default: '',
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
    type: Array<any>,
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
  },
  handle: {
    type: Function,
    required: false,
    default: (v: any) => v
  },
  callback: {
    type: Function,
    required: false,
    default: (v: any) => v
  }
})

const emits = defineEmits(["input", "update:modelValue", "onChange", 'onBlur', 'onForce'])

const internalValue = ref(props.modelValue);

const labelValue = computed(
    () => {
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
  emits('update:modelValue', e); // 触发内部的 v-model 更新事件
  emits('onChange', e); // 触发自定义的 change 事件

}

const handleBlue = (e: any) => {
  emits('onBlur', e)
}

const handleForce = (e: any) => {
  emits('onForce', e)
}

</script>

<template>
  <el-form-item :label="labelValue" :prop="name" :rules="rules">
    <el-row style="width: 100%">
      <el-col :span="20" style="text-align: left">

        <el-input type="textarea" style="width: 100%"
                  v-if="type === 'text'" v-bind="$attrs"
                  :placeholder="placeholder"
                  :disabled="disabled" @focus="handleForce" @blur="handleBlue"
                  v-model="internalValue" @input="handleInput"/>

        <el-input v-if="type === 'string'" v-bind="$attrs"
                  v-model="internalValue" @input="handleInput"
                  :disabled="disabled" @focus="handleForce" @blur="handleBlue"
                  :placeholder="placeholder"/>

        <el-input-number v-if="type === 'number'"
                         v-bind="$attrs" style="width: 100%;"
                         v-model="internalValue" @input="handleInput"
                         :disabled="disabled"
                         :max="9999" :min="1" @focus="handleForce" @blur="handleBlue"
                         :placeholder="placeholder"/>

        <el-select v-if="type === 'select'"
                   v-bind="$attrs"
                   :placeholder="placeholder" @focus="handleForce" @blur="handleBlue"
                   :disabled="disabled" style="width: 100%;"
                   v-model="internalValue" @change="handleChange">
          <el-option
              v-for="item in options"
              :key="item.name"
              :label="item.label"
              :value="item.name"/>
        </el-select>

        <el-switch v-if="type === 'switch'"
                   v-bind="$attrs"
                   :disabled="disabled"
                   v-model="internalValue"
                   @focus="handleForce" @blur="handleBlue"
                   @change="handleChange"/>

      </el-col>

      <el-col :span="1" :offset="1" v-show="help">
        <el-popover
            placement="left-end"
            :title="label"
            width="500"
            trigger="click">
          <template #reference>
            <el-icon>
              <QuestionFilled/>
            </el-icon>
          </template>
          <div style="overflow: scroll">
            <pre>{{ help }}</pre>
          </div>
        </el-popover>
      </el-col>

    </el-row>
  </el-form-item>
</template>

<style scoped lang="less">

</style>
