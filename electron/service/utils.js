'use strict';

const {Service} = require('ee-core');

/**
 * utils
 */
class DataUtilService extends Service {
    constructor(ctx) {
        super(ctx);
    }

    /**
     * 对象判空
     * @param obj
     * @returns {boolean}
     */
    nullObj(obj) {
        let empty = true
        for (const key in obj) {
            if (obj.hasOwnProperty(key)) {
                empty = false
                break
            }
        }
        return empty
    }
}

DataUtilService.toString = () => '[class DataUtilService]';
module.exports = DataUtilService;
