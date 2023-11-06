//
//  Elements.swift
//  Mixboard
//
//  Created by Raghavasimhan Sankaranarayanan on 11/8/22.
//

import SwiftUI

struct PasswordField: View {
    let title: String
    
    @Binding var passwd:String
    
    @State var showPasswd = false
    var body: some View {
        ZStack(alignment: .trailing) {
            Group {
                if showPasswd {
                    TextField(title, text: $passwd)
                } else {
                    SecureField(title, text: $passwd)
                }
            }
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled(true)
            .padding(.all, 8)
            .background(
                Color.BgColor
                    .cornerRadius(4)
                    .shadow(color: .black.opacity(0.2), radius: 2, x: 2, y: 2)
            )
            .textFieldStyle(.plain)
            .foregroundColor(.AccentColor)
            
            
            Image(systemName: showPasswd ? "eye.slash.fill" : "eye.fill")
                .foregroundColor(.SecondaryBgColor)
                .onLongPressGesture(minimumDuration: 60, perform: {
                    
                }, onPressingChanged: { value in
                    showPasswd = value
                })
//                .gesture(TapGesture()
//                    .updating($showPasswd, body: { _, showPasswd, _ in
//                        showPasswd = true
//                    })
//                )
                .padding(.all, 4)
        }
        .frame(height: 36)
        
    }
}

struct MBTextField: View {
    var title: String
    @Binding var text: String
    
    var body: some View {
        TextField(title, text: $text)
            .textContentType(.emailAddress)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled(true)
            .padding(.all, 8)
            .background(
                Color.BgColor
                    .cornerRadius(4)
                    .shadow(color: .black.opacity(0.2), radius: 2, x: 2, y: 2)
            )
            .textFieldStyle(.plain)
            .foregroundColor(.AccentColor)
    }
}

struct MBButton<T: View>: View {
    var action: () -> ()
    var label: T

    init(action: @escaping () -> (), @ViewBuilder label: () -> T) {
        self.action = action
        self.label = label()
    }
    
    var body: some View {
        Button {
            action()
        } label: {
            label
        }

    }
}

struct Elements_Previews: PreviewProvider {
    static var previews: some View {
        MBTextField(title: "title", text: .constant(""))
    }
}
