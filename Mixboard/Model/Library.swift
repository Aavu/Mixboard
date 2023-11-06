//
//  Library.swift
//  Mashup
//
//  Created by Raghavasimhan Sankaranarayanan on 10/13/22.
//

import Foundation

/// Struct to hold the non silent bounds from the backend
struct NonSilentBounds: Codable, Hashable {
    let drums: Dictionary<String, [Float]>
    let vocals: Dictionary<String, [Float]>
    let other: Dictionary<String, [Float]>
    let bass: Dictionary<String, [Float]>
}

/// This is the container for a song
struct Song: Codable, Hashable {
    var album: String?
    var artist: String?
    var external_url: String?
    var fs: Int?
    let id: String
    var img_url: String?
    var key_and_mode: [Int]?
    var name: String?
    var non_silent_bounds: NonSilentBounds?
    var preview_url: String?
    var release_date: String?
    var tempo: Double?
    var placeholder: Bool
    
    
    enum CodingKeys: String, CodingKey {
        case album               = "album"
        case artist              = "artist"
        case external_url        = "external_url"
        case fs                  = "fs"
        case id                  = "id"
        case img_url             = "img_url"
        case key_and_mode        = "key_and_mode"
        case name                = "name"
        case non_silent_bounds   = "non_silent_bounds"
        case preview_url         = "preview_url"
        case release_date        = "release_date"
        case tempo               = "tempo"
        case placeholder         = "placeholder"
    }
    
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(String.self, forKey: .id)
        album = try values.decodeIfPresent(String.self, forKey: .album)
        artist = try values.decodeIfPresent(String.self, forKey: .artist)
        external_url = try values.decodeIfPresent(String.self, forKey: .external_url)
        fs = try values.decodeIfPresent(Int.self, forKey: .fs)
        img_url = try values.decodeIfPresent(String.self, forKey: .img_url)
        key_and_mode = try values.decodeIfPresent([Int].self, forKey: .key_and_mode)
        name = try values.decodeIfPresent(String.self, forKey: .name)
        non_silent_bounds = try values.decodeIfPresent(NonSilentBounds.self, forKey: .non_silent_bounds)
        preview_url = try values.decodeIfPresent(String.self, forKey: .preview_url)
        release_date = try values.decodeIfPresent(String.self, forKey: .release_date)
        tempo = try values.decodeIfPresent(Double.self, forKey: .tempo)
        placeholder = try values.decodeIfPresent(Bool.self, forKey: .placeholder) ?? false
    }
    
    init(album: String? = nil, artist: String? = nil, id: String, img_url: String? = nil, name: String? = nil, release_date: String? = nil) {
        self.album = album
        self.artist = artist
        self.id = id
        self.img_url = img_url
        self.name = name
        self.release_date = release_date
        
        self.external_url = nil
        self.fs = nil
        self.key_and_mode = nil
        self.non_silent_bounds = nil
        self.preview_url = nil
        self.tempo = nil
        self.placeholder = false
    }
}

/// Container for library
struct Library: Decodable, Hashable {
    let version: String
    let statusCode: Int
    var items: Dictionary<String, Song>
}
