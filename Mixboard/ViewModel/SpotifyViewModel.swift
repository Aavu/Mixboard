//
//  SpotifyViewModel.swift
//  Mashup
//
//  Created by Raghavasimhan Sankaranarayanan on 10/13/22.
//

import Foundation
import Combine

class SpotifyViewModel: ObservableObject {
    
    @Published var songs = [Spotify.Track]()
    @Published var recommendations = [Spotify.Track]() {
        didSet {
            songs = recommendations
        }
    }
    
    @Published var searchText = ""
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        addSubscribers()
    }
    
    func addSubscribers() {
        /// Subcription for search text
        $searchText
            .debounce(for: .seconds(0.5), scheduler: DispatchQueue.main)
            .sink { [weak self] txt in
                SpotifyManager.shared.searchSpotify(txt: txt) { tracks, err in
                    if let e = err as? SpotifyError, e == .EmptyTextError {
                        if let reco = self?.recommendations {
                            self?.songs = reco
                        }
                    }else if err == nil {
                        self?.songs = tracks
                    } else {
                        Logger.error(err.debugDescription)
                    }
                }
                
            }.store(in: &cancellables)
    }
    
    /// Get song from spotify api if not already in library
    func getSpotifySong(songId: String, completion: @escaping (_ spotifyTrack: Spotify.Track?) -> ()) {
        for song in songs {
            if song.id == songId {
                completion(song)
                return
            }
        }
        
        Logger.info("\(songId) not in the fetched spotify track list. Fetching from API")
        // If the chosen song is not part of the recommendation.
        // This happens when the user cancels search after selecting a song from the searched song list
        SpotifyManager.shared.getSong(songId: songId, completion: completion)
    }
    
    /// Get the song in the Song Struct format
    func getSong(songId: String) -> Song? {
        for song in songs {
            if song.id == songId {
                return Song(album: song.album.name, artist: song.artists[0].name, id: songId, img_url: song.album.images[0].url, name: song.name, release_date: song.album.release_date)
            }
        }
        
        return nil
    }
}
