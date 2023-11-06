//
//  HapticManager.swift
//  Mashup
//
//  Created by Raghavasimhan Sankaranarayanan on 10/24/22.
//

import Foundation
import SwiftUI

class HapticManager {
    static let shared = HapticManager()
    
    func notify(type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type)
    }
    
    func impact(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
}
