# source-reader

## 📚 文档
- [教程文档](https://www.yuque.com/u34495/mivcfg)

## 安装

### 环境准备

+ node >= 14
+ python
+ windows build tool
+ vs

### [开发](https://www.yuque.com/u34495/mivcfg/ltgte9)

1. 镜像加速

```shell
# 优先使用npm, yarn/pnpm/cnpm等可能出现包安装不完整。

# 设置国内镜像源(加速)
npm config set registry=https://registry.npmmirror.com
npm config set disturl=https://registry.npmmirror.com/-/binary/node

#如果下载electron慢，配置如下（或者挂个VPN）
npm config set electron_mirror=https://registry.npmmirror.com/-/binary/electron/
```
2. electron 构建

```shell
# 进入目录 ./electron-egg/
npm install

# 构建sqlite
# - 需要 python3 环境 （操作系统自带）
# - 需要 node-gyp
npm i node-gyp -g
npm run re-sqlite

# 如果sqlite报错 ...tools之类的
npm --vs2015 i -g --production windows-build-tools
# 或者 
npm i -g --production windows-build-tools 
# 或者
npm config set msvs_version 2022
npm config set msbuild_path "C:\Program Files\Microsoft Visual Studio\2022\Professional\Msbuild\Current\Bin\MSBuild.exe"
```
3. 前端vue构建

```shell
cd ./frontend
npm install
```

4. 启动项目

```shell
# 运行
cd {root}
npm run start
```

5. 调试/热更新

修改 [config.default.js](electron/config/config.default.js)

```js
/**
* 开发者工具
*/
config.openDevTools = true;
```

请确保前端启动端口为 8080，否则请修改配置文件

```json
{
  "vue": {
    "hostname": "localhost",
    "port": 15000
  }
}
```
启动项目前后端

```shell
# 启动前端
cd ./frontend
npm run serve

# 启动后端
cd {root}
npm run reload
```


## [打包](https://www.yuque.com/u34495/mivcfg/fro580)

1. 打包前端

```shell
cd ./frontend
npm run build
```

2. 复制前端资源

```shell
cd {root}
npm run rd
# 将前端资源迁移到 /public/dist，如果没有这个文件夹需要新建

# 运行检查
npm run start
```
3. 构建

+ 加密步骤可略过
+ 可打包其他格式，详见 [package.json](package.json)

```shell
# 加密
npm run encrypt

npm config set electron_builder_binaries_mirror=https://registry.npmmirror.com/-/binary/electron-builder-binaries/

npm run build-wz 
```

## 功能

1. [ ] 爱阅书香功能
   1. [x] 书源文件解析(解析工具 [xbsrebuild](https://github.com/ne1llee/xbsrebuild.git))
   2. [x] 书源节点编辑
   3. [x] 书源本地存储
   4. [ ] 书源节点调试
