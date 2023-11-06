//
//  TaskResult.swift
//  Mashup
//
//  Created by Raghavasimhan Sankaranarayanan on 10/17/22.
//

import Foundation

/// Result from http request for generate
struct TaskResult: Codable {
    struct Result: Codable {
        let snd: String
        let tempo: Float
    }
    
    let task_result: Result
}

/// Status of the generate request
struct TaskStatus: Codable {
    struct Status: Codable {
        var progress: Int
        var description: String?
    }
    
    let requestStatus: String
    let task_id: String
    let task_result: Status
}

/// This holds the region data from backend
struct TaskData: Codable {
    struct MBData: Codable {
        let id: String
        let snd: String
        let tempo: Double
        let position: Int64
        var lane: String
        let valid: Bool
        let start: Int64
        let end: Int64
    }
    
    let requestStatus: String
    let task_id: String
    let task_result: MBData
}

enum RequestStatus: String {
    case Success = "SUCCESS"
    case Progress = "PROGRESS"
    case Pending = "PENDING"
    case Failure = "FAILURE"
}
