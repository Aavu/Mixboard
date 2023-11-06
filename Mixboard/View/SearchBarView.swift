//
//  SearchBarView.swift
//  Mashup
//
//  Created by Raghavasimhan Sankaranarayanan on 10/17/22.
//

import SwiftUI

struct SearchBarView: View {
    
    @Binding var searchText: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundColor(.AccentColor)
            TextField("Search Song, album or artist", text: $searchText)
                .foregroundColor(.AccentColor)
                .overlay(
                    Button(action: {
                        UIApplication.shared.endEditing()
                        searchText = ""
                    }, label: {
                        Image(systemName: "xmark.circle")
                            .foregroundColor(.AccentColor)
                            .padding()
                            .offset(x:8)
                            .opacity(searchText.isEmpty ? 0.0 : 1.0)
                    })
                    
                    , alignment: .trailing
                )
        }.padding(.all, 8)
            .background(
                RoundedRectangle(cornerRadius: 8).fill(Color.SecondaryBgColor)
                    .shadow(radius: 4)
            )
    }
}

struct SearchBarView_Previews: PreviewProvider {
    static var previews: some View {
        SearchBarView(searchText: .constant(""))
    }
}
