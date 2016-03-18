//
//  Member.swift
//  RCCache
//
//  Created by Robin on 3/18/16.
//  Copyright © 2016 Robin. All rights reserved.
//

import Foundation


class Member: NSObject, NSCoding {
    var id: NSNumber?
    var name: String?
    var score: NSNumber?
    
    
    override init() {
        
    }
    
    required init?(coder aDecoder: NSCoder) {
        self.id = aDecoder.decodeObjectForKey("id") as? NSNumber
        self.name = aDecoder.decodeObjectForKey("name") as? String
        self.score = aDecoder.decodeObjectForKey("score") as? NSNumber
    }
    
    func encodeWithCoder(aCoder: NSCoder) {
        aCoder.encodeObject(self.id, forKey: "id")
        aCoder.encodeObject(self.name, forKey: "name")
        aCoder.encodeObject(self.score, forKey: "score")
    }
}