import { createRouter, createWebHistory, RouteRecordRaw } from 'vue-router'

const routes: Array<RouteRecordRaw> = [
    {
        path: '/',
        name: 'main',
        alias: ['/main','/index'],   // 别名，可以定义很多个
        children: [
            {
                path: '/novels',
                name: 'novels',
                component: () => import('@/views/novels/Index.vue')
            },
            {
                path: '/nodes',
                name: 'nodes',
                component: () => import('@/views/nodes/Index.vue')
            },
            {
                path: '/discover',
                name: 'discover',
                component: () => import('@/views/discover/Index.vue')
            },
            {
                path: '/mine',
                name: 'mine',
                component: () => import('@/views/mine/Index.vue')
            },
            {
                path: '/setting',
                name: 'setting',
                component: () => import('@/views/setting/Index.vue')
            }
        ]
    },
]

const router = createRouter({
    history: createWebHistory(),
    routes
})

export default router
