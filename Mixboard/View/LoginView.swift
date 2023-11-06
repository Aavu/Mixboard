//
//  LoginView.swift
//  Mixboard
//
//  Created by Raghavasimhan Sankaranarayanan on 11/5/22.
//

import SwiftUI
import AuthenticationServices
import FirebaseAuth

struct LoginView: View {
    
    @EnvironmentObject var mashupVM: MashupViewModel
    
    @StateObject var loginVM = LoginViewModel()
    
    @State var email = ""
    @State var firstName = ""
    @State var lastName = ""
    @State var password = ""
    @State var rePass = ""
    
    let btnHeight:CGFloat = 36
    
    @State var showAlert = false
    
    @State var showPasswd = false
    @State private var showLinkAccountAlert = false
    @State private var shouldLinkAccounts = false
    
    var body: some View {
        VStack {
            Text("Welcome to Mixboard!")
                .shadow(color: .black.opacity(0.2), radius: 2, x: 2, y: 2)
                .foregroundColor(.SecondaryAccentColor)
                .font(.largeTitle)
                .fontWeight(.semibold)
                .padding(.bottom, 8)
            
            VStack {
                
                if loginVM.signUp {
                    HStack {
                        MBTextField(title: "First Name", text: $firstName)
                        MBTextField(title: "Last Name", text: $lastName)
                    }.transition(.move(edge: .bottom))
                }
                
                MBTextField(title: "Email", text: $email)
                PasswordField(title: "Password", passwd: $password)
                
                if loginVM.signUp {
                    PasswordField(title: "Retype password", passwd: $rePass)
                        .transition(.move(edge: .top))
                }
                
                HStack {
                    if !loginVM.signUp {
                        // MARK: Login Btn
                        Button {
                            handleSignInBtn()
                        } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: 4)
                                    .frame(height: btnHeight)
                                    .foregroundColor(.SecondaryBgColor)
                                    .shadow(radius: 2, x: 2, y: 2)
                                
                                Text("Login").foregroundColor(.AccentColor)
                            }
                        }
                        .transition(.opacity)
                        
                        Spacer(minLength: 16)
                    }
                    
                    // MARK: Signup Btn
                    Button {
                        handleSignUpBtn()
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 4)
                                .frame(height: btnHeight)
                                .foregroundColor(.SecondaryAccentColor)
                                .shadow(radius: 2, x: 2, y: 2)
                            
                            Text("Sign Up").foregroundColor(.BgColor)
                        }
                    }
                    .alert(Text(loginVM.alertMsg), isPresented: $showAlert) {
                        Button("Ok") {
                            showAlert = false
                        }
                    }
                    .alert(isPresented: $showLinkAccountAlert) {
                        Alert(title: Text("Account with this email already exists. Should I link them?"),
                              message: Text("Please login using Sign in with apple to link."), primaryButton: .default(Text("Link"), action: {
                            showLinkAccountAlert = false
                            shouldLinkAccounts = true
                            
                        }), secondaryButton: .cancel(Text("Cancel"), action: {
                            showLinkAccountAlert = false
                            shouldLinkAccounts = false
                        }))
                    }
                }
                .padding([.vertical], 4)
                
                if loginVM.signUp {
                    HStack {
                        Text("Already have an account?").foregroundColor(.SecondaryAccentColor)
                        Button {
                            withAnimation {
                                loginVM.signUp = false
                            }
                        } label: {
                            Text("Login").foregroundColor(.AccentColor)
                        }
                    }
                }
                
                VStack {
                    RoundedRectangle(cornerRadius: 0.5).fill(.black.opacity(0.5)).frame(height: 1).padding(.vertical, 4)
                    
                    // MARK: Sign in with Apple
                    SignInWithAppleButton { request in
                        loginVM.handleSignInWithAppleRequest(request: request)
                    } onCompletion: { result in
                        loginVM.handleSignInWithAppleCompletion(result: result, email: email, passwd: password, shouldLink: shouldLinkAccounts) { user, err in
                            if let err = err {
                                Logger.error(err)
                                return
                            }
                            
                            // You will get email and name only once!
                            if let em = user?.email {
                                mashupVM.currentEmail = em
                                mashupVM.loggedIn = true
                                mashupVM.createNewSession()
                            } else {
                                Logger.error("Unable to get email")
                                return
                            }
                        }
                    }.frame(maxWidth: 375, maxHeight: btnHeight)
                        .shadow(radius: 2, x: 2, y: 2)
                }
                .padding([.vertical], 4)
            }
            .frame(maxWidth: 400)
            .padding()
        }
    }
    
    func handleSignUpBtn() {
        if loginVM.signUp {
            if email.isEmpty || password.isEmpty || rePass.isEmpty || firstName.isEmpty || lastName.isEmpty {
                showAlert = true
                loginVM.alertMsg = "Please fill in all fields"
            } else {
                if password == rePass {
                    
                    FirebaseManager.createUser(email: email, passwd: password) {user, err in
                        if let err = err {
                            Logger.error(err)
                            
                            let nsErr = err as NSError
                            if nsErr.code == 17094 || nsErr.code == 17007 {
                                Auth.auth().fetchSignInMethods(forEmail: email) { providers, err in
                                    if let providers = providers {
                                        for p in providers  {
                                            if p == "password" {
                                                mashupVM.appError = AppError(description: "Account already Exists. Please Sign in")
                                                return
                                            }
                                        }
                                    }
                                    showLinkAccountAlert = true
                                }
                                
                                return
                            } else {
                                mashupVM.appError = AppError(description: err.localizedDescription)
                                return
                            }
                        }
                        
                        mashupVM.currentEmail = email
                        mashupVM.loggedIn = true
                        mashupVM.createNewSession()
                    }
                    
                } else {
                    showAlert = true
                    loginVM.alertMsg = "Passwords don't match. Try again"
                }
            }
        } else {
            withAnimation {
                loginVM.signUp = true
            }
        }
    }
    
    func handleSignInBtn() {
        if email.isEmpty || password.isEmpty {
            loginVM.alertMsg = "Please fill in all fields"
            showAlert = true
        } else {
            FirebaseManager.signInWithEmail(email: email, password: password) { user, err in
                if let err = err {
                    Logger.error(err)
                    
                    let nsErr = err as NSError
                    if nsErr.code == 17009 {
                        mashupVM.appError = AppError(description: "Account already Exists. Please use Sign in with Apple!")
                        return
                    }
                    mashupVM.appError = AppError(description: err.localizedDescription)
                    return
                }
                
                guard let _email = user?.email else {
                    Logger.error("Email is empty")
                    mashupVM.appError = AppError(description: "Email is empty")
                    return
                }
                
                mashupVM.currentEmail = _email
                mashupVM.loggedIn = true
                mashupVM.createNewSession()
            }
        }
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
    }
}
