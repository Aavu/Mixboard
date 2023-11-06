//
//  LibraryView.swift
//  Mashup
//
//  Created by Raghavasimhan Sankaranarayanan on 10/13/22.
//

import SwiftUI

// MARK: Library View
struct LibraryView: View {
    
    @EnvironmentObject var spotifyVM: SpotifyViewModel
    @EnvironmentObject var libraryVM: LibraryViewModel
    @EnvironmentObject var userLibVM: UserLibraryViewModel
    @EnvironmentObject var mashupVM: MashupViewModel
    
    @ObservedObject var spotifyManager = SpotifyManager.shared
    
    @State var selectedSongId = [String: SongSource]()
    @State var canRandomize = true
    
    @State var freezeSelection = false
    
    @Binding var isPresented: Bool
    
    @State var selectedTab: Int = 0
    
    @State var draggingOffsetWidth: CGFloat = 0
    
    var didSelectSongs: ([String: SongSource]) -> ()
    
    let gridItem = [GridItem(.adaptive(minimum: 250))]
    
    init(isPresented: Binding<Bool>, didSelectSongs: @escaping ([String: SongSource]) -> ()) {
        self._isPresented = isPresented
        self.didSelectSongs = didSelectSongs
    }
    
    var body: some View {
        ZStack {
            Color.BgColor.ignoresSafeArea()
            VStack(spacing: 0) {
                TabBarView(isPresented: $isPresented, canRandomize: $canRandomize, searchText: selectedTab == 0 ? $libraryVM.searchText : $spotifyVM.searchText, handleDoneBtn: handleDoneBtn) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 32).fill(Color.SecondaryBgColor).shadow(radius: 4).padding(4)
                        HStack(spacing: 0) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 32).foregroundColor(.BgColor).frame(width: 120).padding(8)
                                    .offset(x: selectedTab == 0 ? -60 : 60)
                                
                                HStack(spacing: 32) {
                                    Button {
                                        withAnimation {
                                            selectedTab = 0
                                        }
                                    } label: {
                                        HStack {
                                            Image("MusicLib").renderingMode(.template).resizable().scaledToFit().padding(.vertical, 14)
                                            Text("Library")
                                        }
                                    }
                                    
                                    Button {
                                        withAnimation {
                                            selectedTab = 1
                                        }
                                    } label: {
                                        HStack {
                                            Image("Spotify").renderingMode(.original).resizable().scaledToFit().padding(.vertical, 14)
                                            Text("Spotify")
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .frame(width: 256)
                    
                }.frame(height: 48)
                    .padding(.bottom, 12)
                
                HStack {
                    VStack {
                        SearchBarView(searchText: selectedTab == 0 ? $libraryVM.searchText : $spotifyVM.searchText)
                            .padding([.horizontal], 8).padding(.bottom, 4)
                            .animation(.spring(), value: selectedSongId.count > 0)
                            .transition(.move(edge: .leading))
                        
                        GeometryReader { geo in
                            HStack(spacing: 0) {
                                LibContentView(contentType: .Library) {
                                    ForEach(libraryVM.songs, id: \.self) { song in
                                        SongCardView(song: song).frame(height: 100)
                                            .cornerRadius(8)
                                            .border((selectedSongId[song.id] != nil) ? Color.blue: .clear, width: 6)
                                            .overlay((freezeSelection && selectedSongId[song.id] == nil) ? .gray.opacity(0.75) : .clear)
                                            .blur(radius: (freezeSelection && selectedSongId[song.id] == nil) ? 2 : 0)
                                            .onTapGesture {
                                                handleTapGesture(id: song.id, songSource: .Library)
                                            }
                                    }
                                }
                                .frame(width: geo.frame(in: .global).width)
                                .opacity(selectedTab == 0 ? 1 : 0)
                                .onAppear {
                                    libraryVM.filterUserLibSongs(songs: userLibVM.songs)
                                }
                                .animation(.spring(), value: selectedSongId.count > 0)
                                .transition(.move(edge: .bottom))
                                
                                LibContentView(contentType: .Spotify) {
                                    ForEach(spotifyVM.songs, id: \.self) { song in
                                        SongCardView(spotifySong: song).frame(height: 100)
                                            .cornerRadius(8)
                                            .border((selectedSongId[song.id] != nil) ? Color.blue: .clear, width: 6)
                                            .overlay((freezeSelection && selectedSongId[song.id] == nil) ? .gray.opacity(0.75) : .clear)
                                            .blur(radius: (freezeSelection && selectedSongId[song.id] == nil) ? 2 : 0)
                                            .onTapGesture {
                                                handleTapGesture(id: song.id, songSource: .Spotify)
                                            }
                                    }
                                }
                                .frame(width: geo.frame(in: .global).width)
                                .opacity(selectedTab == 1 ? 1 : 0)
                                .animation(.spring(), value: selectedSongId.count > 0)
                                .transition(.move(edge: .bottom))
                                .environmentObject(spotifyVM)
                            }
                            .offset(x: (selectedTab == 0 ? 0: -geo.frame(in: .global).width) + draggingOffsetWidth)
                            .gesture(DragGesture()
                                .onEnded({ value in
                                    withAnimation(.spring()) {
                                        if value.predictedEndTranslation.width < 0 {
                                            selectedTab = 1
                                        }
                                        
                                        else if value.predictedEndTranslation.width > geo.frame(in: .global).width {
                                            selectedTab = 0
                                        }
                                    }
                                    
                                    draggingOffsetWidth = 0
                                })
                            )
                        }
                    }
                    
                    if selectedSongId.count > 0 {
                        SelectionView(selectedSongs: $selectedSongId)
                            .frame(width: 200)
                            .padding([.bottom, .horizontal], 4)
                            .animation(.spring(), value: selectedSongId.count > 0)
                            .transition(.move(edge: .trailing))
                            .ignoresSafeArea(edges: .bottom)
                    }
                }
            }
            .onChange(of: selectedSongId) { newValue in
                withAnimation {
                    freezeSelection = selectedSongId.count >= 4
                    canRandomize = selectedSongId.count == 0
                }
            }
            .onChange(of: spotifyManager.isLinked) { newValue in
                Logger.info("spotify linked: \(spotifyManager.isLinked)")
                spotifyManager.getRecommendations(numTracks: 100, forUser: spotifyManager.isLinked) { spotifyTracks in
                    if let tracks = spotifyTracks {
                        spotifyVM.recommendations = tracks
                    }
                }
            }
            .onAppear {
                spotifyManager.getRecommendations(numTracks: 100, forUser: spotifyManager.isLinked) { spotifyTracks in
                    if let tracks = spotifyTracks {
                        spotifyVM.recommendations = tracks
                    }
                }
                
                selectedSongId = [:]
                for song in userLibVM.songs {
                    selectedSongId[song.id] = .Library
                }
            }
        }
    }
    
