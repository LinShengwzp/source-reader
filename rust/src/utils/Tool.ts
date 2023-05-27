import type { App, Plugin } from 'vue'


// 全局组件安装
export const withInstall = <T>(component: T, alias?: string) => {
	const comp = component as any
	comp.install = (app: App) => {
		// @ts-ignore
		app.component(comp.name || comp.displayName, component)
		if (alias) {
			app.config.globalProperties[alias] = component
		}
	}
	return component as T & Plugin
}
