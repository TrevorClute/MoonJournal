//
//  Wheel.swift
//  3dJournal
//
//  Created by Trevor Clute on 6/14/25.
//

import Foundation

class Wheel<T> {
    var current = 0
    var list:[T]
    init(_ list:[T]){
        self.list = list
    }
    
    func getCurrent() -> T {
        return list[current]
    }
    
    func iterate(){
        current += 1
        if(current == list.count){
            current = 0
        }
    }
}
