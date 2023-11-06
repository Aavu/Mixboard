//
//  FirebaseManager.swift
//  Mixboard
//
//  Created by Raghavasimhan Sankaranarayanan on 11/7/22.
//

import Foundation
import Firebase
import FirebaseAuth
import SwiftUI

class FirebaseManager {
    // Refer: https://stackoverflow.com/questions/41375219/how-to-manage-users-different-authentication-in-firebase
//    static var iCloudKeyStore = NSUbiquitousKeyValueStore()
    
    static func getCurrentUser() -> User? {
        return Auth.auth().currentUser
    }
    
    static func createUser(email: String, passwd: String, completion: @escaping (User?, Error?) -> ()) {
        Auth.auth().createUser(withEmail: email, password: passwd) { dataResult, err in
            var linking = false
            if let err = err {
                let nsErr = (err as NSError)
                
                if nsErr.code == 17007 {
                    linking = true
                    Logger.warn("User already has an account.")
                    completion(dataResult?.user, err)
                }
            }
            
            if !linking {
                completion(dataResult?.user, err)
            }
        }
    }
    
    static func signInWithEmail(email: String, password: String, completion: @escaping (User?, Error?) -> ()) {
        Auth.auth().signIn(withEmail: email, password: password) { dataResult, err in
            completion(dataResult?.user, err)
        }
    }
    
    static func signInWithCredential(credential: AuthCredential, email: String, passwd: String, shouldLink: Bool, completion: @escaping (User?, Error?) -> ()) {
        Auth.auth().signIn(with: credential) { dataResult, err in
            var retErr = err
            if let err = err {
                Logger.error(err)
            }
            
            if shouldLink {
                let cred = EmailAuthProvider.credential(withEmail: email, password: passwd)
                linkAccount(credential: cred) { user, err in
                    if let _ = user {
                        Logger.info("Successfully linked accounts")
                    }
                    
                    retErr = err
                    return
                }
            }
            completion(dataResult?.user, retErr)
        }
    }
    
    static func signInWithToken(customToken: String, completion: @escaping (AuthDataResult?, Error?) -> ()) {
        Auth.auth().signIn(withCustomToken: customToken) { dataResult, err in
            completion(dataResult, err)
        }
    }
    
    static func getCredential(provider: LoginProvider, idToken: String, rawNonce: String) -> AuthCredential {
        return OAuthProvider.credential(withProviderID: provider.rawValue, idToken: idToken, rawNonce: rawNonce)
    }
    
    static func signOut() {
        do {
            try Auth.auth().signOut()
        } catch (let e) {
            Logger.error(e)
        }
    }
    
    static func linkAccount(credential: AuthCredential, completion:@escaping (User?, Error?) -> ()) {
        Auth.auth().currentUser?.link(with: credential) { result, err in
            if result?.user != nil {
                Logger.info("Successfully linked user")
            }
            
            if let err = err {
                Logger.error(err)
            }
            
            
            completion(result?.user, err)
    
        }
    }
    
    // Adapted from https://auth0.com/docs/api-auth/tutorials/nonce#generate-a-cryptographically-random-nonce
    static func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] =
        Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length
        
        while remainingLength > 0 {
            let randoms: [UInt8] = (0 ..< 16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess {
                    fatalError(
                        "Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)"
                    )
                }
                return random
            }
            
            randoms.forEach { random in
                if remainingLength == 0 {
                    return
                }
                
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        
        return result
    }
}
