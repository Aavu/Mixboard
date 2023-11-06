//
//  SpotifyAuth.swift
//  Mixboard
//
//  Created by Raghavasimhan Sankaranarayanan on 11/12/22.
//  Adapted from https://github.com/spotipy-dev/spotipy/blob/master/spotipy/oauth2.py

import Foundation
import Combine

/// Base class for client and OAuth credential
class SpotifyAuthBase {
    enum TokenType: String {
        case Bearer
        case Basic
    }
    
    var clientIdSecret: Spotify.ClientIdSecret
    
    fileprivate var db = DatabaseManager.shared
    
    let OAUTH_TOKEN_URL = URL(string: "https://accounts.spotify.com/api/token")!
    
    init(clientIdSecret: Spotify.ClientIdSecret) {
        self.clientIdSecret = clientIdSecret
    }
    
    /// Checks if the token is expired
    /// - Parameter credential: The OAuth credential that needs to be checked
    /// - Returns: Bool indicating true if expired and false if valid
    func isTokenExpired(credential: Spotify.Credential) -> Bool {
        if let creationTime = credential.creationTime {
            return Date().timeIntervalSince(creationTime) >= Double(credential.expires_in)
        }
        
        // By default the token is expired
        return true
    }
    
    /// Create the header that has authorization. If access token is provided, it creates a Bearer header, else it creates a Basic header
    /// - Parameter accessToken: The access token acquired after authenticating
    /// - Returns: Network Header
    func getAuthHeader(accessToken: String? = nil) -> NetworkManager.Header {
        if let accessToken = accessToken {
            let value = "\(TokenType.Bearer.rawValue) \(accessToken)"
            return NetworkManager.Header(value: value, key: "Authorization")
        }
        
        let authToken = "\(clientIdSecret.clientId):\(clientIdSecret.clientSecret)".toBase64()
        let value = "\(TokenType.Basic.rawValue) \(authToken)"
        
        return NetworkManager.Header(value: value, key: "Authorization")
    }
    
    fileprivate func addCreationTime(credential: Spotify.Credential?) -> Spotify.Credential? {
        var temp = credential
        temp?.creationTime = Date()
        return temp
    }
    
    /// If a valid access token is in memory, returns it. Else fetches a new token and returns it
    /// - Parameters:
    ///   - completion: Return Access token as String if successful, else nil
    func getAccessToken(completion: @escaping (String?) -> ()) {
        fatalError("Must Override")
    }
    
    func updateDb(with credential: Spotify.Credential, type: Spotify.GrantType, completion: ((Error?) -> ())?) {
        db.setSpotifyAuthCredential(cred: credential, type: type) { err in
            if let completion = completion {
                completion(err)
            }
        }
    }
}


/// Creates a Client Credentials Flow Manager. The Client Credentials flow is used in server-to-server authentication. Only endpoints that do not access user information can be accessed. This means that endpoints that require authorization scopes cannot be accessed. The advantage, however, of this authorization flow is that it does not require any user interaction.
class SpotifyClientCredential: SpotifyAuthBase {
    var credential: Spotify.Credential?
    
    override init(clientIdSecret: Spotify.ClientIdSecret) {
        super.init(clientIdSecret: clientIdSecret)
        
        self.db.getSpotifyAuthCredential(for: .client) { cred, err in
            if let err = err {
                Logger.error(err)
                return
            }
            self.credential = cred
        }
    }
    
    /// If a valid access token is in memory, returns it. Else fetches a new token and returns it
    /// - Parameters:
    ///   - completion: Return Access token as String if successful, else nil
    override func getAccessToken(completion: @escaping (String?) -> ()) {
        if let credential = self.credential {
            if !isTokenExpired(credential: credential) {
                completion(credential.access_token)
                return
            }
            Logger.info("Token Expired")
        }
        Logger.info("Requesting New Token")
        requestAccessToken { cred in
            completion(cred?.access_token)
        }
    }
    
    /// Gets client credentials access token
    /// - Parameter completion: Return client crdential if successful, else nil
    private func requestAccessToken(completion: @escaping (Spotify.Credential?) -> ()) {
        let authHeader = getAuthHeader()
        let body = ["grant_type": "client_credentials"]
        
        Logger.debug("Sending post request to \(OAUTH_TOKEN_URL) with body \(body)")
        
        NetworkManager.request(url: OAUTH_TOKEN_URL, type: .POST, httpbody: NetworkManager.getAsHttpBody(body: body), contentType: .FORM, headers: [authHeader]) { [weak self] (credentials) in
            guard let strongSelf = self else {
                completion(nil)
                return
            }
            strongSelf.credential = strongSelf.addCreationTime(credential: credentials)
            if let cred = strongSelf.credential {
                strongSelf.updateDb(with: cred, type: .client) { err in
                    if let err = err { Logger.error(err) }
                    completion(cred)
                }
            } else { completion(nil) }
        }
    }
}


