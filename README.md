# RCCache

** Tiis Repository is just fork the [ZZDiskCache](https://github.com/smalldu/ZZDiskCache). **

** Just learning !!!!! **

# ZZDiskCache

####对象、图片、NSData的 本地缓存

#####知识储备
工欲善其事必先利其器，要想封装一个好用的本地缓存库，首先要对本地文件目录有个比较清晰的认识

- **沙盒主路径**：是程序运行期间系统会生成一个专属的沙盒路径，应用程序在使用期间非代码的文件都存储在当前的文件夹路径里面

```
let homePath = NSHomeDirectory()
print(homePath)
```

把控制台输出的地址拷贝，Finder下前往后可以看到目录结构

![配图](http://upload-images.jianshu.io/upload_images/954071-46ca70d01d2616e7.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

- **Documents**：用来存储永久性的数据的文件 程序运行时所需要的必要的文件都存储在这里（数据库）itunes会自动备份这里面的文件

```
//Document 主目录
let documentPaths = NSSearchPathForDirectoriesInDomains(NSSearchPathDirectory.DocumentationDirectory, NSSearchPathDomainMask.AllDomainsMask, true)
let path = documentPaths.first
```
- **Library**：用于保存程序运行期间生成的文件

```
//Libaray目录
let libPaths = NSSearchPathForDirectoriesInDomains(NSSearchPathDirectory.LibraryDirectory, NSSearchPathDomainMask.AllDomainsMask, true)
let libPath = libPaths.first
```
- **Caches**：文件夹用于保存程序运行期间产生的缓存文件

```
//Cache目录
let cachePaths = NSSearchPathForDirectoriesInDomains(NSSearchPathDirectory.CachesDirectory, NSSearchPathDomainMask.AllDomainsMask, true)
let cachePath = cachePaths.first
```

- **Preferences**：主要是保存一些用户偏好设置的信息，一般情况下，我们不直接打开这个文件夹 而是通过`NSUserDefaults`进行偏好设置的存储

`NSUserDefaults`的操作非常简单，我对它也小小的封装了一下，写了几个全局方法

```
func setDefault(key:String,value:AnyObject?){
    if value == nil{
        NSUserDefaults.standardUserDefaults().removeObjectForKey(key)
    }else{
        NSUserDefaults.standardUserDefaults().setObject(value, forKey: key)
        NSUserDefaults.standardUserDefaults().synchronize() //同步
    }
}

func removeUserDefault(key:String?){
    if key != nil{
         NSUserDefaults.standardUserDefaults().removeObjectForKey(key!)
         NSUserDefaults.standardUserDefaults().synchronize()
    }
}

func getDefault(key:String) ->AnyObject?{
   return NSUserDefaults.standardUserDefaults().valueForKey(key)
}
```
- **tmp**：临时文件夹---程序运行期间产生的临时岁骗会保存在这个文件夹中 通常文件下载完之后或者程序退出的灰自动清空此文件夹itunes不会备份这里的数据。 

>tips： 由于系统会清空此文件夹所以下载或者其他临时文件若需要持久化请及时移走

#####本地缓存库

有了这些对文件存储的预备知识，下面来开发我们的本地缓存

首先明确我们为什么要做这件事情，主要是为了提高用户体验
比如：简书中用户浏览了主页，点进了各种详情页看了，然后坐在地铁上，想浏览自己浏览过的页面时，由于连不上网络或者网络很差。这时候如果你把用户浏览的记录都储存在本地，用户体验就会非常舒服。而且用户浏览过的页面，再次浏览的时候直接从本地去，有更新再从服务器取，这样省去了用户的重复等待。

我现在做的app就有这样的需求，每个页面都要做本地存储，因为做了聊天，聊天中的图片和语音也要做本地存储。

针对这个需求，我们来写一个好用的能适配这些情况的库。

因为是缓存，我选择了存在Cache文件夹中。因为需要分类管理，所以我会在Cache地下建几个不同的文件夹，页面缓存的其实是对象类型。用一个文件夹管理，图片和语音也分别用一个，所以这里用了枚举来管理这几种类型。以后添加类型也方便

```
//会在cache下创建目录管理
enum CacheFor:String{
    case Object = "zzObject"     //页面对象缓存 (缓存的对象)
    case Image = "zzImage"  //图片缓存 (缓存NSData)
    case Voice = "zzVoice"  //语音缓存 (缓存NSData)
}
```

文件管理，需要用到`NSFileManager`对象，这里声明一个文件管理的私有变量。文件的写入放在一个串行的线程中异步执行，需要一个队列对象。 当然还需要一个路径对象。为了避免文件名或者队列名的重复，都声明了一个前缀，还有一个默认的缓存名。最后声明一个私有的缓存类型的变量

```
public class ZZDiskCache {

    private let defaultCacheName = "zz_default"
    private let cachePrex = "com.zz.zzdisk.cache."
    private let ioQueueName = "com.zz.zzdisk.cache.ioQueue."
    
    private var fileManager: NSFileManager!
    private let ioQueue: dispatch_queue_t
    var diskCachePath:String
    private var storeType:CacheFor
}
```

然后就是初始化这些变量了，因为我们要按照类型初始化，所以初始化的时候需要传入对应的类型。

```
init(type:CacheFor) {
        self.storeType = type
        let cacheName = cachePrex+type.rawValue
        ioQueue = dispatch_queue_create(ioQueueName+type.rawValue, DISPATCH_QUEUE_SERIAL)
        //获取缓存目录
        let paths = NSSearchPathForDirectoriesInDomains(.CachesDirectory, NSSearchPathDomainMask.UserDomainMask, true)
        //缓存目录下创建一个子目录
        diskCachePath = (paths.first! as NSString).stringByAppendingPathComponent(cacheName)
        
        dispatch_sync(ioQueue) { () -> Void in
            self.fileManager = NSFileManager()
            //创建子目录对应的文件夹
            do {
                try self.fileManager.createDirectoryAtPath(self.diskCachePath, withIntermediateDirectories: true, attributes: nil)
            } catch _ {}
        }
    }
    
```

根据类型创建好对应的队列名称，目录和文件夹。

一般我在项目中只用到三种类型，所以我自己声明好三个对象，方便自己使用。

声明三个私有的全局对象
```
private let page = ZZDiskCache(type:.Object)
private let image = ZZDiskCache(type:.Image)
private let voice = ZZDiskCache(type:.Voice)
```

对外开放调用的变量
```
 // 针对Page
    public class var sharedCacheObj: ZZDiskCache {
        return page
    }
    
    // 针对Image
    public class var sharedCacheImage: ZZDiskCache {
        return image
    }
    
    // 针对Voice
    public class var sharedCacheVoice: ZZDiskCache {
        return voice
    }
```
准备工作完毕，可以真正的存储和获取了。

页面的缓存一般缓存的是对象或者对象数组也有可能为nil，这里用AnyObject?

首先需要知道一点就是对象的缓存是通过归档和反归档 ， 所有对象必须序列化和反序列化。也就是实现`NSCoding`的`encodeWithCoder:`和`init?(coder aDecoder: NSCoder)`

比如我们新建一个Student类，应该这样
```
import Foundation

class Student: NSObject,NSCoding {
    
    var id:NSNumber?
    var name:String?
    
    //MARK: -序列化
    func encodeWithCoder(aCoder: NSCoder) {
        aCoder.encodeObject(self.name, forKey: "name")
        aCoder.encodeObject(self.id, forKey: "id")
    }
    
    //MARK: -反序列化
    required init?(coder aDecoder: NSCoder) {
        self.id = aDecoder.decodeObjectForKey("id") as? NSNumber
        self.name = aDecoder.decodeObjectForKey("name") as? String
    }
}
```

对象存储的时候需要一个路径和一个key，这里写了两个方法来管理这个key，key既作为路径也作为取值的key并对它进行md5加密

```
extension ZZDiskCache{
    func cachePathForKey(key: String) -> String {
        let fileName = cacheFileNameForKey(key)     //对name进行MD5加密
        return (diskCachePath as NSString).stringByAppendingPathComponent(fileName)
    }
    
    func cacheFileNameForKey(key: String) -> String {
        return key.zz_MD5()
    }
}
```

`key.zz_MD5()`是一个String的扩展，后面我会把源码地址放上，大家可以下载看。其实不加密也是可以的。

需要使用路径的时候只需要传入一个key进去就行了
`let path = self.cachePathForKey(key)`

写一个私有方法处理对象归档

```
    /**
     对象存储 归档操作后写入文件
     
     - parameter key:   键
     - parameter value: 值
     - parameter path: 路径
     - parameter completeHandler: 完成后回调
     */
    private func stroeObject(key:String,value:AnyObject?,path:String,completeHandler:(()->())? = nil){
        dispatch_async(ioQueue){
            let data = NSMutableData()  //声明一个可变的Data对象
            //创建归档对象
            let keyArchiver = NSKeyedArchiver(forWritingWithMutableData: data)
            //开始归档
            keyArchiver.encodeObject(value, forKey: key.zz_MD5())  //对key进行MD5加密
            //完成归档
            keyArchiver.finishEncoding() //归档完毕
            
            do {
                //写入文件
                try data.writeToFile(path, options: NSDataWritingOptions.DataWritingAtomic)  //存储
                //完成回调
                completeHandler?()
            }catch let err{
                print("err:\(err)")
            }
        }
    }
 ```

这里的操作放在我们定义好的串行队列中进行，注释很清楚了，就不再赘述。


同理写两个本地存储UIImage和NSData(用来放音频)的私有方法

```
 /**
     图像存储
     
     - parameter image:           image
     - parameter key:             键
     - parameter path:            路径
     - parameter completeHandler: 完成回调
     */
    private func storeImage(image:UIImage,forKey key:String,path:String,completeHandler:(()->())? = nil){
        dispatch_async(ioQueue) {
            let data = UIImagePNGRepresentation(image.zz_normalizedImage())
            if let data = data {
                self.fileManager.createFileAtPath(path, contents: data, attributes: nil)
            }
        }
    }
    
    /**
     存储声音
     
     - parameter data:            data
     - parameter key:             键
     - parameter path:            路径
     - parameter completeHandler: 完成回调
     */
    private func storeVoice(data:NSData?,forKey key:String,path:String,completeHandler:(()->())? = nil){
        dispatch_async(ioQueue) {
            if let data = data {
                self.fileManager.createFileAtPath(path, contents: data, attributes: nil)
            }
        }
    }
```

图像存储中的`zz_normalizedImage`是担心图像的方向不对写的UIImage的分类。可以下载源码查看。如果要真正用图片缓存的话，在读取的时候都加一层内存的缓存，用NSCache就行了，用法很简单 就不赘述了，因为本文重点是本地缓存

然后写一个公开的存储方法，根据当前的类型调用不同的私有方法。

```
    /**
     存储
     
     - parameter key:             键
     - parameter value:           值
     - parameter image:           图像
     - parameter data:            data
     - parameter completeHandler: 完成回调
     */
    public func stroe(key:String,value:AnyObject? = nil,image:UIImage?,data:NSData?,completeHandler:(()->())? = nil){
        let path = self.cachePathForKey(key)
        switch storeType{
        case .Object:
            print("save Object ")
            self.stroeObject(key, value: value,path:path,completeHandler:completeHandler)
        case .Image:
            print("save Image ")
            if let image = image{
                self.storeImage(image, forKey: key, path: path, completeHandler: completeHandler)
            }
        case .Voice:
            print("save Voice ")
            self.storeVoice(data, forKey: key, path: path, completeHandler: completeHandler)
        }
    }
```

用同样的方式写出获取的方法

```
/**
     获取数据的方法
     
     - parameter key:              键
     - parameter objectGetHandler: 对象完成回调
     - parameter imageGetHandler:  图像完成回调
     - parameter voiceGetHandler:  音频完成回调
     */
    public func retrieve(key:String,objectGetHandler:((obj:AnyObject?)->())? = nil,imageGetHandler:((image:UIImage?)->())? = nil,voiceGetHandler:((data:NSData?)->())?){
        let path = self.cachePathForKey(key)
        switch storeType{
        case .Object:
            self.retrieveObject(key.zz_MD5(), path: path, objectGetHandler: objectGetHandler)
        case .Image:
            self.retrieveImage(path,imageGetHandler:imageGetHandler)
        case .Voice:
            self.retrieveVoice(path, voiceGetHandler: voiceGetHandler)
        }
    }
    
    
    /**
     获取文件归档对象
     
     - parameter key:              键
     - parameter path:             路径
     - parameter objectGetHandler: 获得后回调闭包
     */
    private func retrieveObject(key:String,path:String,objectGetHandler:((obj:AnyObject?)->())?){
        //反归档 获取
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) { () -> Void in
            if self.fileManager.fileExistsAtPath(path){
                let mdata = NSMutableData(contentsOfFile:path)  //声明可变Data
                let unArchiver = NSKeyedUnarchiver(forReadingWithData: mdata!) //反归档对象
                let obj = unArchiver.decodeObjectForKey(key)    //反归档
                objectGetHandler?(obj:obj)  //完成回调
            }
                objectGetHandler?(obj:nil)
        }
    }
    
    /**
     获取图片
     
     - parameter path:            路径
     - parameter imageGetHandler: 获得后回调闭包
     */
    private func retrieveImage(path:String,imageGetHandler:((image:UIImage?)->())?){
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) { () -> Void in
            if let data = NSData(contentsOfFile: path){
                if let image = UIImage(data: data){
                    imageGetHandler?(image: image)
                }
            }
            imageGetHandler?(image: nil)
        }
    }
    
    /**
     获取音频数据
     
     - parameter path:            路径
     - parameter voiceGetHandler: 获得后回调闭包
     */
    private func retrieveVoice(path:String,voiceGetHandler:((data:NSData?)->())?){
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) { () -> Void in
            if let data = NSData(contentsOfFile: path){
                voiceGetHandler?(data: data)
            }
            voiceGetHandler?(data: nil)
        }
    }
```

这样一个针对对象、图片、NSData进行本地读取并对其分目录管理的类就写完了，但是现在要调用非常麻烦，还需要进一步封装。

创建一个结构体，对存储和获取方法进行封装
```
public struct ZZDiskCacheHelper {
    
    /**
      本地缓存对象
     */
    static func saveObj(key:String,value:AnyObject?,completeHandler:(()->())? = nil){
    
        ZZDiskCache.sharedCacheObj.stroe(key, value: value, image: nil, data: nil, completeHandler: completeHandler)
        
    }
    
    /**
      本地缓存图片
     */
    static func saveImg(key:String,image:UIImage?,completeHandler:(()->())? = nil){
        
        ZZDiskCache.sharedCacheImage.stroe(key, value: nil, image: image, data: nil, completeHandler: completeHandler)
        
    }
    
    /**
     本地缓存音频 或者其他 NSData类型
     */
    static func saveVoc(key:String,data:NSData?,completeHandler:(()->())? = nil){
    
        ZZDiskCache.sharedCacheVoice.stroe(key, value: nil, image: nil, data: data, completeHandler: completeHandler)
        
    }
    
    /**
      获得本地缓存的对象
     */
    static func getObj(key:String,compelete:((obj:AnyObject?)->())){
        
        ZZDiskCache.sharedCacheObj.retrieve(key, objectGetHandler: compelete, imageGetHandler: nil, voiceGetHandler: nil)
        
    }
    
    /**
     获得本地缓存的图像
     */
    static func getImg(key:String,compelete:((image:UIImage?)->())){
        
        ZZDiskCache.sharedCacheImage.retrieve(key, objectGetHandler: nil, imageGetHandler: compelete, voiceGetHandler: nil)
        
    }
    
    /**
     获得本地缓存的音频数据文件
     */
    static func getVoc(key:String,compelete:((data:NSData?)->())){
        
        ZZDiskCache.sharedCacheVoice.retrieve(key, objectGetHandler: nil, imageGetHandler: nil, voiceGetHandler: compelete)
        
    }

}
```

经过封装，我们现在使用已经很方便了，只需要这样

![配图](http://upload-images.jianshu.io/upload_images/954071-37d3aee12a6bfa2c.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

但是每次还要输入ZZDiskCacheHelper好麻烦 。

再加一句代码
```
typealias $ = ZZDiskCacheHelper
```

这时候就很方便了


![配图](http://upload-images.jianshu.io/upload_images/954071-34ba6a00d9db82d1.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


![配图](http://upload-images.jianshu.io/upload_images/954071-7bd59abe2892b6bc.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


在任何想要存储和获取的地方只需要简单的save和get就行了，文件夹，队列异步等都在那个简单的类中写好了。

测试下，对象的。 此类我在项目中亲测可用。欢迎下载。

空项目Caches下只有屏幕截图

![配图](http://upload-images.jianshu.io/upload_images/954071-365d68cd49fb7bb5.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

我们在viewDidLoad中加入这段代码
```
let stu = Student()
stu.name = "小王"
stu.id = 1
$.saveObj("xxxx", value: stu)
```

![配图](http://upload-images.jianshu.io/upload_images/954071-68789942485594a8.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

我们创建的文件夹和文件都在了。

获取更简单。

```
$.getObj("xxxx") { (obj) -> () in
         if let obj = obj as? Student{
            print("\(obj.id) , \(obj.name)")
         }
 }
```
输出:**Optional(1) , Optional("小王")**

图片和NSData就不再这里演示了大家可以下载代码看看。其实平时Coding的时候有很多可以封装的东西，一次动手后面就轻松多了。
