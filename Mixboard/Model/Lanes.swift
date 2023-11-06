//
//  Lanes.swift
//  Mashup
//
//  Created by Raghavasimhan Sankaranarayanan on 10/15/22.
//

import Foundation

/// This is used by the canvas when laying regions on tracks
enum Lane: String, CaseIterable {
    case Vocals = "0"
    case Other = "1"
    case Bass = "2"
    case Drums = "3"
    
    func getName() -> String {
        switch self {
        case .Vocals:
            return  "Vocals"
        case .Other:
            return "Chords"
        case .Bass:
            return "Bass"
        case .Drums:
            return "Drums"
        }
    }
    
    func getId() -> Int {
        switch self {
        case .Vocals:
            return 0
        case .Other:
            return 1
        case .Bass:
            return 2
        case .Drums:
            return 3
        }
    }
}