/// Implements Authorization Code Flow for Spotify's OAuth implementation.
class SpotifyOAuth: SpotifyAuthBase, ObservableObject {
    let OAUTH_AUTHORIZE_URL = "https://accounts.spotify.com/authorize"
    
    var scopes: [String]
    var showDialog: Bool
    
    var redirectUri: String
    var credential: Spotify.Credential?
    
    var code: String?
    
    @Published var isLinked = false
    
    init(clientIdSecret: Spotify.ClientIdSecret, redirectUri: String, scopes: [String], showDialog: Bool = true) {
        self.showDialog = showDialog
        self.scopes = scopes
        self.redirectUri = redirectUri
        super.init(clientIdSecret: clientIdSecret)
        
        self.db.getSpotifyAuthCredential(for: .code) { cred, err in
            if let err = err {
                Logger.error(err)
                return
            }
            self.credential = cred
            self.isLinked = (self.credential != nil)
        }
    }
    
    func getAuthUrl() -> URL {
        let clientId = clientIdSecret.clientId
        let scopes = self.scopes.joined(separator: "%20")
        let responseType = "code"
        
        let urlString = "\(OAUTH_AUTHORIZE_URL)?client_id=\(clientId)&redirect_uri=\(redirectUri)&scope=\(scopes)&response_type=\(responseType)&show_dialog=\(showDialog)"
        
        return URL(string: urlString)!
    }
    
    func validate(credential: Spotify.Credential, completion: @escaping (Spotify.Credential?) -> ()) {
        if isTokenExpired(credential: credential) {
            Logger.info("Token Expired. Acquiring a new one")
            if let refreshToken = credential.refresh_token {
                Logger.debug("Refreshing Token")
                refreshAccessToken(refreshToken: refreshToken, completion: completion)
            } else {
                Logger.critical("Refresh token not found")
                completion(nil)
            }
        } else { completion(credential) }
    }
    
    private func refreshAccessToken(refreshToken: String, completion: @escaping (Spotify.Credential?) -> ()) {
        let authHeader = getAuthHeader()
        
        let body = ["refresh_token": refreshToken,
                    "grant_type": "refresh_token"]
        
        Logger.debug("Sending post request to \(OAUTH_TOKEN_URL) with body \(body)")
        
        NetworkManager.request(url: OAUTH_TOKEN_URL, type: .POST, httpbody: NetworkManager.getAsHttpBody(body: body), contentType: .FORM, headers: [authHeader]) { [weak self] (credentials) in
            guard let strongSelf = self else { return }
            strongSelf.credential = strongSelf.addCreationTime(credential: credentials)
            strongSelf.credential = strongSelf.addCodeAndToken(credential: strongSelf.credential, refreshToken: refreshToken)
            if let cred = strongSelf.credential {
                strongSelf.updateDb(with: cred, type: .code) { err in
                    if let err = err { Logger.error(err) }
                    completion(cred)
                }
            } else { completion(nil) }
        }
    }
    
    func parseResponseCode(urlString: String) -> String? {
        if urlString.contains("error") {
            return nil
        }
        
        let splitUrl = urlString.split(separator: "?")
        code = String(splitUrl[1].split(separator: "=")[1])
        return code
    }
    
    /// Gets the access token for the app given the code
    func exchangeAccessToken(forCode code: String, completion: @escaping (String?) -> ()) {
        let authHeader = getAuthHeader()
        
        let body = ["redirect_uri": self.redirectUri,
                    "code": code,
                    "grant_type": "authorization_code"]
        
        Logger.debug("Sending post request to \(OAUTH_TOKEN_URL) with body \(body)")
        
        NetworkManager.request(url: OAUTH_TOKEN_URL, type: .POST, httpbody: NetworkManager.getAsHttpBody(body: body), contentType: .FORM, headers: [authHeader]) { [weak self] (credentials) in
            guard let strongSelf = self else { return }
            strongSelf.code = code
            strongSelf.credential = strongSelf.addCreationTime(credential: credentials)
            strongSelf.credential = strongSelf.addCodeAndToken(credential: strongSelf.credential)
            strongSelf.isLinked = (strongSelf.credential != nil)
            if let cred = strongSelf.credential {
                strongSelf.updateDb(with: cred, type: .code) { err in
                    if let err = err { Logger.error(err) }
                    completion(cred.access_token)
                }
            } else { completion(nil) }
        }
        
    }
    
    override func getAccessToken(completion: @escaping (String?) -> ()) {
        if let credential = credential {
            validate(credential: credential) { cred in
                completion(cred?.access_token)
            }
        } else {
            Logger.error("no credential found")
            completion(nil)
        }
    }
    
    private func addCodeAndToken(credential: Spotify.Credential?, refreshToken: String? = nil) -> Spotify.Credential? {
        var temp = credential
        temp?.code = self.code
        if let refreshToken = refreshToken {
            temp?.refresh_token = refreshToken
        }
        return temp
    }
}
