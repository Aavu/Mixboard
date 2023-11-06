//
//  AudioManager.swift
//  Mashup
//
//  Created by Raghavasimhan Sankaranarayanan on 10/17/22.
//

import Foundation
import AVKit
import Combine
import SwiftUI

class AudioManager: ObservableObject {
    static let shared = AudioManager()
    
    @Published var currentMusic: MBMusic?
    
    private var displayLink: CADisplayLink?
    
    private let engine = AVAudioEngine()
    private var players = [String: AVAudioPlayerNode]()
    private var silencePlayer = AVAudioPlayerNode()
    private var needsFilesScheduled = true
    
    @Published var isPlaying = false
    
    @Published var currentPosition: AVAudioFramePosition = 0
    
    private var currentSilentBufferPosition: AVAudioFramePosition = 0
    @Published var audioLengthSamples: AVAudioFramePosition = 0
    @Published var timelineLengthSamples: AVAudioFramePosition = 0
    
    init() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback)
        } catch {
            Logger.error("Unable to set audio category")
        }
    }
    
    
    private var totalBeats:Int = 32 {
        didSet {
            timelineLengthSamples = MBMusic.getInSamples(value: totalBeats, sampleRate: sampleRate, tempo: tempo)
            Logger.debug("totalBeats: \(totalBeats)")
        }
    }
    
    private var sampleRate: Double = 44100
    
    @Published var tempo: Double = 120 {
        didSet {
            currentMusic?.set(tempo: tempo)
            timelineLengthSamples = MBMusic.getInSamples(value: totalBeats, sampleRate: sampleRate, tempo: tempo)
            Logger.debug("tempo: \(tempo)")
        }
    }
    
    func setTotalBeats(_ beats: Int) {
        totalBeats = beats
    }
    
    func setMashupLength(lengthInBars: Int) {
        let temp = MBMusic.getInSamples(value: lengthInBars, sampleRate: sampleRate, tempo: tempo)
        needsFilesScheduled = temp != audioLengthSamples
        audioLengthSamples = temp
        Logger.trace("length in samples: \(audioLengthSamples), tempo: \(tempo)")
    }
    
    func getMashupLength() -> AVAudioFramePosition {
        return audioLengthSamples
    }
    
    func playOrPause() {
        if needsFilesScheduled {
            Logger.debug("Not ready to play")
            return
        }
        
        if isPlaying {
            pause()
        } else {
            play()
        }
    }
    
    func prepareForPlay(music: MBMusic, lengthInBars: Int) {
        setMashupLength(lengthInBars: lengthInBars)

        self.set(music: music)
        
        let success = configEngine()
        if !success {
            Logger.critical("Unable to configure engine.")
            return
        }
        setCurrentPosition(position: 0) // Also schedules music
        setupDisplayLink()
        needsFilesScheduled = false
    }
    
    func set(music: MBMusic) {
        self.currentMusic = music
    }
    
    private func play() {
        displayLink?.isPaused = false
        for (_, p) in self.players {
            p.play()
        }
        self.silencePlayer.play()
        self.isPlaying = true
    }
    
    private func pause() {
        displayLink?.isPaused = true
        for (_, p) in self.players {
            p.pause()
        }
        self.silencePlayer.pause()
        self.isPlaying = false
    }
    
    func stop() {
        displayLink?.isPaused = true
        for (_, p) in self.players {
            p.stop()
        }
        self.silencePlayer.stop()
        self.isPlaying = false
    }
    
    func reset() {
        stop()
        currentPosition = 0
        needsFilesScheduled = true
    }
    
    func set(volume: Float) {
        for (_, p) in players {
            p.volume = volume
        }
    }
    
    func handleMute(regionIds: [UUID]) {
        set(volume: 1)
        for id in regionIds {
            if let player = players[id.uuidString] {
                player.volume = 0
            }
        }
    }
    
    func handleSolo(regionIds: [UUID]) {
        if regionIds.count > 0 {
            set(volume: 0)
        } else {
            set(volume: 1)
            return
        }
        
        for id in regionIds {
            if let player = players[id.uuidString] {
                player.volume = 1
            }
        }
    }
    
    private func playBackCompleteCallback() {
        if isPlaying {
            DispatchQueue.main.async {
                self.stop()
                Logger.debug("playback complete")
                self.setCurrentPosition(position: 0)
                self.scheduleMusic() // prep for next playback
            }
        }
    }
    
    
    func scheduleMusic(at position: AVAudioFramePosition? = nil) {
        guard let music = self.currentMusic else {
            Logger.debug("Current Music is nil. Not scheduling")
            return
        }
        
        let _pos = position ?? currentPosition
        currentPosition = _pos
        
        stop()
        
//        Logger.trace("Current position: \(currentPosition), tempo: \(tempo)")
        
        if audioLengthSamples > AVAudioFrameCount(currentPosition) {
            guard let buffer = AVAudioPCMBuffer(pcmFormat: .init(standardFormatWithSampleRate: sampleRate, channels: 1)!, frameCapacity: AVAudioFrameCount(audioLengthSamples - currentPosition)) else { return }
            let _time = AVAudioTime(sampleTime: currentPosition, atRate: sampleRate)
            currentSilentBufferPosition = currentPosition
            silencePlayer.scheduleBuffer(buffer, at: _time)
            silencePlayer.prepare(withFrameCount: buffer.frameLength)
        } else {
            Logger.debug("illegal capacity: \(currentPosition), \(audioLengthSamples)")
            return
        }
        
        for (id, audio) in music.audios {
            if let player = players[id] {
                do {
                    guard let len = audio.length else {
                        Logger.error("audio (\(id)) does not have length set")
                        continue
                    }
                    
                    let file = try AVAudioFile(forReading: audio.file)
                    let fmt = file.processingFormat
                    sampleRate = fmt.sampleRate
                    let diffTime = audio.position - currentPosition
//                    Logger.trace("audio position for \(id): \(audio.position), diff time: \(diffTime), file length: \(file.length), audio length: \(len)")
                    if diffTime >= 0 {  // Region is in the future
                        let _time = AVAudioTime(sampleTime: diffTime, atRate: sampleRate)
                        player.scheduleSegment(file, startingFrame: 0, frameCount: AVAudioFrameCount(len), at: _time)
                        player.prepare(withFrameCount: AVAudioFrameCount(len))
                    } else {
                        if currentPosition < audio.position + len {  // Region under playhead
                            let startingFrame = AVAudioFramePosition(currentPosition - audio.position)
                            let frameCount = AVAudioFrameCount(len - startingFrame)
                            player.scheduleSegment(file, startingFrame: startingFrame, frameCount: frameCount, at: nil)
                            player.prepare(withFrameCount: frameCount)
                        }
                    }
                } catch (let e) {
                    Logger.error(e)
                    return
                }
            }
        }
        
        needsFilesScheduled = false
    }
    
    private func resetPlayers() {
        for (_, p) in players {
            p.engine?.detach(p)
        }
        players.removeAll()
        needsFilesScheduled = true
    }
    
    private func configEngine() -> Bool {
        guard let music = self.currentMusic else { return false }
        displayLink?.isPaused = true
        
        if engine.isRunning {
            engine.stop()
        }
        
        resetPlayers()
        
        // Create a dummy player that plays silence. This will be helpful to track current play time
        engine.attach(silencePlayer)
        engine.connect(silencePlayer, to: engine.mainMixerNode, format: .init(standardFormatWithSampleRate: self.sampleRate, channels: 1))
        
        for (id, _) in music.audios {
            let p = AVAudioPlayerNode()
            players[id] = p
            engine.attach(p)
            engine.connect(p, to: engine.mainMixerNode, format: .init(standardFormatWithSampleRate: self.sampleRate, channels: 1))
        }
        
        engine.prepare()
        
        do {
            try engine.start()
            return true
        } catch {
            Logger.critical("Unable to start player: \(error)")
            return false
        }
    }
    
    private func setupDisplayLink() {
        displayLink = CADisplayLink(
            target: self,
            selector: #selector(updateDisplay))
        displayLink?.add(to: .current, forMode: .common)
    }
    
    @objc private func updateDisplay() {
        if self.currentPosition >= self.audioLengthSamples {
            self.playBackCompleteCallback()
        }
        
        if let t = silencePlayer.lastRenderTime {
            if let playerTime: AVAudioTime = silencePlayer.playerTime(forNodeTime: t) {
                self.currentPosition = playerTime.sampleTime + currentSilentBufferPosition
            }
            
        }
    }
    
    func setCurrentPosition(position: AVAudioFramePosition) {
        currentPosition = max(min(position, timelineLengthSamples), 0)
        let wasPlaying = isPlaying
        let _ = scheduleMusic(at: currentPosition)
        
        if wasPlaying {
            play()
        }
    }
    
    func setProgress(progress p: CGFloat) {
        if p.isNaN { return }
        let temp = max(min(p, 1), 0)
        setCurrentPosition(position: AVAudioFramePosition(round(Double(timelineLengthSamples) * temp)))
    }
}
