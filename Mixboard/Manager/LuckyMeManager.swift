//
//  LuckyMeManager.swift
//  Mashup
//
//  Created by Raghavasimhan Sankaranarayanan on 10/20/22.
//

import Foundation

class LuckyMeManager {
    static let shared = LuckyMeManager()
    
    private var templates = [Int: LuckyMeTemplates]()
    
    var appError: AppError?
    
    private var totalBeats: Int = 32
    
    private let bars = [16, 32]
    
    func loadTemplateFiles() {
        for bar in bars {
            guard let url = Bundle.main.url(forResource: "LuckyMeTemplates\(bar)", withExtension: "json")
            else {
                appError = AppError(description: "LuckyMe templates JSON file not found")
                Logger.critical("LuckyMe templates JSON file not found")
                return
            }
            
            do {
                let data = try Data(contentsOf: url)
                self.templates[bar] = try JSONDecoder().decode(LuckyMeTemplates.self, from: data)
            } catch let e {
                Logger.error(e)
                appError = AppError(description: e.localizedDescription)
                return
            }
        }
    }
    
    func setTotalBeats(_ beats: Int) {
        totalBeats = beats
    }
    
    func surpriseMe(songs: [Song]) -> Layout? {
        var layout = Layout()
        guard let templates = self.templates[totalBeats] else {
            Logger.error("No template for \(totalBeats) bars found")
            return nil
        }
        guard let tracks = templates.tracks[songs.count] else {
            Logger.error("No tracks for \(songs.count) songs found")
            return nil
        }
        
        let chosenTemplate = tracks[Int.random(in: 0..<tracks.count)]
        
        for lane in Lane.allCases {
            layout.lane[lane.rawValue] = Layout.Track()
            let laneVars = chosenTemplate.lane[Int(lane.rawValue)!]!
            
            for j in 0..<laneVars.blocks.count {
                let block = laneVars.blocks[j]
                let startPos = block[0]
                let width = block[1] - startPos
                
                let filteredSongs = songs.filter { s in
                    guard let nsb = s.non_silent_bounds else { return false }
                    
                    var bounds = Dictionary<String, [Float]>()
                    switch lane {
                    case .Vocals:
                        bounds = nsb.vocals
                    case .Other:
                        bounds = nsb.other
                    case .Bass:
                        bounds = nsb.bass
                    case .Drums:
                        bounds = nsb.other
                    }

                    for (_, b) in bounds {
                        if b.count > 0 {
                            return true
                        }
                    }
                    return false
                }
                
                if filteredSongs.isEmpty {
                    continue
                }
                
                let trackId = max(min(determineTrack(trackId: laneVars.tracks[j]), filteredSongs.count - 1), 0)
                let shuffledSongs = filteredSongs.shuffled()
                let song = shuffledSongs[trackId]
                let region = Region(x: startPos, w: width, item: .init(id: song.id), state: .New)
                layout.lane[lane.rawValue]!.layout.append(region)
            }
        }
        
        return layout
    }
    
    private func getBlockWidth(lane: Lane, maxWidth: Int) -> Int {
        let randomWidth = [
            Lane.Vocals: Int.random(in: 4...maxWidth),
            Lane.Other: Int.random(in: 4...12),
            Lane.Bass: Int.random(in: 4...12),
            Lane.Drums: Int.random(in: 8...maxWidth)
        ]
        
        return randomWidth[lane]!
    }
    
    func findOverlap(x: Int, y: Int, song: Song, lane: Lane) ->Bool {
        
        return false
    }
    
    private func determineTrack(trackId: Int) -> Int {
        switch(trackId) {
        case 4:
            return Int.random(in: 0...1)
        case 5:
            return Int.random(in: 2...3)
        case 6:
            return Int.random(in: 0...3)
        default:
            return trackId
        }
    }
}
