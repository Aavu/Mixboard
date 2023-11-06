//
//  UserLibraryViewModel.swift
//  Mashup
//
//  Created by Raghavasimhan Sankaranarayanan on 10/14/22.
//

import Foundation
import Combine

class UserLibraryViewModel: ObservableObject {
    @Published var songs = [Song]()
    @Published var disableRemoveBtn = false
    
    /// This is for the songs
    @Published var isSelected = Dictionary<String, Bool>() {
        didSet {
            isFocuingSongs = isSelected.count > 0
        }
    }
    
    @Published var silenceOverlayText = Dictionary<String, String>()
    @Published var dragOffset = Dictionary<String, CGSize>()
    
    @Published var isFocuingSongs = false
    
    @Published var canRemoveSong = [String:Bool]() {
        didSet {
            disableRemoveBtn = shouldDisableRemove()
        }
    }
    
    static let TOTAL_PROGRESS = 100
    
    private var mashupVM: MashupViewModel?
    private var lib: LibraryViewModel?
    private var spotifyVM: SpotifyViewModel?
    
    private var errorSubscriber: AnyCancellable?
    @Published var appError: AppError?
    @Published var showError = false
    
    init() {
        addSubscriber()
    }
    
    func addSubscriber() {
        errorSubscriber = $appError.sink {[weak self] err in
            self?.showError = (err != nil)
        }
    }
    
    func unselectAllSongs() {
        isSelected.removeAll()
    }
    
    func attachViewModels(mashupVM: MashupViewModel, library: LibraryViewModel, spotifyViewModel: SpotifyViewModel) {
        self.mashupVM = mashupVM
        self.lib = library
        self.spotifyVM = spotifyViewModel
    }
    
    func isSongSelected(songId: String) -> Bool {
        return isSelected[songId] ?? false
    }
    
    func isSongInLibrary(songId: String) -> Bool {
        return lib?.getSong(songId: songId) != nil
    }
    
    func contains(songId: String) -> Bool {
        return get(songId: songId) != nil
    }
    
    func get(songId: String) -> Song? {
        for song in songs {
            if song.id == songId {
                return song
            }
        }
        return nil
    }
    
    /// Batch add songs
    func addSongs(songIds: [String: SongSource]) {
        for (id, _) in songIds {
            addSong(songId: id) { err in
                if let err = err {
                    self.appError = AppError(description: err.localizedDescription)
                    self.removePlaceholderSongs()
                    self.mashupVM?.deleteRegionsFor(songId: id)
                }
            }
        }
    }
    
    /// Add a song to library if not already present
    func addSong(songId: String, completion: ((Error?) -> ())? = nil) {
        if isSongInUserLibrary(songId: songId, includePlaceholderTag: false) {
            Logger.info("Song already in library")
            return
        }
        
        canRemoveSong[songId] = false
        
        // Since adding a song might take a while, a placeholder is added for the UI until the song is available
        addPlaceholderSong(songId: songId) { succeeded in
            if !succeeded {
                self.canRemoveSong[songId] = nil
                Logger.error("Cannot add placeholder for song id: \(songId) ....")
                if let completion = completion {
                    completion(MBError.PlaceholderError)
                    return
                }
            }
            
            // Call backend to add the song
            BackendManager.shared.addSong(songId: songId) { err in
                self.canRemoveSong[songId] = true
                
                if let err = err {
                    Logger.error(err)
                    self.canRemoveSong[songId] = nil
                    if let completion = completion {
                        completion(err)
                    }
                    return
                }
                
                if let lib = self.lib {
                    lib.update() {err in
                        self.canRemoveSong[songId] = true
                        self.isSelected[songId] = nil
                        
                        if let err = err {
                            Logger.error(err)
                            self.canRemoveSong[songId] = nil
                            if let completion = completion {
                                completion(err)
                            }
                            return
                        }
                        
                        if let err = self.addSongFromLib(songId: songId), err == MBError.SongNotInLibError(songId) {
                            self.canRemoveSong[songId] = nil
                            if let completion = completion {
                                completion(BackendError.SongDownloadError)
                            }
                            return
                        }
                        
                    }
                }
                
                if let completion = completion {
                    completion(nil)
                }
            }
        }
    }
    
