//
//  LoginViewModel.swift
//  Mixboard
//
//  Created by Raghavasimhan Sankaranarayanan on 11/7/22.
//

import Foundation
import AuthenticationServices
import FirebaseAuth
import CryptoKit

class LoginViewModel: ObservableObject {
    /// A variable to denote if the user is currently signing up or signing in
    @Published var signUp = false
    
    /// The alert message that is shown to the user when alert pops up
    @Published var alertMsg = ""
    
    private var currentNonce: String?
    
    @Published var appleCredential: AuthCredential?
    @Published var emailCredential: AuthCredential?
    
    //Refer: https://firebase.google.com/docs/auth/ios/apple
    func handleSignInWithAppleRequest(request: ASAuthorizationAppleIDRequest) {
        request.requestedScopes = [.email, .fullName]
        let nonce = FirebaseManager.randomNonceString()
        currentNonce = nonce
        request.nonce = sha256(nonce)
    }
    
    func handleSignInWithAppleCompletion(result: Result<ASAuthorization, Error>, email: String, passwd: String, shouldLink: Bool, completion: @escaping (User?, Error?) -> ()) {
        switch result {
        case .failure(let err):
            Logger.error("Auth failure: \(err)")
            
        case .success(let auth):
            switch auth.credential {
            case let cred as ASAuthorizationAppleIDCredential:
                guard let nonce = currentNonce else {
                    fatalError("Invalid State. Current Nonce is already set without sending a request")
                }
                
                guard let token = cred.identityToken else {
                    Logger.error("Cannot get identity token")
                    return
                }
                
                guard let tokenString = String(data: token, encoding: .utf8) else {
                    Logger.error("Cannot Serialize identity token. \(token.debugDescription)")
                    return
                }
                
                appleCredential = FirebaseManager.getCredential(provider: .Apple, idToken: tokenString, rawNonce: nonce)
                
                if let appleCredential = appleCredential {
                    FirebaseManager.signInWithCredential(credential: appleCredential, email: email, passwd: passwd, shouldLink: shouldLink) {user, err in
                        completion(user, err)
                    }
                }
                
            default:
                break
            }
        }
    }
    
    @available(iOS 13, *)
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()
        
        return hashString
    }
}
