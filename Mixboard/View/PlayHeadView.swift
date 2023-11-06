//
//  PlayHeadView.swift
//  Mashup
//
//  Created by Raghavasimhan Sankaranarayanan on 10/17/22.
//

import SwiftUI

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        
        return path
    }
}

struct PlayHeadView: View {
    var body: some View {
        VStack(spacing: 0.0) {
            Triangle().frame(width: 20, height: 20).foregroundColor(.black)
            ZStack {
                Rectangle().frame(width: 4).foregroundColor(.white).opacity(0.75)
                Rectangle().frame(width: 2).foregroundColor(.black)
            }
        }.opacity(0.6)
    }
}

struct PlayHeadView_Previews: PreviewProvider {
    static var previews: some View {
        PlayHeadView()
    }
}
