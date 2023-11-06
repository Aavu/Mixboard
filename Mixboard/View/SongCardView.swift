//
//  SongCardView.swift
//  Mashup
//
//  Created by Raghavasimhan Sankaranarayanan on 10/13/22.
//

import SwiftUI

struct SongCardView: View {
    var spotifySong: Spotify.Track?
    var song: Song?
    
    let minFrameWidthForText: CGFloat = 100
    
    @ObservedObject var imageVM: ImageViewModel
    @EnvironmentObject var libVM: LibraryViewModel
    
    private let hasRemoveBtn: Bool
    
    init(spotifySong: Spotify.Track?, hasRemoveBtn: Bool = false) {
        self.spotifySong = spotifySong
        self.imageVM = ImageViewModel(imageUrl: spotifySong?.album.images[0].url)
        self.hasRemoveBtn = hasRemoveBtn
    }
    
    init(song: Song?, hasRemoveBtn: Bool = false) {
        self.song = song
        self.imageVM = ImageViewModel(imageUrl: song?.img_url)
        self.hasRemoveBtn = hasRemoveBtn
    }
    
    var body: some View {
        let title = song?.name ?? spotifySong?.name ?? "Song"
        let artist = song?.artist ?? spotifySong?.artists[0].name ?? "Artist"
        ZStack(alignment: .top) {
            Rectangle()
                .fill(imageVM.averageColor)
                .shadow(radius: 4)
            ZStack {
                GeometryReader { geo in
                    let padding: CGFloat = geo.size.height > 32 ? 8 : 4
                    HStack {
                        if geo.frame(in: .local).width >= minFrameWidthForText {
                            VStack(alignment: .leading) {    // Title and subtitle
                                StrokeText(text: title, width: 0.25, color: .black).font(geo.size.height > 32 && geo.size.width >= 150 ? .title3 : .callout)
                                if geo.size.height >= 72 && geo.size.width >= 100 {
                                    StrokeText(text: "", width: 0.25, color: .clear).font(.caption) // dummy
                                    StrokeText(text: artist, width: 0.25, color: .black).font(.body)
                                }
                            }
                            
                            Spacer()
                        }
                        ImageView(image: $imageVM.image)
                            .frame(height: max(0, geo.frame(in: .local).height - (padding * 2)))
                    }
                    .padding([.all], padding)
                }
            }
        }
    }
}

struct UserLibSongCardView: View {
    private var song: Song
    
    @ObservedObject var imageVM: ImageViewModel
    @ObservedObject var audioManager = AudioManager.shared
    @ObservedObject var backend = BackendManager.shared
    
    @EnvironmentObject var userLibVM: UserLibraryViewModel
    @EnvironmentObject var mashupVM: MashupViewModel
    
    init(song: Song) {
        self.song = song
        self.imageVM = ImageViewModel(imageUrl: song.img_url)
    }
    
    var body: some View {
        let title = song.name ?? "Name"
        let artist = song.artist ?? "Artist"
        let songId = song.id
        
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                Rectangle().foregroundColor(imageVM.averageColor).shadow(radius: 4)
                ZStack(alignment: .bottom) {
                    VStack {
                        GeometryReader { geo in
                            HStack {
                                VStack(alignment: .leading) {    // Title and subtitle
                                    StrokeText(text: title, width: 0.25, color: .black).font(.subheadline)
                                    StrokeText(text: "", width: 0.25, color: .clear).font(.caption) // dummy
                                    StrokeText(text: artist, width: 0.25, color: .black).font(.caption)
                                }
                                
                                Spacer(minLength: 0)
                                
                                ImageView(image: $imageVM.image).shadow(radius: 4)
                                
                            }.padding([.all], 4)
                        }
                        
                        
                        if let status = backend.downloadStatus[songId] {
                            if status.progress < UserLibraryViewModel.TOTAL_PROGRESS {
                                Rectangle().fill(.black).opacity(0.5).frame(height: 4)
                            }
                        }
                    }
                    
                    
                    if let status = backend.downloadStatus[songId] {
                        if status.progress < UserLibraryViewModel.TOTAL_PROGRESS {
                            VStack(alignment: .center, spacing: 2) {
                                if geo.size.height > 100 {
                                    StrokeText(text: status.description ?? "Downloading", width: 0.25, color: .black).font(.caption)
                                }
                                ZStack {
                                    Rectangle().frame(height: 8).foregroundColor(.BgColor)
                                    ProgressView(value: CGFloat(status.progress), total: CGFloat(UserLibraryViewModel.TOTAL_PROGRESS))
                                }
                            }
                        }
                    }
                }
                
                Button {
                    withAnimation {
                        userLibVM.removeSong(songId: song.id ) { err in
                            userLibVM.dragOffset[song.id ] = nil
                            if err != nil {
                                Logger.error(err)
                                return
                            }
                            mashupVM.deleteRegionsFor(songId: song.id )
                        }
                    }
                } label: {
                    ZStack {
                        Color.BgColor.shadow(radius: 4).cornerRadius(4)
                        Text("Remove").foregroundColor(.AccentColor)
                    }
                }
                .frame(height: 32)
                .opacity((userLibVM.isSelected[songId] ?? false) ? 1 : 0)
                .disabled(!(userLibVM.isSelected[songId] ?? false))
                .animation(.spring(), value: userLibVM.isSelected[songId])
                .transition(.opacity)
            }
            .blur(radius: (userLibVM.silenceOverlayText[songId] != nil) ? 4 : 0)
            .overlay(content: {
                if let txt = userLibVM.silenceOverlayText[songId] {
                    ZStack(alignment: .top) {
                        Color.red.opacity(0.5)
                        Text(txt).foregroundColor(.AccentColor).font(.headline).padding(.top, 4)
                    }
                }
            })
        }
        .frame(maxHeight: 150)
        .simultaneousGesture(TapGesture()
            .onEnded({
                if audioManager.isPlaying { return }
                withAnimation {
                    if userLibVM.isSelected[songId] == nil {
                        if !userLibVM.disableRemoveBtn {
                            userLibVM.isSelected[songId] = true
                        }
                    } else {
                        userLibVM.isSelected[songId] = nil
                    }
                    
                }
            })
        )
    }
}


// Reference: https://stackoverflow.com/questions/57334125/how-to-make-text-stroke-in-swiftui
struct StrokeText: View {
    let text: String
    let width: CGFloat
    let color: Color
    
    var body: some View {
        ZStack{
            ZStack{
                Text(text).offset(x:  width, y:  width)
                Text(text).offset(x: -width, y: -width)
                Text(text).offset(x: -width, y:  width)
                Text(text).offset(x:  width, y: -width)
            }
            .foregroundColor(color)
            Text(text)
        }.foregroundColor(.white)
    }
}

// artwork: URL(string:"https://i.scdn.co/image/ab67616d0000b2730c13d3d5a503c84fcc60ae94")!

struct SongCardView_Previews: PreviewProvider {
    static var previews: some View {
        SongCardView(song: nil).frame(width: 100, height: 32)
    }
}
