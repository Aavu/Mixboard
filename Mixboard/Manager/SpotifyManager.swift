//
//  SpotifyManager.swift
//  Mixboard
//
//  Created by Raghavasimhan Sankaranarayanan on 11/6/22.
//

import Foundation
import Combine
import SwiftUI

class SpotifyManager: ObservableObject {
    static var shared = SpotifyManager()
    let scopes = ["user-top-read", "user-read-email"]
    
    @AppStorage("email") var currentEmail: String? {
        didSet {
            if let email = currentEmail {
                dbManager.updateUserId(userId: email)
            }
        }
    }
    
    private var dbManager = DatabaseManager.shared
    var spotifyOAuth: SpotifyOAuth?
    var spotifyClientAuth: SpotifyClientCredential?
    
    private var credential = [Spotify.GrantType: Spotify.Credential]()
    
    var code: String?
    
    @Published var isLinked = false
    
    // Client ID and Secret. DO NOT store on client device. Grab it from a secured server. Firebase in this case!
    private var clientIdSecret: Spotify.ClientIdSecret?
    
    var cancellable: AnyCancellable?
    
    enum TokenType: String {
        case Bearer
        case Basic
    }
    
    init() {
        if clientIdSecret == nil {
            getClientIdAndSecret() { idSecret in
                if let idSecret = idSecret {
                    self.spotifyClientAuth = SpotifyClientCredential(clientIdSecret: idSecret)
                    self.spotifyOAuth = SpotifyOAuth(clientIdSecret: idSecret, redirectUri: Config.SPOTIFY_REDIRECT_URL, scopes: self.scopes)
                    
                    self.addSubscriber()
                }
            }
        }
    }
    
    func addSubscriber() {
        cancellable = self.spotifyOAuth?.$isLinked
            .sink(receiveValue: { linked in
                self.isLinked = linked
            })
    }
    
    func getClientIdAndSecret(callback: ((Spotify.ClientIdSecret?) -> ())? = nil) {
        dbManager.getSpotifyClient { clientIdSecret in
            self.clientIdSecret = clientIdSecret
            if let callback = callback {
                callback(clientIdSecret)
            }
        }
    }
    
    func getUserInfo(completion: @escaping (_ userInfo: Spotify.UserInfo?) -> ()) {
        if let spotifyOAuth = spotifyOAuth {
            spotifyOAuth.getAccessToken(completion: { accessToken in
                guard let accessToken = accessToken else {
                    Logger.error("accessToken is nil")
                    completion(nil)
                    return
                }
                
                let url = URL(string: "https://api.spotify.com/v1/me")!
                
                let authHeader = spotifyOAuth.getAuthHeader(accessToken: accessToken)
                
                NetworkManager.request(url: url, type: .GET, contentType: .JSON, headers: [authHeader]) {userInfo in
                    completion(userInfo)
                }
                
            })
        } else {
            Logger.error("spotifyOAuth is nil")
            completion(nil)
        }
    }
    
    func getSong(songId: String, completion: @escaping (_ spotifyTrack: Spotify.Track?) -> ()) {
        if let spotifyClientAuth = spotifyClientAuth {
            spotifyClientAuth.getAccessToken { accessToken in
                guard let accessToken = accessToken else {
                    Logger.error("accessToken is nil")
                    completion(nil)
                    return
                }
                
                let url = URL(string: "https://api.spotify.com/v1/tracks/\(songId)")!
                
                let authHeader = spotifyClientAuth.getAuthHeader(accessToken: accessToken)
                
                NetworkManager.request(url: url, type: .GET, contentType: .JSON, headers: [authHeader]) {track in
                    completion(track)
                }
            }
        }
    }
    
    func getRecommendations(numTracks: Int, forUser: Bool, completion: @escaping (_ spotifyTracks: [Spotify.Track]?) -> ()) {
        let auth = forUser ? spotifyOAuth : spotifyClientAuth
        
        if let auth = auth {
            Logger.debug("Getting recommendations. For user? : \(forUser)")
            
            auth.getAccessToken { accessToken in
                guard let accessToken = accessToken else {
                    Logger.error("accessToken is nil")
                    completion(nil)
                    return
                }
                
                let url = forUser ? URL(string: "https://api.spotify.com/v1/me/top/tracks?limit=\(numTracks)")! : URL(string: "https://api.spotify.com/v1/recommendations?limit=\(numTracks)&seed_genres=pop")!
                
                let authHeader = auth.getAuthHeader(accessToken: accessToken)
                
                if forUser {
                    NetworkManager.request(url: url, type: .GET, contentType: .JSON, headers: [authHeader]) {(result: Spotify.SearchResult.STrack?) in
                        completion(result?.items)
                        return
                    }
                } else {
                    NetworkManager.request(url: url, type: .GET, contentType: .JSON, headers: [authHeader]) {(result: Spotify.Library?) in
                        completion(result?.tracks)
                        return
                    }
                }
            }
        }
    }
    
    func searchSpotify(txt: String, completion: @escaping (_ spotifyTracks: [Spotify.Track], _ error: Error?) -> ()) {
        if txt.isEmpty {
            completion([], SpotifyError.EmptyTextError)
            return
        }
        
        if let spotifyClientAuth = spotifyClientAuth {
            spotifyClientAuth.getAccessToken { accessToken in
                guard let accessToken = accessToken else {
                    Logger.error("accessToken is nil")
                    completion([], SpotifyError.AuthError)
                    return
                }
                
                let truncatedText = txt.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).replacingOccurrences(of: " ", with: "+")
                let encodedUrlString = "https://api.spotify.com/v1/search?q=\(truncatedText)&type=album,artist,track&limit=50".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
                guard let url = URL(string: encodedUrlString ?? "") else {
                    completion([], MBError.URLError(encodedUrlString))
                    return
                }
                
                let authHeader = spotifyClientAuth.getAuthHeader(accessToken: accessToken)
                
                NetworkManager.request(url: url, type: .GET, contentType: .JSON, headers: [authHeader]) {(result: Spotify.SearchResult?) in
                    if let items = result?.tracks.items {
                        completion(items, nil)
                        return
                    }
                    
                    completion([], SpotifyError.ServerError)
                    return
                }
            }
        }
    }
}
