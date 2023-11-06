//
//  ContentView.swift
//  Mashup
//
//  Created by Raghavasimhan Sankaranarayanan on 10/13/22.
//

import SwiftUI

struct MashupView: View {
    @EnvironmentObject var mashupVM: MashupViewModel
    
    @StateObject var libViewModel   = LibraryViewModel()
    @StateObject var userLibVM      = UserLibraryViewModel()
    @StateObject var spotifyVM      = SpotifyViewModel()
    @StateObject var userInfoVM     = UserInfoViewModel()
    
    var body: some View {
        ZStack(alignment: .leading) {
            HomeView()
                .environmentObject(spotifyVM)
                .environmentObject(libViewModel)
                .blur(radius: userInfoVM.showUserInfo ? 4 : 0)
                .disabled(userInfoVM.showUserInfo)
                .onTapGesture {
                    withAnimation {
                        userInfoVM.showUserInfo = false
                    }
                }
            
            ZStack {
                if userInfoVM.showUserInfo {
                    UserInfoView() { history in
                        userLibVM.restoreFromHistory(history: history)
                        mashupVM.restoreFromHistory(history: history)
                    }
                    .frame(width: 300)
                    .transition(.move(edge: .leading))
                    .ignoresSafeArea()
                    .shadow(radius: 8)
                }
            }
        }
        .environmentObject(mashupVM)
        .environmentObject(userLibVM)
        .environmentObject(userInfoVM)
        .onAppear {
            mashupVM.attach(userInfoVM: userInfoVM, userLibVM: userLibVM)
        }
    }
}

struct HomeView: View {
    @StateObject var audioManager = AudioManager.shared
    
    @EnvironmentObject var mashupVM: MashupViewModel
    @EnvironmentObject var spotifyVM: SpotifyViewModel
    @EnvironmentObject var libViewModel: LibraryViewModel
    @EnvironmentObject var userLibVM: UserLibraryViewModel
    
    @ObservedObject var backend = BackendManager.shared
    
    var body: some View {
        let showProgress = backend.isGenerating && mashupVM.showGenerationProgress
        ZStack {
            GeometryReader { geo in
                ZStack {
                    Color.BgColor.ignoresSafeArea()
                    
                    ZStack(alignment: .trailing) {
                        VStack{
                            HStack(alignment: .center, spacing: 0) {
                                UserLibraryView(numSongs: 4, cardWidth: mashupVM.userLibCardWidth)
                                    .zIndex(2)
                                    .allowsHitTesting(!audioManager.isPlaying)
                                
                                VStack {
                                    Spacer(minLength: 4)
                                    TracksView()
                                        .cornerRadius(4)
                                    Spacer(minLength: 4)
                                    
                                }.blur(radius: userLibVM.isFocuingSongs ? 4:0)
                                    .onTapGesture {
                                        if userLibVM.isFocuingSongs {
                                            withAnimation {
                                                userLibVM.unselectAllSongs()
                                            }
                                        }
                                    }
                                    .padding([.horizontal], 4)
                            }
                            ToolbarView()
                                .frame(height: max(36, min(64, 0.075 * geo.size.height)))
                        }
                        .disabled(backend.isGenerating)
                        .blur(radius: showProgress ? 8: 0)
                        .overlay(showProgress ? .black.opacity(0.5) : .clear)
                        .allowsHitTesting(!backend.isGenerating)
                        .environmentObject(libViewModel)
                        .environmentObject(spotifyVM)
                    }
                    .environmentObject(userLibVM)
                    .environmentObject(mashupVM)
                    
                    
                    if showProgress {
                        if let status = backend.generationStatus {
                            ProgressView(status.description ?? "Generating Mashup", value: CGFloat(status.progress), total: 100).padding()
                                .foregroundColor(.white)
                                .progressViewStyle(LinearProgressViewStyle(tint: .white))
                        }
                    }
                }
                
                .alert(isPresented: $mashupVM.showError, error: mashupVM.appError, actions: {
                    Button("Ok") {
                        mashupVM.appError = nil
                    }
                })
                .alert(isPresented: $userLibVM.showError, error: userLibVM.appError, actions: {
                    Button("Ok") {
                        userLibVM.appError = nil
                    }
                })
                .onAppear {
                    if mashupVM.loggedIn {
                        libViewModel.update(didUpdate: { err in
                            if let err = err {
                                if err._code == -1011 {
                                    mashupVM.appError = AppError(description: "Server not responding. Please try again later")
                                    mashupVM.appFailed = true
                                } else {
                                    mashupVM.appError = AppError(description: err.localizedDescription)
                                    Logger.error(err)
                                }
                                
                            }
                        })
                    } else {
                        Logger.trace("Not logged in")
                    }
                    mashupVM.userLibCardWidth = 0.22 * geo.size.width
                }
                .onChange(of: geo.size, perform: { newValue in
                    mashupVM.userLibCardWidth = 0.22 * geo.size.width
                })
                .ignoresSafeArea(.keyboard)
            }
        }
    }
}

struct MashupView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
            .environmentObject(MashupViewModel())
    }
}
