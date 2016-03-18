//
//  RCCacheCore.swift
//  RCCache
//
//  Created by Robin on 3/18/16.
//  Copyright © 2016 Robin. All rights reserved.
//

import UIKit


enum CacheType: String {
    case Object = "rcObject"
    case Image = "rcImage"
    case Data = "rcData"
}


private let objectCache = RCCacheCore(.Object)
private let imageCache = RCCacheCore(.Image)
private let dataCache = RCCacheCore(.Data)

public class RCCacheCore {
    
    private let defaultCacheName = "rc_cache"
    private let cachePrex = "com.rc.cache."
    private let ioQueueName = "com.rc.cache.io."
    
    private var fileManager: NSFileManager!
    private var ioQueue: dispatch_queue_t?
    private var cachePath: String = ""

    private var cacheType: CacheType
    
//    private var multipleFolders: [String]?
    
    
    public class var object: RCCacheCore {
        return objectCache
    }
    public class var image: RCCacheCore {
        return imageCache
    }
    public class var data: RCCacheCore {
        return dataCache
    }
    
    
    init(_ cacheType: CacheType) {
        self.cacheType = cacheType
        
        let folderName = cachePrex + self.cacheType.rawValue
        ioQueue = dispatch_queue_create(ioQueueName + self.cacheType.rawValue, DISPATCH_QUEUE_SERIAL)
        
        let paths = NSSearchPathForDirectoriesInDomains(.CachesDirectory, .UserDomainMask, true)
        cachePath = (paths.first! as NSString).stringByAppendingPathComponent(folderName)
        
        dispatch_sync(ioQueue!, { () -> Void in
            self.fileManager = NSFileManager()
            do {
                try self.fileManager.createDirectoryAtPath(self.cachePath, withIntermediateDirectories: true, attributes: nil)
            } catch _ {}
        })

    }
    
//    init(_ multipleFolders: [String]? = nil) {
//        self.multipleFolders = multipleFolders
        
//        if let mFolder = multipleFolders {
//            for folder in mFolder {
//                let folderName = cachePrex + folder
//                ioQueue = dispatch_queue_create(ioQueueName + folderName, DISPATCH_QUEUE_SERIAL)
//                
//                let paths = NSSearchPathForDirectoriesInDomains(.CachesDirectory, .UserDomainMask, true)
//                cachePath = (paths.first! as NSString).stringByAppendingPathComponent(folderName)
//                
//                dispatch_sync(ioQueue!, { () -> Void in
//                    self.fileManager = NSFileManager()
//                    do {
//                        try self.fileManager.createDirectoryAtPath(self.cachePath, withIntermediateDirectories: true, attributes: nil)
//                    } catch _ {}
//                })
//            }
//        } else {
//            let folderName = cachePrex + defaultCacheName
//            ioQueue = dispatch_queue_create(ioQueueName + folderName, DISPATCH_QUEUE_SERIAL)
//            
//            let paths = NSSearchPathForDirectoriesInDomains(.CachesDirectory, .UserDomainMask, true)
//            cachePath = (paths.first! as NSString).stringByAppendingPathComponent(folderName)
//            
//            dispatch_sync(ioQueue!, { () -> Void in
//                self.fileManager = NSFileManager()
//                do {
//                    try self.fileManager.createDirectoryAtPath(self.cachePath, withIntermediateDirectories: true, attributes: nil)
//                } catch _ {}
//            })
//        } 
//    }
    
    
    public func cache(key: String, value: AnyObject?, image: UIImage?, data: NSData?, completeHandler:(() -> ())? = nil) {
        let path = cachePathForKey(key)
        
        switch cacheType {
        case .Object:
            cacheObject(key, value: value, path: path, completeHandler: completeHandler)
        case .Image:
            cacheImage(image, key: key, path: path, completeHandler: completeHandler)
        case .Data:
            cacheData(data, key: key, path: path, completeHandler: completeHandler)
        }
    }
    
    public func get(key: String, objectHandler: ((obj: AnyObject?) -> ())? = nil, imageHandler: ((image: UIImage?) -> ())? = nil, dataHandler: ((data: NSData?) -> ())? = nil) {
        let path = cachePathForKey(key)
        switch cacheType {
        case .Object:
            getObject(key.rc_MD5(), path: path, objectHandler: objectHandler)
        case .Image:
            getImage(path, imageHandler: imageHandler)
        case .Data:
            getData(path, dataHandler: dataHandler)
        }
    }
    
    
    // Mark: - Private Methods
    
    private func cacheObject(key: String, value: AnyObject?, path: String, completeHandler:(() -> ())? = nil) {
        dispatch_async(ioQueue!) { () -> Void in
            let data = NSMutableData()
            
            let keyArchiver = NSKeyedArchiver(forWritingWithMutableData: data)
            
            keyArchiver.encodeObject(value, forKey: key.rc_MD5())
            
            keyArchiver.finishEncoding()
            
            do {
                try data.writeToFile(path, options: .DataWritingAtomic)
                completeHandler?()
            } catch let err {
                print("write Object to file err : \(err)")
            }
        }
    }
    
    private func cacheImage(image: UIImage?, key: String, path: String, completeHandler:(() -> ())? = nil) {
        dispatch_async(ioQueue!) { () -> Void in
            let data = UIImagePNGRepresentation(image!)
            if let data = data {
                self.fileManager.createFileAtPath(path, contents: data, attributes: nil)
                completeHandler?()
            }
        }
    }
    
    private func cacheData(data: NSData?, key: String, path: String, completeHandler:(() -> ())? = nil) {
        dispatch_async(ioQueue!) { () -> Void in
            if let data = data {
                self.fileManager.createFileAtPath(path, contents: data, attributes: nil)
                completeHandler?()
            }
        }
    }
    

    private func getObject(key: String, path: String, objectHandler:((obj: AnyObject?) -> ())? = nil) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) { () -> Void in
            if  self.fileManager.fileExistsAtPath(path) {
                let data = NSMutableData(contentsOfFile: path)
                let unArchiver = NSKeyedUnarchiver(forReadingWithData: data!)
                let obj = unArchiver.decodeObjectForKey(key)
                objectHandler?(obj: obj)
            }else{
                objectHandler?(obj: nil)
            }
        }
    }
    
    
    private func getImage(path: String, imageHandler:((image: UIImage?) -> ())? = nil) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) { () -> Void in
            if let data = NSData(contentsOfFile: path) {
                if let image = UIImage(data: data) {
                    imageHandler?(image: image)
                }
            }
            imageHandler?(image: nil)
        }
    }
    
    private func getData(path: String, dataHandler:((data: NSData?) -> ())? = nil) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) { () -> Void in
            if let data = NSData(contentsOfFile: path) {
                dataHandler?(data: data)
            }
            dataHandler?(data: nil)
        }
    }
}



extension RCCacheCore {
    func cachePathForKey(key: String) -> String {
        let fileName = cacheFileNameForKey(key)
        
        return (cachePath as NSString).stringByAppendingPathComponent(fileName)
    }
    
    func cacheFileNameForKey(key: String) -> String {
        return key.rc_MD5()
    }
}