    func handleTapGesture(id: String, songSource: SongSource) {
        if let ss = selectedSongId[id] {
            selectedSongId[id] = nil
            if userLibVM.contains(songId: id) {
                userLibVM.removeSong(songId: id) { err in
                    if let err = err {
                        Logger.error(err)
                        selectedSongId[id] = ss
                        return
                    }
                    
                    mashupVM.deleteRegionsFor(songId: id)
                }
            }
        } else {
            if (selectedSongId.count < 4) {
                selectedSongId[id] = songSource
            }
        }
        
        libraryVM.searchText = ""
        spotifyVM.searchText = ""
    }
    
    func handleDoneBtn() {
        var choices = selectedSongId
        if canRandomize {    // Choose randomly
            let songs = libraryVM.songs.choose(max(0, 4 - selectedSongId.count))
            for song in songs {
                choices[song.id] = .Library
            }
        }
        didSelectSongs(choices)
        isPresented = false
    }
}

// MARK: Selection View
struct SelectionView: View {
    @EnvironmentObject var spotifyVM: SpotifyViewModel
    @EnvironmentObject var libraryVM: LibraryViewModel
    @EnvironmentObject var userLibVM: UserLibraryViewModel
    @EnvironmentObject var mashupVM: MashupViewModel
    
    @Binding var selectedSongs: [String: SongSource]
    
    @State var libSongs = [Song]()
    @State var spotifySongs = [Spotify.Track]()
    
