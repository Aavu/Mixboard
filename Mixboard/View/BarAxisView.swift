//
//  BarAxisView.swift
//  Mashup
//
//  Created by Raghavasimhan Sankaranarayanan on 10/16/22.
//

import SwiftUI

struct BarAxisView: View {
    
    @ObservedObject var audioManager = AudioManager.shared
    
    @EnvironmentObject var mashup: MashupViewModel
    
    let width: CGFloat
    let height: CGFloat
    
    var body: some View {
        let len = Int(mashup.totalBeats / 4)
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle().fill(Color.BgColor)
                HStack(alignment: .bottom) {
                    ForEach((0..<len), id: \.self) { i in
                        Rectangle().frame(width: width, height: height).foregroundColor(.SecondaryAccentColor)
                        Spacer()
                        ForEach((0..<3)) { j in
                            Rectangle().frame(width: width, height: height / 2.5).foregroundColor(.SecondaryAccentColor).opacity(0.35)
                            Spacer()
                        }
                    }
                }
                
                //            HStack(alignment: .bottom, spacing: 0) {
                //                ForEach((0..<len), id: \.self) { i in
                //                    Text(String((i * 4) + 1))
                //                        .foregroundColor(.SecondaryAccentColor)
                //                        .font(.footnote)
                //                        .frame(maxWidth: .infinity, alignment: .leading)
                //                        .offset(x:4, y:-6)
                //                }
                //            }
            }
            
            .simultaneousGesture(SpatialTapGesture()
                .onEnded({ value in
                    audioManager.setProgress(progress: value.location.x / geo.size.width)
                })
            )
        }
        .frame(height: height)
    }
}

struct BarAxisView_Previews: PreviewProvider {
    static var previews: some View {
        BarAxisView(width: 2, height: 10)
    }
}
