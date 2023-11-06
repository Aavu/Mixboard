//
//  LinkedList.swift
//  Mixboard
//
//  Created by Raghavasimhan Sankaranarayanan on 12/8/22.
//

import Foundation

class LinkedList: CustomStringConvertible {
    class Node {
        var next: Node?
        let data: Any
        
        init(next: Node?, data: Any) {
            self.next = next
            self.data = data
        }
    }
    
    let capacity: Int
    
    private var head: Node?
    private var current: Node?
    
    var first: Node? { head }
    var isEmpty: Bool { length == 0 }
    var length: Int = 0
    var description: String {
        return getDataAsString(separator: " -> ")
    }
    
    init(capacity: Int) {
        self.capacity = capacity
    }
    
    func getDataAsString(separator: String = "\n") -> String {
        return getDataAsStringList().joined(separator: separator)
    }
    
    func getDataAsStringList() -> [String] {
        var _list = [String]()
        var node = head
        
        while node != nil {
            let temp = "\(node!.data)"
            _list.append(temp)
            node = node!.next
        }
        return _list
    }
    
    func append(data: Any) {
        let node = Node(next: nil, data: data)
        
        if let current = current {
            current.next = node
        }
        
        if head == nil {
            head = node
        }
        
        current = node
        length += 1
        
        if length >= capacity {
            clear()
        }
    }
    
    func clear() {
        head = nil
        current = nil
        length = 0
    }
}