    func addPlaceholderSong(songId: String,_ completion: @escaping (Bool) -> ()) {
        if let song = lib?.getSong(songId: songId) {
            var placeHolderSong = song
            placeHolderSong.placeholder = true
            self.songs.append(placeHolderSong)
            completion(true)
        } else {
            if let spotifyVM = spotifyVM {
                spotifyVM.getSpotifySong(songId: songId, completion: { song in
                    guard let song = song else {
                        completion(false)
                        return
                    }
                    
                    var placeHolderSong = Song(album: song.album.name, artist: song.artists[0].name, id: songId, img_url: song.album.images[0].url, name: song.name, release_date: song.album.release_date)
                    placeHolderSong.placeholder = true
                    self.songs.append(placeHolderSong)
                    completion(true)
                })
            } else {
                completion(false)
            }
        }
    }
    
    func removePlaceholderSongs() {
        self.songs = songs.filter { song in
            return !song.placeholder
        }
    }
    
    @discardableResult func replaceDummy(song:Song) -> Bool {
        for i in (0..<songs.count) {
            if songs[i].id == song.id {
                Logger.trace("Replacing dummy for song id: \(song.id)")
                songs[i] = song
                return true
            }
        }
        return false
    }
    
    @discardableResult func addSongFromLib(songId: String) -> MBError? {
        if let song = lib?.getSong(songId: songId) {
            Logger.info("Adding \(song.name ?? "song") to library")
            self.replaceDummy(song: song)
            return nil
        }
        
        return MBError.SongNotInLibError(songId)
    }
    
    func isSongInUserLibrary(songId: String, includePlaceholderTag: Bool = true) -> Bool {
        for s in self.songs {
            if s.id == songId {
                if includePlaceholderTag && !s.placeholder {
                    return true
                }
                
                return true
            }
        }
        
        return false
    }
    
    func hasNonSilentBoundsFor(song: Song, lane: Lane) -> Bool {
        let beats = [4, 8, 16, 32]
        
        switch lane {
        case .Vocals:
            for beat in beats {
                if !(song.non_silent_bounds?.vocals["\(beat)"]?.isEmpty ?? false) {
                    return true
                }
            }
        case .Other:
            for beat in beats {
                if !(song.non_silent_bounds?.other["\(beat)"]?.isEmpty ?? false) {
                    return true
                }
            }
        case .Bass:
            for beat in beats {
                if !(song.non_silent_bounds?.bass["\(beat)"]?.isEmpty ?? false) {
                    return true
                }
            }
        case .Drums:
            for beat in beats {
                if !(song.non_silent_bounds?.drums["\(beat)"]?.isEmpty ?? false) {
                    return true
                }
            }
        }
        
        return false
    }
    
    func removeSong(songId: String, notifyServer: Bool = true, completion: @escaping (Error?) -> ()) {
        if let canRemove = canRemoveSong[songId], !canRemove {
            completion(MBError.SongStillDownloading)
            return
        }
        
        func removeSongfromUserLib(sId: String, complete: ((Error?) -> ())? = nil) {
            var temp = [Song]()
            for song in self.songs {
                if song.id != sId {
                    temp.append(song)
                } else {
                    if song.placeholder {
                        if let complete = complete {
                            complete(MBError.RemoveError)
                            temp.append(song)
                        }
                    }
                }
            }
            
            self.songs = temp
            if let complete = complete {
                complete(nil)
            }
        }
        
        if notifyServer {
            BackendManager.shared.removeSong(songId: songId) { err in
                if let err = err {
                    Logger.error(err)
                    self.appError = AppError(description: err.localizedDescription)
                    return
                }
                
                removeSongfromUserLib(sId: songId, complete: completion)
            }
        } else {
            removeSongfromUserLib(sId: songId, complete: completion)
        }
    }
    
    func restoreFromHistory(history: History) {
        songs = [Song]()
        for song in history.userLibrary {
            addSong(songId: song.id)
        }
    }
    
    func shouldDisableRemove() -> Bool {
        for (_, canRemove) in canRemoveSong {
            if !canRemove {
                return true
            }
        }
        
        return false
    }
}
