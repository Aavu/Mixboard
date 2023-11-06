//
//  MBError.swift
//  Mixboard
//
//  Created by Raghavasimhan Sankaranarayanan on 12/8/22.
//

import Foundation

enum DatabaseError: Error {
    case UserReferenceEmpty
}

enum BackendError: Error, LocalizedError {
    case ResponseEmpty
    case TaskIdEmpty
    case RegionDownloadError(String)
    case SongDownloadError
    case DecodingError
    case WriteToFileError
    
    public var errorDescription: String? {
        switch self {
        case .SongDownloadError:
            return "This song cannot be downloaded at the moment. Please try again later or try a different song!"
        case .ResponseEmpty:
            return "No response from the Server. Please try again later"
        case .TaskIdEmpty:
            return "No task Id found"
        case .RegionDownloadError(let id):
            return "Region \(id) cannot be downloaded"
        case .DecodingError:
            return "There was an issue decoding. Please try again later"
        case .WriteToFileError:
            return "There was an issue saving audio. Please try again"
        }
    }
}

enum SetValueError: Error {
    case AudioNotFound
    case ValueNotUpdated
    case IllegalArgument
}

enum MBError: Error, Equatable {
    case PlaceholderError
    case SongStillDownloading
    case RemoveError
    case URLError(String?)
    case SongNotInLibError(String?)
    case SongAlreadyInUserLibError(String?)
    
    public var errorDescription: String? {
        switch self {
        case .PlaceholderError:
            return "Error adding placeholder"
        case .RemoveError:
            return "Error Removing"
        case .SongStillDownloading:
            return "The requested song is still downloading..."
        case .URLError(let urlString):
            return "Invalid URL: \(String(describing: urlString))"
        case .SongNotInLibError(let id):
            return "Song with id \(String(describing: id)) not found in library. This may be a communication glitch. Please try again..."
        case .SongAlreadyInUserLibError(let id):
            return "Song with id \(String(describing: id)) already in User Library."
        }
        
    }
}

enum SpotifyError: Error {
    case EmptyTextError
    case ServerError
    case AuthError
}
