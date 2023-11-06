//
//  HistoryViewModel.swift
//  Mashup
//
//  Created by Raghavasimhan Sankaranarayanan on 10/18/22.
//

import Foundation
import SwiftUI

class UserInfoViewModel: ObservableObject {
    @Published var histories = [History]()
    @Published var current: History?
    @Published var showUserInfo = false
    
    @AppStorage("email") var currentEmail: String?
    
    @Published var dbManager = DatabaseManager.shared
    let formatter = DateFormatter()
    
    var lastSessionId: String?
    
    init() {
        formatter.timeStyle = .medium
        formatter.dateStyle = .medium
    }
    
    func add(history: History, updateCurrent: Bool = true) {
        if updateCurrent {
            DispatchQueue.main.async {
                self.current = history
            }
        }
        
        if histories.contains(history) {
            return
        }

        dbManager.add(history: history)
        
        self.histories.append(history)
        Logger.info("History for '\(String(describing: history.id))' saved!")
        lastSessionId = history.id
    }
    
    func remove(history: History) -> Bool {
        for i in (0..<histories.count) {
            if history.id == histories[i].id {
                removeHistory(at: i)
                return true
            }
        }
        
        return false
    }
    
    func removeHistory(at idx: Int) {
        let h = histories[idx]
        histories.remove(at: idx)
        dbManager.remove(history: h)
        Logger.info("History for '\(String(describing: h.id))' removed!")
        lastSessionId = nil
    }
    
    
    func removeHistory(atOffsets idxSet: IndexSet) {
        for idx in idxSet {
            removeHistory(at: idx)
        }
    }
    
    func isEmpty() -> Bool {
        return histories.isEmpty
    }
    
    func getDateString(history: History) -> String {
        return formatter.string(from: history.date)
    }
    
    func getLastSessionId() -> String? {
        return lastSessionId
    }
}
