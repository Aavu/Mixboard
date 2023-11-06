//
//  HistoryView.swift
//  Mashup
//
//  Created by Raghavasimhan Sankaranarayanan on 10/18/22.
//

import SwiftUI

struct UserInfoView: View {
    
    @EnvironmentObject var userInfoVM: UserInfoViewModel
    
    @EnvironmentObject var mashupVM: MashupViewModel
    
    var onCompletion: ((History) -> ())
    
    var body: some View {
        ZStack {
            Color.BgColor
            VStack {
                Spacer(minLength: 50)
                List {
                    Section("History") {
                        ForEach(userInfoVM.histories, id: \.self.id) { history in
                            Button {
                                DispatchQueue.main.async {
                                    handleTap(history: history)
                                }
                            } label: {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 4).foregroundColor(history.id == userInfoVM.current?.id ? Color.SecondaryBgColor : .clear).opacity(0.5)
                                    Text(userInfoVM.getDateString(history: history)).foregroundColor(.accentColor)
                                }
                            }
                        }
                        .onDelete { idxSet in
                            userInfoVM.removeHistory(atOffsets: idxSet)
                        }
                    }
                }
                
                Spacer()
                
                Rectangle().frame(height: 1).foregroundColor(.SecondaryBgColor).opacity(0.5).padding(.vertical, 4)
                Button {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        FirebaseManager.signOut()
                        withAnimation {
                            userInfoVM.showUserInfo = false
                            mashupVM.currentEmail = nil
                            userInfoVM.histories = []
                        }
                    }
                    
                    
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 4).frame(width: 136, height: 36)
                            .foregroundColor(.SecondaryAccentColor)
                            .shadow(radius:  4)
                        
                        
                        Text("Sign Out").foregroundColor(.BgColor)
                    }
                }
                .padding()
                
            }
        }
        .onAppear {
            if let email = mashupVM.currentEmail {
                userInfoVM.dbManager.updateUserId(userId: email) { err in
                    if let err = err {
                        Logger.error(err)
                        return
                    }
                    userInfoVM.dbManager.getHistories(completion: { histories in
                        userInfoVM.histories = histories
                    })
                }
                
            }
        }
    }
    
    func handleTap(history: History) {
        userInfoVM.current = history
        onCompletion(history)
        
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            withAnimation {
                userInfoVM.showUserInfo = false
            }
        }
    }
}

struct UserInfoView_Previews: PreviewProvider {
    static var previews: some View {
        UserInfoView() { history in
            
        }
    }
}
