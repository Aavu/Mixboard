//
//  Spotify.swift
//  Mashup
//
//  Created by Raghavasimhan Sankaranarayanan on 10/13/22.
//

import Foundation

class Spotify {
    enum GrantType: String, Codable, CaseIterable {
        case code
        case client
    }
    
    struct ClientIdSecret: Codable {
        let clientId: String
        let clientSecret: String
    }
    
    struct Artist: Codable, Hashable {
        let external_urls : ExternalURL
        let href: String
        let id: String
        let name: String
        let type: String
        let uri: String
    }
    
    struct Image: Codable, Hashable {
        let height: Int
        let url: String
        let width: Int
    }
    
    struct Album: Codable, Hashable {
        let album_type: String
        let artists: [Artist]
        let available_markets: [String]
        let external_urls: ExternalURL
        let href: String
        let id: String
        let images: [Image]
        let name: String
        let release_date: String
        let release_date_precision: String
        let total_tracks: Int
        let type: String
        let uri: String
    }
    
    struct ExternalURL: Codable, Hashable {
        let spotify: String
    }
    
    struct Track: Codable, Hashable {
        let album : Album
        let artists: [Artist]
        let available_markets: [String]
        let disc_number: Int
        let duration_ms: Int
        let explicit: Bool
        let external_ids: Dictionary<String,String>
        let external_urls: ExternalURL
        let href: String
        let id: String
        let is_local: Bool
        let name: String
        let popularity: Int
        let preview_url: String?
        let track_number: Int
        let type: String
        let uri: String
    }
    
    struct Seed: Codable {
        let afterFilteringSize: Int
        let afterRelinkingSize: Int
        let href: String?
        let id: String
        let initialPoolSize: Int
        let type: String
    }
    
    struct Library: Codable {
        let seeds: [Seed]?
        let tracks: [Track]
    }
    
    struct SearchResult: Codable {
        struct STrack: Codable {
            let href: String
            let items: [Track]
            let limit: Int
            let next: String?
            let offset: Int
            var previous: String?
            let total: Int
        }
        
        let tracks: STrack
        
    }
    
    struct Credential: Codable, Hashable {
        let access_token: String
        let expires_in: Int
        let token_type: String
        var scope: String?
        var refresh_token: String?
        var creationTime: Date?
        var code: String?
    }
    
    struct UserInfo: Codable, Identifiable {
        struct ExplicitContent: Codable {
            let filter_enabled: Bool
            let filter_locked: Bool
        }
        
        struct Followers: Codable {
            let href: String?
            let total: Int
        }
        
        let country: String?
        let display_name: String?
        let email: String?
        let explicit_content: ExplicitContent?
        let external_urls: ExternalURL
        let followers: Followers
        let href: String
        let id: String
        let images: [Image]
        let product: String?
        let type: String
        let uri: String
    }
    
}
