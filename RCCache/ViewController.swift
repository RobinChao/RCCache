//
//  ViewController.swift
//  RCCache
//
//  Created by Robin on 3/18/16.
//  Copyright © 2016 Robin. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
//        testCacheObject()
        testCacheImage()
    }
    
    
    
    func testCacheObject() {
        let member = Member()
        
        member.id = 100
        member.name = "Jack"
        member.score = 90
        
        $.cacheObejct("member-1", value: member, completeHandler: {
            print("保存成功")
        })
        
        
        // Get 
        $.getObject("member-1") { (object) -> () in
            if let object = object as? Member {
                print("id: \(object.id) \n name: \(object.name)  \n  score: \(object.score)")
            }
        }
    }
    
    
    func testCacheImage() {
        let image = UIImage(contentsOfFile: NSBundle.mainBundle().pathForResource("52.jpg", ofType: nil)!)
        $.cacheImage("image", image: image!) { () -> () in
            print("保存成功")
        }
        
        
        // Get
        $.getImage("image") { (image) -> () in
            print("\(image)")
        }
    }
   

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

