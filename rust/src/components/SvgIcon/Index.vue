<template>
	<div class="svg-icon">
		<svg :class="`${className}`" :style="`color:${color};`" aria-hidden="true">
			<use :xlink:href="iconName" />
		</svg>
	</div>
</template>

<script setup lang="ts" name="SvgIcon">
import { computed } from 'vue'

const props = defineProps({
	icon: {
		type: String,
		required: true
	},
	color: {
		type: String,
		default: ''
	},
	className: {
		type: String,
		default: ''
	}
})

const iconName = computed(() => `#icon-${props.icon.replace('icon-', '')}`)
</script>

<style scoped>
.svg-icon svg {
	width: 3em;
	height: 3em;
	vertical-align: -0.15em;
	fill: currentColor;
	overflow: hidden;
	flex-shrink: 0;
}
</style>
