//
//  BackendManager.swift
//  Mixboard
//
//  Created by Raghavasimhan Sankaranarayanan on 11/10/22.
//

import Foundation
import Combine
import SwiftUI

class BackendManager: ObservableObject {
    
    public static let shared = BackendManager()
    
    @AppStorage("email") private var email: String?
    
    @Published var isGenerating = false
    var generationTaskId: String?

    @Published var generationStatus: TaskStatus.Status?
    @Published var regionData: TaskData.MBData?
    @Published var downloadStatus = [String: TaskStatus.Status]() {
        didSet {
            isDownloading = downloadStatus.count > 0
        }
    }
    
    @Published private(set) var isDownloading = false
    
    
    private var numRegionsFetched = 0
    private let fetchRegionsQueue = DispatchQueue(label:"fetchRegionsQueue")
    var timer: AnyCancellable?
    
    /// Handle all redis clean up stuffs here
    func endSession(currentUserEmail: String?) {
        let url = URL(string: Config.SERVER + HttpRequests.SESSION_ENDED)!
        
        NetworkManager.request(url: url, type: .POST, httpbody: try? JSONSerialization.data(withJSONObject: ["email": currentUserEmail])) { completion in
            switch completion {
            case .failure(let e):
                Logger.error(e)
            case .finished:
                break
            }
        } completion: { (response:Dictionary<String, String>?) in
            Logger.info("Session ended because the app was terminated.")
        }
    }
    
    
    func addSong(songId: String, onCompletion:@escaping (Error?) -> ()) {
        let url = URL(string: Config.SERVER + HttpRequests.ADD_SONG)!
        
        if self.downloadStatus[songId] == nil {
            self.downloadStatus[songId] = TaskStatus.Status(progress: 5, description: "Waiting in queue")
        }
        
        NetworkManager.request(url: url, type: .POST, httpbody: try? JSONSerialization.data(withJSONObject: ["url" : songId, "email": email])) { completion in
            switch completion {
            case .failure(let e):
                Logger.error(e)
                DispatchQueue.main.async {
                    self.downloadStatus.removeValue(forKey: songId)
                    onCompletion(e)
                }
            case .finished:
                break
            }
        } completion: { (response:Dictionary<String, String>?) in
            guard let response = response else {
                DispatchQueue.main.async {
                    self.downloadStatus.removeValue(forKey: songId)
                    onCompletion(BackendError.ResponseEmpty)
                }
                
                return
            }
            
            if let taskId = response["task_id"] {
                self.updateStatus(taskId: taskId, status: self.downloadStatus[songId]!) { status in
                    self.downloadStatus[songId] = status
                } completion: { status, err in
                    DispatchQueue.main.async {
                        self.downloadStatus.removeValue(forKey: songId)
                        onCompletion(err)
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.downloadStatus.removeValue(forKey: songId)
                    onCompletion(BackendError.TaskIdEmpty)
                }
            }
        }
    }
    
    func removeSong(songId: String, onCompletion: @escaping (Error?) -> ()) {
        let url = URL(string: Config.SERVER + HttpRequests.REMOVE_SONG)!
        
        NetworkManager.request(url: url, type: .POST, httpbody: try? JSONSerialization.data(withJSONObject: ["url" : songId, "email": email])) { completion in
            switch completion {
            case .failure(let e):
                Logger.error(e)
                onCompletion(e)
            case .finished:
                break
            }
        } completion: { (response: Dictionary<String, String>?) in
            onCompletion(nil)
        }
    }
    
    func fetchRegion(regionId: String, tryNum: Int = 0, completion: @escaping (TaskData.MBData?, Error?)->()) {
        let url = URL(string: Config.SERVER + HttpRequests.REGION + "/" + regionId)!
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Application/json", forHTTPHeaderField: "Content-Type")
        
        URLSession.shared.dataTask(with: request) {data, response, err in
            guard let data = data, err == nil else {
                if let err = err {
                    Logger.error(err)
                    if err._code == -1001 {
                        if tryNum < 100 {
                            Logger.warn("Request timeout: trying again...")
                            self.fetchRegion(regionId: regionId, tryNum: tryNum + 1, completion: completion)
                            return
                        }
                    }
                    
                    DispatchQueue.main.async {
                        Logger.error(err)
                        completion(nil, err)
                        return
                    }
                }
                return
            }
            
            do {
                let data = try JSONDecoder().decode(TaskData.MBData.self, from: data)
                if data.valid {
                    completion(data, nil)
                } else {
                    Logger.trace("try num: \(tryNum)")
                    if tryNum >= 50 {
                        Logger.critical("Region fetch failed with region id \(regionId)")
                        completion(nil, BackendError.RegionDownloadError(regionId))
                    } else {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            if self.isDownloading {
                                self.generationStatus?.description = "Downloading Song"
                                self.generationStatus?.progress = 10
                            }
                            let num = self.isDownloading ? tryNum : tryNum + 1
                            self.fetchRegion(regionId: regionId, tryNum: num, completion: completion) // Recursive call
                        }
                    }
                }
            } catch let e {
                DispatchQueue.main.async {
                    if tryNum < 3 {
                        self.fetchRegion(regionId: regionId, tryNum: tryNum + 1, completion: completion)  //  Recursive call
                    } else {
                        Logger.error(e)
                        completion(nil, BackendError.RegionDownloadError(regionId))
                    }
                }
            }
            
        }.resume()
    }
    
