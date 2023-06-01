<script setup lang="ts">
import {onMounted, reactive} from "vue";
import {greet} from '@/utils/Controller'

const initData = reactive({})


onMounted(() => {
  init()
})

const init = async () => {
  const res = await greet()
}

defineExpose({
  init
})
</script>

<template>
  <div>本地节点</div>
</template>

<style scoped lang="">

</style>
