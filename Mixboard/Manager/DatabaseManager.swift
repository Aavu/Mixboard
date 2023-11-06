//
//  DatabaseManager.swift
//  Mixboard
//
//  Created by Raghavasimhan Sankaranarayanan on 11/9/22.
//

import Foundation
import Firebase

class DatabaseManager: ObservableObject {
    static var shared = DatabaseManager()
    
    private var historyRef: CollectionReference?
    private var logsRef: CollectionReference?
    private var spotifyRef: DocumentReference = Firestore.firestore().collection("spotify").document("credentials")
    private var userRef: DocumentReference?
    private var userId: String?
    
    func updateUserId(userId: String, completion: ((Error?) -> ())? = nil) {
        self.userId = userId
        userRef = Firestore.firestore().collection("users").document(userId)
        if let userRef = userRef {
            addCreationTime() { err in
                if let err = err {
                    if let completion = completion {
                        completion(err)
                    }
                    return
                }
                
                self.historyRef = userRef.collection("history")
                self.logsRef = userRef.collection("logs")
                if let completion = completion {
                    completion(nil)
                }
            }
        } else {
            if let completion = completion {
                completion(DatabaseError.UserReferenceEmpty)
            }
        }
    }
    
    private func addCreationTime(completion: ((Error?) -> ())? = nil) {
        userRef?.getDocument(completion: { snapshot, err in
            if let err = err {
                if let completion = completion {
                    completion(err)
                }
                return
            }
            
            if let _ = snapshot?.get("CreationTime") {
            } else {
                self.userRef?.setData(["CreationTime": Date()])
            }
            
            if let completion = completion {
                completion(nil)
            }
        })
    }
    
    func removeSpotifyCredential() {
        if let userRef = userRef {
            for type in Spotify.GrantType.allCases {
                userRef.updateData([getTypeString(for: type): FieldValue.delete()])
            }
        }
    }
    
    func getSpotifyClient(completion: @escaping (Spotify.ClientIdSecret) -> ()) {
        spotifyRef.addSnapshotListener({ snapshot, err in
            if let err = err {
                Logger.error(err)
                return
            }
            
            if let snapshot = snapshot {
                do {
                    let client = try snapshot.data(as: Spotify.ClientIdSecret.self)
                    completion(client)
                } catch (let e) {
                    Logger.error(e)
                }
            } else {
                Logger.error("snapshot is nil")
            }
        })

    }
    
    func setSpotifyAuthCredential(cred: Spotify.Credential, type: Spotify.GrantType, completion: @escaping (Error?) -> ()) {
        if let userRef = userRef {
            do {
                let data = try JSONEncoder().encode(cred)
                let json = try JSONSerialization.jsonObject(with: data)
                
                userRef.updateData([getTypeString(for: type): json], completion: completion)
            } catch (let err) {
                completion(err)
            }
        } else {
            Logger.error("userRef is nil for id: \(String(describing: userId))")
            completion(DatabaseError.UserReferenceEmpty)
        }
    }
    
    func getTypeString(for type: Spotify.GrantType) -> String {
        switch type {
        case .code:
            return "userCredential"
        case .client:
            return "clientCredential"
        }
    }
    
    func getSpotifyAuthCredential(for type:Spotify.GrantType, completion: @escaping (Spotify.Credential?, Error?) -> ()) {
        if let userRef = userRef {
            userRef.getDocument { doc, err in
                guard let userCred = doc?.get(self.getTypeString(for: type)) else {
                    completion(nil, nil)
                    return
                }
                do {
                    let json = userCred as! [String : Any]
                    let data = try JSONSerialization.data(withJSONObject: json)
                    let cred = try JSONDecoder().decode(Spotify.Credential.self, from: data)
                    completion(cred, nil)
                    return
                } catch (let e) {
                    Logger.error(e)
                    completion(nil, e)
                    return
                }
                
            }
        } else {
            Logger.error("userRef is nil for id: \(String(describing: userId))")
            completion(nil, DatabaseError.UserReferenceEmpty)
        }
    }
    
    func setSpotifyAuthCode(code: String, completion: @escaping (Error?) -> ()) {
        if let userRef = userRef {
            userRef.updateData(["spotifyAuthCode": code], completion: completion)
        } else {
            Logger.error("userRef is nil for id: \(String(describing: userId))")
            completion(DatabaseError.UserReferenceEmpty)
        }
    }
    
    func getSpotifyAuthCode(completion: @escaping (String?) -> ()) {
        if let userRef = userRef {
            userRef.getDocument(completion: { doc, err in
                let temp = doc?.get("spotifyAuthCode") as? String
                completion(temp)
                return
            })
        } else {
            completion(nil)
        }
    }
    
    func add(history: History) {
        do {
            if let uuid = history.id {
                let _ = try historyRef?.document(uuid).setData(from: history)
            }
        } catch (let err) {
            Logger.error(err)
        }
    }
    
    func remove(history: History) {
        if let uuid = history.id {
            historyRef?.document(uuid).delete()
        }
    }
    
    func getHistories(completion: @escaping ([History]) -> ()) {
        if let historyRef = historyRef {
            historyRef.addSnapshotListener({ snapshot, err in
                if let err = err {
                    Logger.error(err)
                    completion([])
                    return
                }
                
                if let snapshot = snapshot {
                    let histories = snapshot.documents.compactMap { doc in
                        do {
                            var history = try doc.data(as: History.self)
                            
                            // Remove audio path if the file does not exist
                            if let audio = history.audio {
                                if !MashupFileManager.exists(file: audio.file) {
                                    history.audio = nil
                                }
                            }
                            return history
                        } catch (let e) {
                            Logger.error(e)
                        }
                        
                        return nil
                    }
                    
                    completion(histories)
                } else {
                    Logger.error("snapshot is nil")
                    completion([])
                }
            })
        } else {
            Logger.error("History ref is nil")
            completion([])
        }
    }
    
    func saveLogsToDatabase(shouldClear: Bool = true) {
        logsRef?.addDocument(data: [Date.now.formatted() : Logger.getLogs(shouldClear: shouldClear)])
    }
}
