//
//  TracksView.swift
//  Mashup
//
//  Created by Raghavasimhan Sankaranarayanan on 10/13/22.
//

import SwiftUI

enum DragType {
    case None
    case start
    case end
    case horizontal
    case vertical
}


struct TracksView: View {
    
    @EnvironmentObject var mashup: MashupViewModel
    @EnvironmentObject var library: LibraryViewModel
    @EnvironmentObject var spotify: SpotifyViewModel
    @EnvironmentObject var userLib: UserLibraryViewModel
    
    @ObservedObject var audioManager = AudioManager.shared
    @ObservedObject var backend = BackendManager.shared
    
    @State var startX = Dictionary<UUID, CGFloat>()
    @State var endX = Dictionary<UUID, CGFloat>()
    @State var yPos = Dictionary<UUID, CGFloat>()
    
    @State var dragType: DragType = .None
    @State var dummyRegionView: RegionView?
    
    @State var barText = "long"
    
    @State var playHeadPosition: CGFloat = .zero
    
    var body: some View {
            ZStack(alignment: .leading) {
                VStack(spacing: 0.0) {
                    HStack(spacing: 0.0) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 4).foregroundColor(.SecondaryBgColor).shadow(radius: 4)
                            Button {
                                if mashup.totalBeats == 16 {
                                    mashup.setTotalBeats(beats: 32)
                                    barText = "long"
                                } else {
                                    mashup.setTotalBeats(beats: 16)
                                    barText = "short"
                                }
                            } label: {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 4).foregroundColor(.clear).shadow(radius: 4)
                                    HStack(spacing: 2) {
                                        Text(barText).fontWeight(.bold)
                                    }
                                }
                                
                            }
                            .disabled(audioManager.isPlaying || backend.isGenerating)
                        }
                        .frame(width: mashup.trackLabelWidth - 32, height: 20)
                        .padding(.trailing, 32)
                        
                        
                        
                        BarAxisView(width: 1, height: 22)
                            .environmentObject(mashup)
                    }
                    
                    GeometryReader { geo in
                        ZStack(alignment: .topLeading) {
                            if let dummyRegionView = dummyRegionView {
                                let laneMultiplier = CGFloat(Lane.allCases.firstIndex(of: dummyRegionView.lane)!)
                                dummyRegionView
                                    .frame(width: geo.size.width - mashup.trackLabelWidth, height: geo.size.height / 4)
                                    .offset(x: mashup.trackLabelWidth, y: (laneMultiplier * geo.size.height / 4) + (yPos[dummyRegionView.uuid] ?? 0))
                                    .zIndex(10)
                                    .transition(AnyTransition.identity)
                            }
                            VStack(spacing: 0.0) {
                                ForEach(Lane.allCases, id: \.self) { lane in
                                    ZStack {
                                        LaneView(lane: lane).cornerRadius(2)
                                        if let lanes = mashup.layoutInfo.lane[lane.rawValue] {
                                            ForEach(lanes.layout) { region in
                                                let song = userLib.get(songId: region.item.id)
                                                RegionView(lane: lane, uuid: region.id, song: song, dragType: $dragType, startX: $startX, endX: $endX)
                                                    .frame(width: geo.size.width - mashup.trackLabelWidth)
                                                    .offset(x: mashup.trackLabelWidth / 2, y: yPos[region.id] ?? 0)
                                                    .onAppear {
                                                        yPos[region.id] = 0
                                                    }
                                                    .zIndex(mashup.isSelected[region.id] ?? false ? 10 : region.zIndex)
                                                    .simultaneousGesture(DragGesture(coordinateSpace: .global)
                                                        .onChanged({ value in
                                                            userLib.unselectAllSongs()
                                                            if dragType == .None || dragType == .horizontal || dragType == .vertical {
                                                                if value.translation.height > 0 {
                                                                    dummyRegionView = RegionView(lane: lane, uuid: region.id, song: song, dragType: $dragType, startX: $startX, endX: $endX)
                                                                }

                                                                dragType = .vertical
                                                                withAnimation(.easeInOut(duration: 0.1)) {
                                                                    yPos[region.id] = value.translation.height
                                                                }
                                                                
                                                                if let l = mashup.getLaneForLocation(location: value.location) {
                                                                    if let song = song {
                                                                        let hasNSB = userLib.hasNonSilentBoundsFor(song: song, lane: l)
                                                                        withAnimation {
                                                                            userLib.silenceOverlayText[song.id] = hasNSB ? nil : "No \(l.getName()) in song"
                                                                        }
                                                                    }
                                                                }
                                                            }
                                                        })

                                                        .onEnded({ value in
                                                            dummyRegionView = nil
                                                            
                                                            if let song = song {
                                                                withAnimation {
                                                                    userLib.silenceOverlayText[song.id] = nil
                                                                }
                                                            }
                                                            
                                                            if let l = mashup.getLaneForLocation(location: value.location) {
                                                                if l != lane {
                                                                    if let song = song {
                                                                        if userLib.hasNonSilentBoundsFor(song: song, lane: l) {
                                                                            mashup.changeLane(regionId: region.id, currentLane: lane, newLane: l)
                                                                        }
                                                                    }
                                                                }
                                                            }
                                                            yPos[region.id] = 0
                                                            dragType = .None
                                                        })
                                                    )
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .onAppear {
                            mashup.tracksViewLocation = CGPoint(x: geo.frame(in: .global).minX + mashup.trackLabelWidth, y: geo.frame(in: .global).minY)
                            mashup.tracksViewSize = geo.frame(in: .global).size
                        }
                        
                        .onChange(of: geo.size) { newValue in
                            mashup.tracksViewLocation = CGPoint(x: geo.frame(in: .global).minX + mashup.trackLabelWidth, y: geo.frame(in: .global).minY)
                            mashup.tracksViewSize = geo.frame(in: .global).size
                        }
                    }
                }
                
                GeometryReader() { geo in
                    let totalWidth = geo.frame(in: .local).width - mashup.trackLabelWidth
                    let audioProgressPercentage = audioManager.timelineLengthSamples > 0 ? (CGFloat(audioManager.currentPosition) / CGFloat(audioManager.timelineLengthSamples)) : 0
                    PlayHeadView()
                    // For better touch response
                        .overlay(content: {
                            Rectangle().fill(.clear).frame(width: 24)
                        })
                        .offset(x: mashup.trackLabelWidth - 10)
                        .offset(x: audioProgressPercentage * totalWidth)
                        .simultaneousGesture(DragGesture(coordinateSpace: .local)
                            .onChanged({ value in
                                userLib.unselectAllSongs()
                                playHeadPosition = min(max(0, value.location.x - mashup.trackLabelWidth), totalWidth) / totalWidth
                            })
                        )
                        .onChange(of: playHeadPosition) { newValue in
                            audioManager.setProgress(progress: playHeadPosition)
                        }
                }
            }
            .onTapGesture {
                userLib.unselectAllSongs()
                mashup.unselectAllRegions()
            }
    }
}

struct LaneView: View {
    @EnvironmentObject var mashup: MashupViewModel
    
    let label: String
    let lane: Lane
    
    init(lane: Lane) {
        self.label = lane.getName()
        self.lane = lane
    }
    
    var body: some View {
        HStack(spacing: 0.0) {
            
            ZStack(alignment: .trailing) {
                Rectangle()
                    .foregroundColor(.NeutralColor)
                    .padding([.bottom, .top], 1)
                
                VStack {
                    Spacer(minLength: 0)
                    Text(label).font(.subheadline).fontWeight(.bold).foregroundColor(.BgColor).padding(.all, 16)
                    
                    if let l = mashup.layoutInfo.lane[lane.rawValue] {
                        Spacer(minLength: 0)
                        
                        HStack(spacing:2) {
                            MBButton {
                                mashup.handleMute(lane: lane)
                            } label: {
                                ZStack {
                                    Rectangle().fill(l.laneState == .Mute ? Color.red : Color.SecondaryBgColor)
                                    Image(systemName: "speaker.slash.fill")
                                        .renderingMode(.template).resizable().scaledToFit()
                                        .foregroundColor(l.laneState == .Mute ? Color.PureColor : Color.AccentColor)
                                        .padding(.all, 6)
                                }
                                .transition(.identity)
                                .animation(.none, value: l.laneState)
                            }
                            .frame(minHeight: 20, maxHeight: 32)
                            .padding(.bottom, 1)
                            
                            MBButton {
                                mashup.handleSolo(lane: lane)
                            } label: {
                                ZStack {
                                    Rectangle()
                                        .fill(l.laneState == .Solo ? Color.green : Color.SecondaryBgColor)
                                    Image(systemName: "headphones")
                                        .renderingMode(.template).resizable().scaledToFit()
                                        .foregroundColor(l.laneState == .Solo ? Color.PureColor : Color.AccentColor)
                                        .padding(.all, 6)
                                }
                                .transition(.identity)
                                .animation(.none, value: l.laneState)
                            }
                            .frame(minHeight: 20, maxHeight: 32)
                            .padding(.bottom, 1)
                            
                        }
                    }
                }
            }
            .frame(width: mashup.trackLabelWidth)
            
            Rectangle()
                .foregroundColor(.SecondaryBgColor).opacity(0.75)
                .padding([.bottom, .top], 1)
        }
        
    }
}

struct RegionView: View {
    
    @EnvironmentObject var mashup: MashupViewModel
    @EnvironmentObject var userLib: UserLibraryViewModel
    @ObservedObject var audioManager = AudioManager.shared
    
    let song: Song?
    
    @State var conversion: CGFloat = 1

    @Binding var endX: [UUID: CGFloat]
    @Binding var startX: [UUID: CGFloat]
    
    @State var lastStartX: CGFloat = 0
    @State var lastEndX: CGFloat = 0
    @State var lastWidth: CGFloat = 0

    let pad:CGFloat = 1
    
    @Binding var dragType: DragType
    
    let lane: Lane
    let uuid: UUID
    
    init(lane:Lane, uuid: UUID, song: Song?, dragType: Binding<DragType>, startX: Binding<[UUID: CGFloat]>, endX: Binding<[UUID: CGFloat]>) {
        self.lane = lane
        self.uuid = uuid
        self.song = song
        self._dragType = dragType
        self._startX = startX
        self._endX = endX
    }
    
    
    var body: some View {
        let start = startX[uuid] ?? 0
        let end = endX[uuid] ?? 0
        ZStack {
            let isSelected = mashup.isSelected[uuid] ?? false
            let width = end - start
            GeometryReader { geometry in
                SongCardView(song: song).frame(width: max(0, width - 2*pad)).background(.black)
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.1)) {
                            mashup.unselectAllRegions()
                            if !isSelected {
                                mashup.setSelected(uuid: uuid, isSelected: true)
                            }
                        }
                    }
                    .border(Color.NeutralColor, width: isSelected ? 4 : 0)
                    .animation(.easeInOut(duration: 0.1), value: isSelected)
                    .transition(.opacity)
                    .offset(x: start)
                    .gesture(DragGesture(minimumDistance: 0)
                        .onChanged({ value in
                            userLib.unselectAllSongs()
                            dragType = .horizontal
                            let tempStartX = min(max(0, lastStartX + value.translation.width), geometry.size.width - lastWidth)
                            let tempEndX = min(geometry.size.width, tempStartX + lastWidth)
                            
                            withAnimation(.easeInOut(duration: 0.1)) {
                                startX[uuid] = round(tempStartX / conversion) * conversion
                                endX[uuid] = round(tempEndX / conversion) * conversion
                            }
                            
                        })
                             
                        .onEnded({ value in
                            withAnimation(.easeInOut(duration: 0.1)) {
                                startX[uuid] = round(start / conversion) * conversion
                                endX[uuid] = round(end / conversion) * conversion
                            }
                            handleDragEnded(geometry: geometry)
                        })
                    )
                    .onAppear {
                        updateFrame(geometry: geometry)
                    }
                    .onChange(of: geometry.size) { _ in
                        updateFrame(geometry: geometry)
                    }
                    .onChange(of: mashup.totalBeats) { _ in
                        updateFrame(geometry: geometry)
                    }
                
                
                ZStack {
                    let handleWidth:CGFloat = 32
                    Rectangle()
                        .fill(LinearGradient(colors: [.black.opacity(0.2), .clear], startPoint: .leading, endPoint: .trailing))
                        .opacity(0.25)
                        .frame(width: handleWidth)
                        .offset(x: start)
                        .simultaneousGesture(DragGesture(minimumDistance: 0)
                            .onChanged({ value in
                                userLib.unselectAllSongs()
                                dragType = .start
                                let temp = max(0, lastStartX + value.translation.width)
                                if (endX[uuid]! - temp) >= conversion {
                                    withAnimation(.easeInOut(duration: 0.1)) {
                                        startX[uuid] = round(temp / conversion) * conversion
                                    }
                                }
                            })
                                .onEnded({ value in
                                    withAnimation(.easeInOut(duration: 0.1)) {
                                        startX[uuid] = round(start / conversion) * conversion
                                    }
                                    handleDragEnded(geometry: geometry)
                                })
                        )
                    Rectangle()
                        .fill(LinearGradient(colors: [.clear, .black.opacity(0.2)], startPoint: .leading, endPoint: .trailing))
                        .opacity(0.25)
                        .frame(width: handleWidth)
                        .offset(x: end - handleWidth - 2*pad)
                        .simultaneousGesture(DragGesture(minimumDistance: 0)
                            .onChanged({ value in
                                userLib.unselectAllSongs()
                                dragType = .end
                                let temp = min(geometry.size.width, lastEndX + value.translation.width)
                                if (temp - startX[uuid]!) >= conversion {
                                    withAnimation(.easeInOut(duration: 0.1)) {
                                        endX[uuid] = round(temp / conversion) * conversion
                                    }
                                }
                            })
                                .onEnded({ value in
                                    withAnimation(.easeInOut(duration: 0.1)) {
                                        endX[uuid] = round(end / conversion) * conversion
                                    }
                                    handleDragEnded(geometry: geometry)
                                })
                        )
                }
                
                if isSelected {
                    HStack(spacing: 2) {
                        MBButton {
                            mashup.setRegionState(regionId: uuid, state: .New)
                            mashup.readyToPlay = false
                        } label: {
                            ZStack {
                                Color.BgColor.shadow(radius: 4).cornerRadius(4)
                                HStack {
                                    Image(systemName: "shuffle").renderingMode(.template).foregroundColor(.AccentColor)
                                    if width > 200 {
                                        Text("Shuffle").foregroundColor(.AccentColor)
                                    }
                                }
                            }
                        }

                        
                        Button {
                            withAnimation(.easeInOut(duration: 0.1)) {
                                let _ = mashup.removeRegion(lane: lane, id: uuid)
                            }
                        } label: {
                            ZStack {
                                Color.BgColor.shadow(radius: 4).cornerRadius(4)
                                HStack {
                                    Image(systemName: "xmark").renderingMode(.template).foregroundColor(.red)
                                    if width > 200 {
                                        Text("Remove").foregroundColor(.red)
                                    }
                                }
                            }
                        }
                    }
                    .frame(width: width - pad, height: 32)
                    .offset(x: start)
                }
            }

        }
        .padding([.top, .bottom], 2*pad).padding([.leading, .trailing], pad)
        .allowsHitTesting(!audioManager.isPlaying)
    }
    
    func updateFrame(geometry: GeometryProxy) {
        conversion = geometry.frame(in: .local).width / CGFloat(mashup.totalBeats)
        if let region = mashup.getRegion(lane: lane, id: uuid) {
            let width = CGFloat(region.w) * conversion
            startX[uuid] = CGFloat(region.x) * conversion
            endX[uuid] = startX[uuid]! + width
            
            lastStartX = startX[uuid]!
            lastEndX = endX[uuid]!
            lastWidth = lastEndX - lastStartX
        }
    }
    
    func handleDragEnded(geometry: GeometryProxy) {
        dragType = .None
        let tempx = Int(round(startX[uuid]! / conversion))
        let length = Int(round((endX[uuid]! - startX[uuid]!) / conversion))
        let success = mashup.updateRegion(id: uuid, x: tempx, length: min(Int(mashup.totalBeats) - tempx, length))
        if success {
            startX[uuid] = CGFloat(tempx) * conversion
            endX[uuid] = CGFloat(length + tempx) * conversion
            lastStartX = startX[uuid]!
            lastEndX = endX[uuid]!
            lastWidth = lastEndX - lastStartX
        } else {
            startX[uuid] = lastStartX
            endX[uuid] = lastEndX
        }
    }
}

//struct TracksView_Previews: PreviewProvider {
//    static var previews: some View {
//        TracksView(playHeadPosition: .constant(0))
//    }
//}
