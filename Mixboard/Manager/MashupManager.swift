//
//  MashupManager.swift
//  Mixboard
//
//  Created by Raghavasimhan Sankaranarayanan on 3/5/23.
//

import Foundation
import Combine
import SwiftUI


class MashupManager: ObservableObject {
    public static let shared = MashupManager()
    
    let BAR_LENGTHS = [4, 8, 16, 32]
    
    func chooseBound(for song: Song, lane: Lane, x: Int, w: Int, start: Int64? = nil, end: Int64? = nil) -> Region.Item.Bound {
        let bound = Region.Item.Bound(start: start, end: end)
        
        if let nsb = getNonSilentBounds(for: song, lane: lane, length: w) {
            if nsb.count == 0 {
                Logger.error("No Non Silent Bounds found for song \(song.name ?? song.id) for \(lane) lane")
            }
        } else {
            Logger.error("Cannot get Non Silent Bounds for song \(song.name ?? song.id) for \(lane) lane")
        }
        
        return bound
    }
    
    /// Length can be any length between [1, 32]. Make sure to snap before indexing
    func getNonSilentBounds(for song: Song, lane: Lane, length: Int) -> [Float]? {
        if let nonSilentBounds = song.non_silent_bounds {
            var nsb = nonSilentBounds.vocals
            switch lane {
            case .Vocals:
                nsb = nonSilentBounds.vocals
            case .Other:
                nsb = nonSilentBounds.other
            case .Bass:
                nsb = nonSilentBounds.bass
            case .Drums:
                nsb = nonSilentBounds.drums
            }
            
            if let len = snap(length: length) {
                return nsb[String(len)]
            }
        }
        
        return nil
    }
    
    fileprivate func snap(length: Int) -> Int? {
        for len in BAR_LENGTHS {
            if length <= len {
                return len
            }
        }
        
        Logger.error("Cannot snap \(length) to available Bar length")
        return nil
    }
}