    func updateRegionData(regionIds: [String], tryNum: Int = 0, statusCallback: @escaping (TaskData.MBData) -> (), completion: @escaping ()->()) {
        self.numRegionsFetched = 0
        var numRegionsToFetch = regionIds.count
        
        for regionId in regionIds {
            fetchRegion(regionId: regionId) { data, err in
                var complete = false
                
                if let err = err {
                    Logger.error(err)
                    self.fetchRegionsQueue.sync {
                        numRegionsToFetch -= 1
                        complete = numRegionsToFetch == 0
                    }
                    
                    statusCallback(TaskData.MBData(id: regionId, snd: "", tempo: 0, position: 0, lane: "", valid: false, start: 0, end: 0))
                }
                
                if let data = data, err == nil {
                    self.fetchRegionsQueue.sync {
                        self.numRegionsFetched += 1
                        DispatchQueue.main.async {
                            self.generationStatus?.description = "Fetched \(self.numRegionsFetched) regions"
                            self.generationStatus?.progress = (self.numRegionsFetched / regionIds.count) * 100
                        }
                    }
                    statusCallback(data)
                }
                
                Logger.info("Num regions fetched: \(self.numRegionsFetched), out of \(numRegionsToFetch)")
                
                self.fetchRegionsQueue.sync {
                    complete = self.numRegionsFetched >= numRegionsToFetch || complete
                }
                
                if complete {
                    self.updateRegionCompletion(regionIds: regionIds, completion)
                    return
                }
            }
        }
    }

    func updateRegionCompletion(regionIds: [String],_ completion: @escaping () -> ()) {
        let url = URL(string: Config.SERVER + HttpRequests.REGION_UPDATE_COMPLETION)!
        
        NetworkManager.request(url: url, type: .POST, httpbody: try? JSONSerialization.data(withJSONObject: ["regions": regionIds])) { completion in
            switch completion {
            case .failure(let e):
                Logger.error(e)
            case .finished:
                break
            }
        } completion: { (response:Dictionary<String, Int>?) in
            completion()
        }
    }
    
