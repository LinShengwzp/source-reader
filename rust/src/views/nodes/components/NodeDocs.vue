<script setup lang="ts">


import {reactive} from "vue";

const initData = reactive({
  text: `
#### js教程：https://www.w3school.com.cn/js/index.asp
#### xpath教程：https://www.w3school.com.cn/xpath/index.asp
#### config, params, result为预定义参数名，请不要再使用这个三个名称，善用logWithKey打印数据，你将发现新世界

### ////////////////////////////////////////////////////////////////////////////
### 香色闺阁使用xpath和js来解析书源，分为两步：第一步获取请求信息，第二步解析响应。

#### 一. 获取请求信息，有两种方式，任选一个
\t1. 使用url：search.php?searchkey=%@keyWord&page=%@pageIndex&offset=%@offset&filter=%@filter
\t2. 使用js获取请求信息，需使用@js:声明，js参数有config, params, result，返回结果为请求信息，可以直接返回url，也可以返回对象
\t   参数config：对象类型，包含所有配置信息
\t   参数params：keyWord,pageIndex,offset,filter,filters,queryInfo,lastResponse(有下一页地址或在response中声明autoRequestMore),responseUrl,responseHeaders
\t   参数result：上一级获取的url
\t   返回结果：可直接返回url，也可返回对象{url,POST,httpParams,httpHeaders,forbidCookie,requestParamsEncode,responseFormatType,cacheTime,tryCount,response}，注意请求时可直接返回response，如果无需网络请求。sourceRegex用于嗅探音/视频资源，例如使用'.*\\\\.(mp3|m4a).*'，将返回第一个mp3或m4a文件url，注意反斜杠需转义符，也可以使用/.*\\.(mp3|m4a).*/.toString()返回正则表达式
\t   返回结果示例：
\t\t\t{
\t\t\t'url':'https://www.baidu.com',
\t\t\t'POST':false,
\t\t\t'httpParams':{'key':'value'},
\t\t\t'httpHeaders':{'UserAgent':'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/72.0.3626.121 Safari/537.36'},
\t\t\t'forbidCookie':false,
\t\t\t'requestParamsEncode':'',
\t\t\t'responseFormatType':'json',
\t\t\t'cacheTime':3600,
\t\t\t'tryCount':1,
\t\t\t"webView":'',
\t\t\t'webViewJs':'document.documentElement.outerHTML',
\t\t\t'webViewSkipUrls':['https://www.baidu.com'],
\t\t\t'sourceRegex':'.*\\\\.(mp3|m4a).*'
\t\t\t}


#### 二. 解析响应，也有两种方式，任选一个
\t1. 使用规则解析响应，可使用xpath/jsonpath/js，有多个规则时使用'||'，js必须放在最后，示例：//a/@href || @js: return '返回结果';
\t2. 使用js解析响应，编写完整的js函数：function functionName(config, params, result) {return '解析结果';}
\t   书本详情配置可直接返回bookInfo
\t   章节内容配置可直接返回content，也可以在字典中返回content，如{'content':content}
\t   其他包含列表的配置都必须使用list返回结果，如{'list':list}
\t   响应参数类型：
\t\tcontent(str)
\t\tlist(arr)
\t\tmore(bool)
\t\tmaxPage(int)
\t\tremoveHtmlKeys(string/arr)
\t\tautoRequestMore(bool，success/more为true时生效，异步自动再请求，章节内容分页请求内部就是通过这个实现)
\t\tsendResponseOnRequest(bool)
\t\tsuccess(bool)
\t\terror(string)


### ///////////////////////////////////////////////////////////////////////
### 示例一，使用xpath解析，建议有电脑和iPad辅助，目标为笔趣阁https://www.xbiquwx.la

#### 第一步，创建书源
\t1.在名称中输入“笔趣阁测试”，首页中输入“https://www.xbiquwx.la”，权重输入10000(置顶，方便下次打开)，需要注意的是首页在此处可当作host用，且可以在config.host中获取

#### 第二步，配置书籍搜索
\t1. 响应解析方式选择“HTML(格式化为DOM)”
\t2. 请求信息中输入“https://www.xbiquwx.la/modules/article/search.php?searchkey=%@keyWord”\t\t注：keyWord将被替换成经过url编码的搜索词
\t3. 列表的xpath路径：//table[@class='grid']//tr
\t4. 书名：//td[1]/a
\t5. 作者：//td[3]
\t6. 状态：//td[6]
\t7. 字数：//td[4]
\t8. 最后一章标题：//td[2]/a
\t9. 书本详情页地址：//td[1]/a/@href
\t10. 测试请求，可修改参数试试

#### 第三步，配置书本详情(可不用)
\t1. 响应解析方式选择“HTML(格式化为DOM)”
\t2. 请求信息无需输入，会自动从上一层获取detailUrl，也可以输入%@result，或%@js return result;
\t3. 书名：//meta[@property='og:novel:book_name']/@content
\t4. 作者：//meta[@property='og:novel:author']/@content
\t5. 图标：//meta[@property='og:image']/@content
\t6. 简介：//meta[@property='og:description']/@content
\t7. 测试

#### 第四步，配置章节列表
\t1. 响应解析方式选择“HTML(格式化为DOM)”
\t2. 最后一章更新时间：//div[@id='maininfo']/div[1]\t注：只要包含完整时间即可，会自动格式化时间
\t3. 列表：//div[@id='list']/dl/dd
\t4. 标题：//a
\t5. 下一级界面地址，注意此处的detailUrl，对应测试界面“参数”：//a/@href || %@js return params.queryInfo.detailUrl + result;
\t6. 测试

#### 第五步，配置章节内容
\t1. 响应解析方式(responseFormatType)选择“HTML(格式化为DOM)”
\t2. 正文：//div[@id='content']/text()
\t3. 测试

#### 第六步，配置书籍分类
\t1. 添加一个分组，名称为“分类”
\t2. 响应解析方式(responseFormatType)选择“HTML(格式化为DOM)”
\t3. moreKeys中输入：{"pageSize":"30","requestFilters":{"玄幻":"1","科幻":"6","修真":"2","穿越":"4","网游":"5","都市":"3"}}\t注：最好使用JSON编辑器编辑好后再复制
\t4. 请求信息中输入：https://www.xbiquwx.la/list/%@filter_%@pageIndex.html
\t5. 列表：//div[@id='newscontent']/div[1]/ul/li
\t6. 书名：//span[2]/a
\t7. 作者：//span[4]
\t8. 最后一章标题：//span[3]/a
\t9. 书本详情页地址：//span[2]/a/@href
\t10. 测试


### ////////////////////////////////////////////////////////////////////
### 示例二，使用js解析，建议有电脑和iPad辅助，目标为笔趣阁https://www.xbiquwx.la

#### 第一步，创建书源
\t1. 在名称中输入“笔趣阁测试2”，首页中输入“https://www.xbiquwx.la”，权重输入10001(置顶，方便下次打开)，需要注意的是首页在此处可当作host用，且可以在config.host中获取

#### 第二步，配置书籍搜索
\t1. 响应解析方式选择“普通字符串”
\t2. 请求信息中输入：
\`\`\`
@js:
return 'https://www.xbiquwx.la/modules/article/search.php?searchkey=' + encodeURI(params.keyWord);
\`\`\`
\t3. 使用js手动解析响应中输入：
\`\`\`
function functionName(config, params, result)
{
\tlet list = [];
\tlet reg = /<td.*?odd.*?href="(.*?)">(.*?)<(?:\\S|\\s)*?even.*?<a.*?>(.*?)<(?:\\S|\\s)*?odd.*?>(.*?)</gim;

\twhile(tem=reg.exec(result))
\t{
\t\tlet bookInfo = {};
\t\tbookInfo.detailUrl = tem[1];
\t\tbookInfo.bookName = tem[2];
\t\tbookInfo.author = tem[4];
\t\tbookInfo.lastChapterTitle = tem[3];
\t\tlist.push(bookInfo);
\t}

\treturn {'list':list, 'more':false};
}
\`\`\`
\t4. 测试，可修改参数试试

#### 第三步，配置书本详情(可不用)
\t1. 响应解析方式选择“普通字符串”
\t2. 使用js手动解析响应中输入：
\`\`\`
function functionName(config, params, result)
{
\tlet reg = /og:title.*?="(.*?)"(?:\\S|\\s)*?og:description.*?="(.*?)"(?:\\S|\\s)*?og:image.*?="(.*?)"(?:\\S|\\s)*?og:novel:author.*?="(.*?)"/gim;
\tif(tem = reg.exec(result))
\t{
\t\tlet bookInfo = params.queryInfo;
\t\tbookInfo.desc = tem[2];
\t\tbookInfo.cover = tem[3];
\t\treturn {'response':bookInfo, 'removeHtmlKeys':'desc'};
\t}
\treturn undefined;
}
\`\`\`
\t3. 测试

#### 第四步，配置章节列表
\t1. 响应解析方式选择“普通字符串”
\t2. 使用js手动解析响应中输入：
\`\`\`
function functionName(config, params, result)
{
\tlet list = [];
\tlet reg = /<dd>(?:\\S|\\s)*?<a.*?href="(.*?)".*?title="(.*?)"/gim;

\twhile(tem = reg.exec(result))
\t{
\t\tlet chapterInfo = {};
\t\tchapterInfo.title = tem[2];
\t\tchapterInfo.url = params.queryInfo.detailUrl + tem[1];
\t\tlist.push(chapterInfo);
\t}

\treturn {'list':list};
}
\`\`\`
\t3. 测试

#### 第五步，配置章节内容
\t1. 响应解析方式选择“普通字符串”
\t2. 使用js手动解析响应中输入：
\`\`\`
function functionName(config, params, result)
{
\tlet beginStr = '<div id="content">';
\tlet beginIndex = result.indexOf(beginStr);
\tif(beginIndex>0)
\t{
\t\tlet subStr = result.substr(beginIndex + beginStr.length);
\t\tlet endIndex = subStr.indexOf('</div>');
\t\tlet tarStr = subStr.substr(0, endIndex);
\t\treturn {'response':tarStr, 'removeHtmlKeys':'response'};
\t}
\treturn undefined;
}
\`\`\`
\t3. 测试


### ////////////////////////////////////////////////////////////////////
\`\`\`
注意：
使用xpath规则解析内容，本质上是实现js解析，即最终返回的数据和js返回的数据是一样的，
使用js手动解析的时候，只需模仿xpath规则，如响应规则中的bookName/author/cover等等，js对应实现即可，
例如书单搜索配置，查看响应规则可知只有list/title/detail/cover/url，返回格式为：
let info = {'title':'书单名称', 'detail':'详情', 'cover':'http://www.baidu.com/xxx.jpg', 'url':'http://www.baidu.com/id10086'};
let list = [info];
return {'list':list};
\`\`\`

### ////////////////////////////////////////////////////////////////////
\`\`\`
moreKeys为预定义参数，json格式，优先级低于js，可使用的key有:requestFilters(下面详解), removeHtmlKeys(外部自动删除html的key，string/arr), skipCount(有list时跳过前面几个), pageSize(每页数量), maxPage(最大页数，默认1)
\`\`\`

\`\`\`
requestFilters为过滤器，主要用在书本分类中，用于筛选过滤内容，有两种方式：
第一种为示例一的书籍分类配置：{"玄幻":"1","科幻":"6","修真":"2","穿越":"4","网游":"5","都市":"3"}，在请求信息中通过%@filter获取当前选择value，也可以在js使用params.filter获取value。
第二种方式用在有多种类型key的情况，格式为array[object{key, item[object{title,value}]}]，把以下内容复制到json编辑器查看：
{"requestFilters":[{"key":"class","items":[{"title":"全部","value":""},{"title":"玄幻","value":"1"},{"title":"奇幻","value":"2"}]},{"key":"word","items":[{"title":"全部","value":""},{"title":"10万以下","value":"1"},{"title":"10万以上","value":"2"}]},{"key":"status","items":[{"title":"全部","value":""},{"title":"连载","value":"1"},{"title":"完本","value":"2"}]},{"key":"sort","items":[{"title":"综合","value":""},{"title":"字数","value":"word"},{"title":"评分","value":"score"}]}]}
使用时需使用js，通过params.filters.filters获取对应的key/value，如status对应的value：params.filters.filters.status
\`\`\`


### ////////////////////////////////////////////////////////////////////
\`\`\`
jsonpath有两种：
第一种不使用前辍，但仅实现了简单的数据获取，优点是速度快，例如key1/key2[3]/key3对应js为result.key1.key2[3].key3，下标3仅用于数组，从1/-1开始，-1为逆序。复杂情况请直接使用js自定义解析。
第一种使用$.开头，实现了标准的json语法，详情见：https://blog.csdn.net/koflance/article/details/63262484
\`\`\`


### ////////////////////////////////////////////////////////////////////
\`\`\`
原生能力支持使用params.nativeTool，有以下几个功能：

log(obj); // 打印log，key使用时间截
logWithKey(obj, strKey); // 打印log并自定义key

stringByObject(obj); // 将任意对象转换为字符串

deviceId(); // 默认的本地设备id，32位md5小写
deviceIdWithTemplateWithSeparator(strTemplate, strSeparator); // 自定义格式的本地设备id，strTemplate为模版，aaa-aa-aaaa，这里使用-分为3段，每段第一个字符将标识该段类型：0为纯数字，a为纯字母小写，A为纯字母大写，b为字符(数字+字母)小写，B为字符(数字+字母)大写，默认的deviceId模版即为：bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb

base64Decode(str); // base64解码，返回字符串
base64Encode(str); // base64编码，返回字符串
base64EncodeWithData(data); // 对二进制流(NSData)base64编码，返回字符串

readFile(strPath); // 从path中读取文件，返回二进制流
readTxtFile(strPath); // 从path中读取文件，返回字符串
unzipFile(strPath); // 解压zip文件，返回目录path
unzipFileWithPassword(strPath, strPassword); // 使用密码解压zip文件，返回目录path
allFilesAtPath(strDirPath); // 获取path目录下所有的文件path，返回数组:arr(path)

getCache(strKey); // 获取全局缓存对象
setCache(strKey, obj); // 设置全局缓存对象

sha1Encode(str); // 返回sha1
md5Encode(str); // 返回md5

cookieByKey(str); // 返回字符串
cookiesByUrl(url); // 返回数组

XPathParserWithSource(str); // 创建XPath解析器，可用于下面XPath解析器专用接口


XPath解析器接口有：
raw(); // 返回原始html
content(); // 返回内容
tagName(); // 返回字符串
attributes(); // 返回字典
queryWithXPath(strXPath); // 返回查询结果，以数组保存
\`\`\`
  `
})

</script>

<template>
  <div class="node-doc-box">

    <v-md-editor v-model="initData.text"
                 mode="preview"></v-md-editor>
  </div>
</template>

<style scoped lang="scss">
.node-doc-box {
  text-align: left;
  overflow: scroll;
}
</style>
