//
//  UserLibraryView.swift
//  Mashup
//
//  Created by Raghavasimhan Sankaranarayanan on 10/13/22.
//

import SwiftUI

struct UserLibraryView: View {
    let numSongs: Int
    
    @State var isPresented = false
   
    @EnvironmentObject var mashup: MashupViewModel
    @EnvironmentObject var library: LibraryViewModel
    @EnvironmentObject var spotifyVM: SpotifyViewModel
    @EnvironmentObject var userLib: UserLibraryViewModel
    
    @ObservedObject var audioManager = AudioManager.shared
    @ObservedObject var backend = BackendManager.shared
    
    let cardWidth: CGFloat
    
    @State var dragLocation = Dictionary<String, CGPoint>()
    @State var isDragging = Dictionary<String, Bool>()
    @State var removingSong = false
    
    var body: some View {
            ZStack {
                RoundedRectangle(cornerRadius: 4).foregroundColor(.SecondaryBgColor).shadow(radius: 16).opacity(0.5)
                    .frame(width: cardWidth + 4)
                    .ignoresSafeArea(edges: [.vertical])
                
                VStack(spacing: 4) {
                    if userLib.songs.count > 0 {
                        Button {
                            handleRemoveAllSongs()
                        } label: {
                            ZStack {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 4).frame(height: 32)
                                        .foregroundColor(.BgColor)
                                        .shadow(radius:  4)
                                    Text("Remove all").foregroundColor(.red)
                                }
                                .opacity(removingSong || userLib.disableRemoveBtn || audioManager.isPlaying ? 0.5: 1)

                                if removingSong {
                                    ProgressView()
                                }
                            }
                            .frame(width:cardWidth)
                        }
                        .animation(.spring(), value: userLib.songs.count)
                        .transition(.move(edge: .top))
                        .allowsHitTesting(!(removingSong || userLib.disableRemoveBtn))
                    }

                    
                    ForEach(userLib.songs, id: \.self) { song in
                        ZStack {
                            if userLib.dragOffset[song.id]?.width ?? 0 > 0 {
                                UserLibSongCardView(song: song)
                                    .frame(width: cardWidth)
                                    .environmentObject(userLib)
                            }

                            UserLibSongCardView(song: song)
                                .frame(width: cardWidth)
                                .frame(maxHeight: (isDragging[song.id] ?? false) ? mashup.tracksViewSize.height / 4 : nil)
                                .offset(userLib.dragOffset[song.id] ?? .zero)
                                .environmentObject(userLib)
                                .gesture(DragGesture(coordinateSpace: .global)
                                    .onChanged({ value in
                                        handleDragChanged(song: song, value: value)
                                    })

                                    .onEnded({ value in
                                        handleDragEnded(song: song, value: value)
                                    })
                                )
                                .simultaneousGesture(TapGesture()
                                    .onEnded({ value in
                                        withAnimation {
                                            mashup.unselectAllRegions()
                                        }
                                    })
                                )
                                .onAppear {
                                    userLib.dragOffset[song.id] = .zero
                                }
                        }
                }

                if !mashup.appFailed {
                    if mashup.loggedIn {
                        Spacer()
                        if userLib.songs.count < numSongs {
                            Button {
                                isPresented.toggle()
                            } label: {
                                VStack {
                                    Image(systemName: "plus.circle").foregroundColor(.AccentColor).padding(.all, 4).font(.title)
                                    Text("Add Songs").foregroundColor(.AccentColor).font(.subheadline)
                                }
                            }
                        }
                    } else {
                        ProgressView {
                            Text("Connecting to Server")
                        }
                    }
                }
            }
            .padding([.vertical], 16)
        }.sheet(isPresented: $isPresented) {
            LibraryView(isPresented: $isPresented) { results in
                if results.count > 0 {
                    userLib.addSongs(songIds: results)
                    mashup.updateRegionState(.New)
                }
            }
        }
        .onAppear {
            userLib.attachViewModels(mashupVM: mashup, library: library, spotifyViewModel: spotifyVM)
        }
        .onTapGesture {
            withAnimation {
                userLib.unselectAllSongs()
                mashup.unselectAllRegions()
            }
        }
        .onChange(of: userLib.canRemoveSong) { newValue in
            userLib.disableRemoveBtn = userLib.shouldDisableRemove()
        }
        
    }

    func handleRemoveAllSongs() {
        removingSong = true
        
        let numSongs = userLib.songs.count
        var removeCount = 0
        for song in userLib.songs {
            userLib.removeSong(songId: song.id) { err in
                if let err = err {
                    Logger.error("Unable to remove song with id: \(song.id). \(err)")
                    removingSong = false
                }
                
                mashup.deleteRegionsFor(songId: song.id)
                
                removeCount += 1
                
                if removeCount == numSongs {
                    removingSong = false
                    mashup.isEmpty = true
                }
            }

        }
    }
    
    func handleDragChanged(song: Song, value: DragGesture.Value) {
        userLib.unselectAllSongs()
        dragLocation[song.id] = value.location
        isDragging[song.id] = true
        let lane = mashup.getLaneForLocation(location: dragLocation[song.id]!)
        if let lane = lane {
            if !userLib.hasNonSilentBoundsFor(song: song, lane: lane) {
                withAnimation {
                    userLib.silenceOverlayText[song.id] = "No \(lane.getName()) in song"
                }
            } else {
                withAnimation {
                    userLib.silenceOverlayText[song.id] = nil
                }
            }
            
            
        }
        withAnimation {
            userLib.dragOffset[song.id] = value.translation
        }
    }
    
    func handleDragEnded(song: Song, value: DragGesture.Value) {
        isDragging[song.id] = false
        
        if value.predictedEndLocation.x < 0 {
            var shouldRemove = true
            withAnimation(.linear(duration: 0.25)) {
                if backend.isDownloading {
                    userLib.dragOffset[song.id] = .zero
                    shouldRemove = false
                } else {
                    userLib.dragOffset[song.id] = value.predictedEndTranslation
                }
            }
            
            
            if shouldRemove {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    userLib.removeSong(songId: song.id) { err in
                        userLib.dragOffset[song.id] = nil
                        if err != nil { return }
                        mashup.deleteRegionsFor(songId: song.id)
                    }
                }
            }
            
        } else {
            var success = false
            if let loc = dragLocation[song.id] {
                let lane = mashup.getLaneForLocation(location: loc)
                if let lane = lane {
                    if userLib.hasNonSilentBoundsFor(song: song, lane: lane) {
                        success = mashup.handleDropRegion(songId: song.id, dropLocation: dragLocation[song.id]!)
                        dragLocation[song.id]? = .zero
                        if success {
                            userLib.dragOffset[song.id] = .zero
                        }
                    }
                }
            }
            
            if !success {
                withAnimation {
                    userLib.silenceOverlayText[song.id] = nil
                    userLib.dragOffset[song.id] = .zero
                }
                HapticManager.shared.notify(type: .error)
            }
        }
    }
}

struct UserLibraryView_Previews: PreviewProvider {
    static var previews: some View {
        UserLibraryView(numSongs: 4, cardWidth: 144)
    }
}
