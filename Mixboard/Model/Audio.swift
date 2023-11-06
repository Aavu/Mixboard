//
//  Audio.swift
//  Mashup
//
//  Created by Raghavasimhan Sankaranarayanan on 10/29/22.
//

import Foundation
import SwiftUI
import AVFoundation

/// Container for audio data
struct Audio: Equatable, Hashable, Transferable, Codable {
    let file: URL
    var position: AVAudioFramePosition
    var length: AVAudioFramePosition?
    var sampleRate: Double
    
    var tempo: Double
    
    init(file: URL, position: AVAudioFramePosition = 0, length: AVAudioFramePosition? = nil, sampleRate: Double = 44100, tempo: Double = 120) {
        self.file = file
        self.position = position
        self.length = length
        if length == nil {
            do {
                let f = try AVAudioFile(forReading: file)
                self.length = f.length
            } catch {
                Logger.error(error)
            }
        }
        self.sampleRate = sampleRate
        self.tempo = tempo
    }
    
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .audio) {
            SentTransferredFile($0.file)
        } importing: { received in
            return self.init(file: received.file)
        }
        
        ProxyRepresentation(exporting: \.file)
    }
    
    func getId() -> String {
        return String(file.lastPathComponent.split(separator: ".")[0])
    }
    
    static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.getId() == rhs.getId()
    }
}
