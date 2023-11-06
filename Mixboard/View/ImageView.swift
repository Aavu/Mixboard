//
//  ImageView.swift
//  Mashup
//
//  Created by Raghavasimhan Sankaranarayanan on 10/13/22.
//

import SwiftUI

struct ImageView: View {
    static let defaultImg = UIImage(named: "artwork")
    @Binding var image: UIImage?
    
    var body: some View {
        Image(uiImage: image ?? ImageView.defaultImg!).resizable().aspectRatio(contentMode: .fit)
    }
}

struct ImageView_Previews: PreviewProvider {
    static var previews: some View {
        Text("")
//        ImageView(imageUrl: nil)
    }
}
