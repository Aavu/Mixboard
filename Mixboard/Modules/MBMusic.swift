//
//  MBMusic.swift
//  Mixboard
//
//  Created by Raghavasimhan Sankaranarayanan on 11/18/22.
//

import Foundation
import AVFoundation

class MBMusic: Equatable {
    var audios = [String: Audio]()
    var tempo: Double = 120
    
    init(audios: [String: Audio]? = nil, tempo: Double? = nil) {
        Logger.trace("init music")
        self.audios = audios ?? [String : Audio]()
        
        if let tempo = tempo {
            set(tempo: tempo)
        }
    }
    
    func getNumAudio() -> Int {
        return audios.count
    }
    
    func add(audio: Audio) {
        Logger.debug("Adding audio with id: \(audio.getId())")
        audios[audio.getId()] = audio
        set(tempo: audio.tempo)
    }
    
    func remove(audio: Audio) {
        Logger.debug("Removing audio with id: \(audio.getId())")
        audios[audio.getId()] = nil
    }
    
    func remove(id: UUID) {
        Logger.debug("Removing audio with id: \(id)")
        audios[id.uuidString] = nil
    }
    
    func getCommon(music: MBMusic?) -> MBMusic {
        guard let music = music else {return self}
        
        let temp = getIntersection(items: music.audios)
        
        return MBMusic(audios: temp, tempo: tempo)
    }
    
    func getIntersection(items: [String: Audio]) -> [String: Audio] {
        var temp = [String: Audio]()
        for (id, _) in items {
            if let a = self.audios[id] {
                temp[id] = a
            }
        }
        return temp
    }
    
    func set(tempo: Double) {
        self.tempo = tempo
        Logger.trace("tempo: \(self.tempo)")
    }
    
    func update(for audioId: UUID, position: Int? = nil, length: Int? = nil) -> Error? {
        if position == nil && length == nil { return SetValueError.IllegalArgument }
        
        var err: Error? = SetValueError.AudioNotFound
        
        for (id, audio) in audios {
            if id == audioId.uuidString {
                var tempPos = audio.position
                var tempLen = audio.length
                
                if let position = position {
                    let pos = MBMusic.getInSamples(value: position, sampleRate: audio.sampleRate, tempo: tempo)
                    remove(audio: audio)
                    add(audio: Audio(file: audio.file, position: pos, length: tempLen, tempo: tempo))
                    tempPos = pos
                    err = nil
                }
                
                if let length = length {
                    let len = MBMusic.getInSamples(value: length, sampleRate: audio.sampleRate, tempo: tempo)
                    remove(audio: audio)
                    add(audio: Audio(file: audio.file, position: tempPos, length: len, tempo: tempo))
                    tempLen = len
                    err = nil
                }
                
                if err == nil {
                    Logger.trace("x: \(tempPos), length: \(tempLen ?? 0), tempo: \(tempo)")
                }
                
                return err
            }
        }
        
        return err
    }
    
    
    static func getInSamples(value: Int, sampleRate: Double, tempo: Double) -> AVAudioFramePosition {
        let valueInSec = Double(value) * 4 * 60 / tempo
        return AVAudioFramePosition(valueInSec * sampleRate)
    }
    
    static func == (lhs: MBMusic, rhs: MBMusic) -> Bool {
        let temp = lhs.getIntersection(items: rhs.audios)
        return temp.count == lhs.audios.count && temp.count == rhs.audios.count
    }
}
