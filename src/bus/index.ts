import mitt, {Emitter} from 'mitt'
import {NodeInfo} from "@/utils/Models";
import {UploadFile} from "element-plus";

const bus = mitt()

// 提交bus事件
// bus.emit(busNames, args ...);

// 监听bus事件
// bus.on(busNames, (args ... ) => {})

// 一处bus事件
// emitter.off('eventName')

class EventBus<T> {
    private emitter: Emitter<Record<string, T>>;
    private readonly eventName: string;

    constructor(busName: string) {
        this.emitter = mitt();
        this.eventName = busName;
    }

    on(handler: (args: T) => void) {
        this.emitter.on(this.eventName, handler);
    }

    off(handler: (args: T) => void) {
        this.emitter.off(this.eventName, handler);
    }

    emit(args: T) {
        this.emitter.emit(this.eventName, args);
    }
}


// 选中文件
export const nodeFileSelectEvent = new EventBus<UploadFile>("nodeFileSelectEvent");

// 选中节点
export const nodeXsGgSelectEvent = new EventBus<NodeInfo>('nodeXsGgSelectEvent');

// type BusClass<T> = {
//     emit: (name: T) => void
//     on: (name: T, callback: Function) => void
// }
// type BusParams = string | number | symbol
// type List = {
//     [key: BusParams]: Array<Function>
// }
//
// class Bus<T extends BusParams> implements BusClass<T> {
//     list: List
//
//     constructor() {
//         this.list = {}
//     }
//
//     emit(name: T, ...args: Array<any>) {
//         let eventName: Array<Function> = this.list[name]
//         eventName.forEach(ev => {
//             ev.apply(this, args)
//         })
//     }
//
//     on(name: T, callback: Function) {
//         let fn: Array<Function> = this.list[name] || [];
//         fn.push(callback)
//         this.list[name] = fn
//     }
// }
