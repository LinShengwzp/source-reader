// 结构体 api 提交的数据
pub struct ApiOperate<T> {
    action: String,
    cover: bool,
    data: T,
}

