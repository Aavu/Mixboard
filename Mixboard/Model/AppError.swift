//
//  AppError.swift
//  Mashup
//
//  Created by Raghavasimhan Sankaranarayanan on 10/19/22.
//

import Foundation

/// Global error handle
struct AppError: Identifiable, LocalizedError {
    let id = UUID()
    let errorDescription: String?
    
    init(description: String?) {
        self.errorDescription = description
//        Log.error("AppError: \(self.errorDescription ?? "")")
    }
}