    @State var showOverlay = [String: Bool]()
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4).fill(Color.BgColor).shadow(radius: 4)
            VStack {
                ForEach(libSongs, id: \.self.id) { song in
                    SongCardView(song: song)
                        .cornerRadius(4)
                        .frame(maxHeight: 150)
                        .onTapGesture {
                            withAnimation {
                                showOverlay = [:]
                                showOverlay[song.id] = true
                            }
                        }
                        .overlay(alignment: .top) {
                            if let show = showOverlay[song.id], show {
                                Button {
                                    selectedSongs.removeValue(forKey: song.id)
                                    
                                    if userLibVM.contains(songId: song.id) {
                                        userLibVM.removeSong(songId: song.id) { err in
                                            if let err = err {
                                                Logger.error(err)
                                                return
                                            }
                                            mashupVM.deleteRegionsFor(songId: song.id)
                                        }
                                    }
                                } label: {
                                    ZStack {
                                        Color.BgColor.shadow(radius: 4).cornerRadius(4)
                                        Text("Remove").foregroundColor(.AccentColor)
                                    }
                                }
                                .frame(height: 32)
                                .transition(.opacity)
                            }
                        }
                }

                ForEach(spotifySongs, id: \.self.id) { song in
                    SongCardView(spotifySong: song)
                        .cornerRadius(4)
                        .frame(maxHeight: 150)
                        .onTapGesture {
                            withAnimation {
                                showOverlay = [:]
                                showOverlay[song.id] = true
                            }
                        }
                        .overlay(alignment: .top) {
                            if let show = showOverlay[song.id], show {
                                Button {
                                    selectedSongs.removeValue(forKey: song.id)
                                } label: {
                                    ZStack {
                                        Color.BgColor.shadow(radius: 4).cornerRadius(4)
                                        Text("Remove").foregroundColor(.AccentColor)
                                    }
                                }
                                .frame(height: 32)
                                .transition(.opacity)
                            }
                        }
                }
                
                Spacer()
                
                Button {
                    selectedSongs = [:]
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 4).foregroundColor(.BgColor).shadow(radius: 4)
                        Text("Clear").foregroundColor(.red)
                    }.frame(height: 32)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 2)
                }
            }
        }
        .onAppear {
            populateSongs()
        }
        .onChange(of: selectedSongs) { _ in
            populateSongs()
        }
        .onTapGesture {
            showOverlay = [:]
        }
    }
    
    func populateSongs() {
        showOverlay = [:]
        var newSongs = [String: SongSource]()
        var isNew = [String: Bool]()
        
        /// Retain all the songs that are already selected
        var songTemp = [Song]()
        var trackTemp = [Spotify.Track]()
        
        for song in libSongs {
            if selectedSongs[song.id] != nil {
                isNew[song.id] = false
                songTemp.append(song)
            }
        }
        libSongs = songTemp
        
        
        for song in spotifySongs {
            if selectedSongs[song.id] != nil {
                isNew[song.id] = false
                trackTemp.append(song)
            }
        }
        spotifySongs = trackTemp
        
        for (sId, src) in selectedSongs {
            if let isN = isNew[sId] {
                if isN {
                    newSongs[sId] = src
                }
            } else {
                newSongs[sId] = src
            }
        }
        
        /// Add the newly selected songs from selectedSongs dictionary
        for (songId, src) in newSongs {
            switch src {
            case .Spotify:
                spotifyVM.getSpotifySong(songId: songId) { spotifyTrack in
                    if let song = spotifyTrack {
                        spotifySongs.append(song)
                    }
                }
            case .Library:
                if let song = libraryVM.getSong(songId: songId) {
                    libSongs.append(song)
                } else {
                    /// If for some reason, it is not able to get the song from library. This is the fallback
                    spotifyVM.getSpotifySong(songId: songId) { spotifyTrack in
                        if let song = spotifyTrack {
                            spotifySongs.append(song)
                        }
                    }
                }
            }
        }
    }
}

// MARK: Library Content View
struct LibContentView<T: View>: View {
    let content: T
    let contentType: SongSource
    
    @EnvironmentObject var spotifyVM: SpotifyViewModel
    @ObservedObject var spotifyManager = SpotifyManager.shared
    
    init(contentType: SongSource, @ViewBuilder content: () -> T) {
        self.content = content()
        self.contentType = contentType
    }
    
    let gridItem = [GridItem(.adaptive(minimum: 225))]
    
    var body: some View {
        ZStack {
            Color.BgColor.ignoresSafeArea()
            VStack {
                if contentType == .Spotify {
                    if !spotifyManager.isLinked {
                        if let auth = spotifyManager.spotifyOAuth {
                            LinkSpotifyBtn(spotifyOAuth: auth)
                                .frame(width: 200, height: 48)
                        }
                    }
                }
                ScrollView {
                    LazyVGrid(columns: gridItem) {
                        content
                    }
                }
                .scrollDismissesKeyboard(.immediately)
            }.padding(.horizontal, 8)
        }
    }
}

struct TabBarView<T: View>: View {
    
    var titleContent: T

    @Binding var isPresented: Bool
    
    @Binding var canRandomize: Bool
    
    @Binding var searchText: String
    
    var handleDoneBtn: (() -> ())?
    
    init(isPresented: Binding<Bool>, canRandomize: Binding<Bool>, searchText: Binding<String>, handleDoneBtn: (() -> ())? = nil, @ViewBuilder titleContent: () -> T) {
        self._isPresented = isPresented
        self._canRandomize = canRandomize
        self._searchText = searchText
        self.handleDoneBtn = handleDoneBtn
        self.titleContent = titleContent()
    }
    
    var body: some View {
        ZStack {
            Color.BgColor.ignoresSafeArea()
            
            VStack(spacing: 4) {
                Spacer(minLength: 8)
                ZStack {
                    titleContent
                    HStack {
                        Button {
                            isPresented = false
                        } label: {
                            Image(systemName: "xmark").padding(8).font(.largeTitle).foregroundColor(.AccentColor)
                        }
                        Spacer()

                        Button {
                            if let handleDoneBtn = handleDoneBtn {
                                handleDoneBtn()
                            }
                        } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8).foregroundColor(.NeutralColor)
                                Text(canRandomize ? "Choose for Me!" : "Done").foregroundColor(.AccentColor)
                            }.frame(width: 128, height: 36).shadow(radius: 2)
                        }.padding(8)
                    }
                }
            }
        }
    }
}

//struct LibraryView_Previews: PreviewProvider {
//    static var previews: some View {
//        TabBarView(isPresented: .constant(true), selectedSongId: .constant(["132": .Library]))
//    }
//}
