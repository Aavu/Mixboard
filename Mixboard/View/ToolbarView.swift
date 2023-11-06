//
//  ToolbarView.swift
//  Mashup
//
//  Created by Raghavasimhan Sankaranarayanan on 10/13/22.
//

import SwiftUI

struct ToolbarView: View {
    @EnvironmentObject var mashupVM: MashupViewModel
    @EnvironmentObject var userLibVM: UserLibraryViewModel
    @EnvironmentObject var historyVM: UserInfoViewModel
    
    @ObservedObject var audioManager = AudioManager.shared
    @ObservedObject var backend = BackendManager.shared
    
    var body: some View {
        ZStack(alignment: .top) {
            Rectangle().foregroundColor(.BgColor).shadow(radius: 8)
            HStack {
                // MARK: UserInfo Button
                Button {
                    withAnimation {
                        historyVM.showUserInfo = true
                    }
                } label: {
                    Image(systemName: "person.crop.circle")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .foregroundColor(.AccentColor)
                        .frame(width: 24)
                        .padding(.all, 6)
                        .padding(.leading, 10)
                }
                

                Spacer()
                
                Button {
                    if audioManager.isPlaying { return }
                    mashupVM.surpriseMe(songs: userLibVM.songs)
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 4).frame(width: 136)
                            .foregroundColor(.BgColor)
                            .shadow(radius:  4)

                        HStack {
                            Image(systemName: "shuffle").renderingMode(.template).foregroundColor(.SecondaryAccentColor)
                            Text("Surprise Me").foregroundColor(.SecondaryAccentColor)
                        }
                    }
                    .padding(.all, 6)
                    .zIndex(1)
                    .opacity(userLibVM.songs.count > 0 ? 1 : 0)
                    .opacity(audioManager.isPlaying ? 0.5 : 1)
                    
                }.disabled(backend.isGenerating || audioManager.isPlaying || userLibVM.songs.count == 0)

                Spacer()

                HStack {
                    // MARK: Backward 10 Button
                    Button {
                        // TODO: Replace hardcoded sample rate
                        audioManager.setCurrentPosition(position: audioManager.currentPosition - (44100 * 10))
                    } label: {
                        Image(systemName: "gobackward.10").font(.title2).foregroundColor(.AccentColor).opacity(mashupVM.readyToPlay ? 1 : 0.5)
                            .padding(.all, 6)
                    }
                    .disabled(!mashupVM.readyToPlay || mashupVM.isEmpty)
                    
                    // MARK: Play Button
                    Button {
                        handlePlayBtn()
                    } label: {
                        if backend.isGenerating {
                            ProgressView(value: CGFloat(backend.generationStatus?.progress ?? 50), total: 100).progressViewStyle(.circular)
                                .frame(width: 32)
                                .padding(.all, 6)
                        } else {
                            Image(systemName: audioManager.isPlaying ? "pause.fill" : "play.fill")
                                .renderingMode(.template)
                                .frame(width: 32)
                                .font(.title).foregroundColor(.AccentColor).opacity(mashupVM.isEmpty || backend.isGenerating || backend.isDownloading ? 0.5: 1)
                                .padding(.all, 6)
                        }
                    }
                    .disabled(mashupVM.isEmpty || backend.isGenerating || backend.isDownloading)
                    .allowsHitTesting(!backend.isDownloading)
                    .padding(.horizontal, 12)
                    
                    // MARK: Forward 10 Button
                    Button {
                        // TODO: Replace hardcoded sample rate
                        audioManager.setCurrentPosition(position: audioManager.currentPosition + (44100 * 10))
                    } label: {
                        Image(systemName: "goforward.10").font(.title2).foregroundColor(.AccentColor).opacity(mashupVM.readyToPlay ? 1 : 0.5)
                            .padding(.all, 6)
                    }
                    .disabled(!mashupVM.readyToPlay || mashupVM.isEmpty)
                }
                
                Spacer()
                
                Button {
                    mashupVM.clearCanvas()
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 4).frame(width: 120)
                            .foregroundColor(.BgColor)
                            .shadow(radius:  4)
                        Text("Clear Canvas").foregroundColor(.red)
                    }
                    .padding(.all, 6)
                    .zIndex(1)
                    .opacity(mashupVM.isEmpty ? 0: 1)
                }
                
                Spacer()
                
                Menu {
//                    Button {
//                    } label: {
//                        Text("Share Audio")
//                    }
                    
                    Button {
                        DatabaseManager.shared.saveLogsToDatabase(shouldClear: true)
                    } label: {
                        Text("Share Logs")
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up").renderingMode(.template).foregroundColor(.AccentColor)
                        .padding(.trailing, 16)
                    .padding(.all, 4)
                }
                
//                if let music = audioManager.currentMusic {
//                    ShareLink(item: audio, preview: SharePreview("Share"))
//                        .padding([.all], 16)
//                } else {
//                    Rectangle().fill(.clear).frame(width: 100)
//                }
            }
        }
        .onTapGesture {
            userLibVM.unselectAllSongs()
            mashupVM.unselectAllRegions()
        }
    }
    
    func handlePlayBtn() {
        func play() {
            if audioManager.isPlaying {
                audioManager.playOrPause()
            } else {
                audioManager.playOrPause()
            }
        }
        
        if mashupVM.readyToPlay {   // Play
            if !audioManager.isPlaying {
                mashupVM.soloAudios()
                mashupVM.muteAudios()
            }
            audioManager.playOrPause()
        } else {                    // Generate
            audioManager.reset()
            let uuid = UUID().uuidString
            mashupVM.generateMashup(uuid: uuid, lastSessionId: historyVM.getLastSessionId()) {
                guard let music = audioManager.currentMusic else {
                    Logger.error("No Music available")
                    return
                }
                audioManager.prepareForPlay(music: music, lengthInBars: mashupVM.getLastBeat())
                
                mashupVM.soloAudios()
                mashupVM.muteAudios()
                audioManager.playOrPause()
            }
        }
    }
}

//struct ToolbarView_Previews: PreviewProvider {
//    static var previews: some View {
//        ToolbarView()
//    }
//}