    func updateStatus(taskId: String, status: TaskStatus.Status, tryNum: Int = 0, statusCallback: @escaping (TaskStatus.Status?) -> (), completion: @escaping ( TaskStatus.Status?, Error?)->()) {
        if status.progress == 100 { return }
        
        let url = URL(string: Config.SERVER + HttpRequests.STATUS + "/" + taskId)!
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Application/json", forHTTPHeaderField: "Content-Type")
        
        URLSession.shared.dataTask(with: request) { data, response, err in
            guard let data = data, err == nil else {
                if let err = err {
                    Logger.error(err)
                    if err._code == -1001 {
                        if tryNum < 100 {
                            Logger.warn("Request timeout: trying again...")
                            self.updateStatus(taskId: taskId, status: status, tryNum: tryNum + 1, statusCallback: statusCallback, completion: completion)
                            return
                        }
                    }
                    
                    DispatchQueue.main.async {
                        Logger.error(err)
                        completion(nil, err)
                        return
                    }
                }
                return
            }
            
            do {
                let resp = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as! Dictionary<String, Any>
                Logger.debug(resp)
                if let stat = RequestStatus(rawValue: resp["requestStatus"] as! String) {
                    switch stat {
                    case .Progress:
                        let result = try JSONDecoder().decode(TaskStatus.self, from: data)
                        DispatchQueue.main.async {
                            statusCallback(result.task_result)
                            self.updateStatus(taskId: taskId, status: result.task_result, statusCallback: statusCallback, completion: completion)  //  Recursive call
                        }
                        return
                    case .Pending:
                        let result = try JSONDecoder().decode(TaskStatus.self, from: data)
                        DispatchQueue.main.async {
                            statusCallback(result.task_result)
                            self.updateStatus(taskId: taskId, status: result.task_result, statusCallback: statusCallback, completion: completion)  //  Recursive call
                        }

                        return
                    case .Success:
                        DispatchQueue.main.async {
                            let e_code = resp["task_result"] as! Int
                            var err: Error? = nil
                            if e_code == 1 {    // Song mismatch with spotify
                                err = BackendError.SongDownloadError
                            }
                            completion(TaskStatus.Status(progress: 100, description: "Completed!"), err)
                        }
                    case .Failure:
                        DispatchQueue.main.async {
                            completion(nil, BackendError.SongDownloadError)
                        }
                        return
                    }
                }
            } catch let e {
                DispatchQueue.main.async {
                    if tryNum < 3 {
                        self.updateStatus(taskId: taskId, status: status, tryNum: tryNum + 1, statusCallback: statusCallback, completion: completion)  //  Recursive call
                    } else {
                        Logger.error(e)
                        completion(nil, BackendError.SongDownloadError)
                    }
                }
            }
            
        }.resume()
    }
    
    
    func sendGenerateRequest(uuid: String, lastSessionId: String?, layout: Layout, regionIds: [String], statusCallback: @escaping (Audio?, BackendError?) -> (), onCompletion:@escaping (Layout?, Error?) -> ()) {
        let url = URL(string: Config.SERVER + HttpRequests.GENERATE)!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Application/json", forHTTPHeaderField: "Content-Type")
        
        if let email = email {
            let generateRequest = GenerateRequestPayload(data: layout.lane, email: email, sessionId: uuid, lastSessionId: lastSessionId)
            request.httpBody = try? JSONEncoder().encode(generateRequest)
        }
        
        isGenerating = true
        
        var newLayout = layout
        
        URLSession.shared.dataTask(with: request) { data, response, err in
            guard let _ = data, err == nil else {
                Logger.error(err)
                self.isGenerating = false
                onCompletion(nil, err)
                return
            }
            
            DispatchQueue.main.async {
                self.generationStatus = TaskStatus.Status(progress: 5, description: "Hold On! Creating some magic...")
            }
            
            self.updateRegionData(regionIds: regionIds) { mbData in
                if !mbData.valid {
                    statusCallback(nil, .RegionDownloadError(mbData.id))
                    return
                }

                Logger.debug("fetched: \(mbData.id)")

                guard let audioData = Data(base64Encoded: mbData.snd) else {
                    statusCallback(nil, .DecodingError)
                    return
                }

                let tempFile = MashupFileManager.saveAudio(data: audioData, name: mbData.id, ext: "aac")

                if let tempFile = tempFile {
                    statusCallback(Audio(file: tempFile, position: mbData.position, tempo: mbData.tempo), nil)
                } else {
                    statusCallback(nil, .WriteToFileError)
                }
                
                func getId(forLane laneString: String) -> String? {
                    if laneString == "vocals" {
                        return "0"
                    } else if laneString == "other" {
                        return "1"
                    } else if laneString == "bass" {
                        return "2"
                    } else if laneString == "drums" {
                        return "3"
                    }
                    return nil
                }

                if let id = getId(forLane: mbData.lane) {
                    if let lanes = newLayout.lane[id] {
                        for (idx, region) in lanes.layout.enumerated() {
                            if region.id.uuidString == mbData.id {
                                newLayout.lane[id]!.layout[idx].item.bound = Region.Item.Bound(start: mbData.start, end: mbData.end)
                                break
                            }
                        }
                    }
                } else {
                    Logger.error("unknown string name \(mbData.lane) of lane")
                }

            } completion: {
                DispatchQueue.main.async {
                    self.isGenerating = false
                    onCompletion(newLayout, nil)
                }
            }
            
//            do {
////                let resp = try JSONSerialization.jsonObject(with: data) as! Dictionary<String, String>
//
//            } catch let e {
//                Log.error(e)
//                self.isGenerating = false
//                onCompletion(nil, err)
//            }
            
        }.resume()
    }
    
    func fetchMashup(uuid: String, tryNum: Int = 0, onCompletion: @escaping (Audio?, Error?) -> ()) {
        guard let taskId = self.generationTaskId else { return }
        
        let url = URL(string: Config.SERVER + HttpRequests.RESULT + "/" + taskId)!
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Application/json", forHTTPHeaderField: "Content-Type")
        
        
        URLSession.shared.dataTask(with: request) { data, response, err in
            guard let data = data, err == nil else {
                Logger.error(err)
                onCompletion(nil, err)
                return
            }
            
            do {
                let result = try JSONDecoder().decode(TaskResult.self, from: data)
                guard let audioData = Data(base64Encoded: result.task_result.snd) else {
                    onCompletion(nil, BackendError.DecodingError)
                    return
                }
                
                let tempFile = MashupFileManager.saveAudio(data: audioData, name: uuid, ext: "aac")
                
                if let tempFile = tempFile {
                    DispatchQueue.main.async {
                        self.generationTaskId = nil
                        
                        onCompletion(Audio(file: tempFile, position: 0, sampleRate: 44100), nil)
                    }
                } else {
                    onCompletion(nil, BackendError.WriteToFileError)
                }
            } catch let e {
                DispatchQueue.main.async {
                    if tryNum < 3 {
                        self.fetchMashup(uuid: uuid, tryNum: tryNum + 1, onCompletion: onCompletion)  //  Recursive call
                    } else {
                        Logger.error(e)
                        onCompletion(nil, e)
                    }
                }
            }
            
        }.resume()
        
    }
}
