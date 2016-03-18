//
//  RCCache.swift
//  RCCache
//
//  Created by Robin on 3/18/16.
//  Copyright © 2016 Robin. All rights reserved.
//

import UIKit

typealias $ = RCCache

class RCCache: NSObject {
    
    /**
     * Cache data's
     */
    
    // cache the object, must impl the encoding 
    static func cacheObejct(key: String, value: AnyObject?, completeHandler: (() -> ())? = nil) {
        RCCacheCore.object.cache(key, value: value, image: nil, data: nil, completeHandler: completeHandler)
    }
    
    // cache image
    static func cacheImage(key: String, image: UIImage, completeHandler: (() -> ())? = nil) {
        RCCacheCore.image.cache(key, value: nil, image: image, data: nil, completeHandler: completeHandler)
    }
    
    // cache data
    static func cacheData(key: String, data: NSData?,  completeHandler: (() -> ())? = nil) {
        RCCacheCore.data.cache(key, value: nil, image: nil, data: data, completeHandler: completeHandler)
    }


    /**
     *  Get Cache data's
     */
    
    // get object
    static func getObject(key: String, completion: ((object: AnyObject?) -> ())) {
        RCCacheCore.object.get(key, objectHandler: completion, imageHandler: nil, dataHandler: nil)
    }
    
    // get image
    static func getImage(key: String, completion: ((image: UIImage?) -> ())) {
        RCCacheCore.image.get(key, objectHandler: nil, imageHandler: completion, dataHandler: nil)
    }
    
    // get data
    static func getData(key: String, completion: ((data: NSData?) -> ())) {
        RCCacheCore.data.get(key, objectHandler: nil, imageHandler: nil, dataHandler: completion)
    }

}
