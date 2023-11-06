//
//  LuckyMeTemplates.swift
//  Mashup
//
//  Created by Raghavasimhan Sankaranarayanan on 10/20/22.
//

import Foundation

/// Holder for SurpriseMe/LuckyMe templates read from the json file
struct LuckyMeTemplates: Codable {
    struct Template: Codable {
        struct Track: Codable {
            let blocks: [[Int]]
            let tracks: [Int]
        }
        
        let randomGen: Bool
        var lane = Dictionary<Int, Track>()
    }
    
    var tracks = Dictionary<Int, [Template]>()
}
