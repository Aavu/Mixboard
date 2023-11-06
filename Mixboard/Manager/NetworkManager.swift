//
//  NetworkManager.swift
//  Mixboard
//
//  Created by Raghavasimhan Sankaranarayanan on 11/1/22.
//

import Foundation
import Combine

// Inspired from: https://www.youtube.com/watch?v=pp5-ASYnY0o
class NetworkManager {
    
    enum RequestType: String {
        case POST
        case GET
    }
    
    struct Header {
        let value: String
        let key: String
    }
    
    enum ContentType: String {
        case JSON = "Application/json"
        case FORM = "Application/x-www-form-urlencoded"
    }
    
    
    static func request<T:Decodable>(url: URL, type: RequestType, httpbody: Data? = nil, contentType: ContentType = .JSON, headers: [Header]? = nil, handleCompletion: ((Subscribers.Completion<Error>) -> ())? = nil, completion: @escaping (T?) -> ()) {
        var request = URLRequest(url: url)
        request.httpMethod = type.rawValue
        request.setValue(contentType.rawValue, forHTTPHeaderField: "Content-Type")
        
        if let headers = headers {
            for header in headers {
                request.addValue(header.value, forHTTPHeaderField: header.key)
            }
        }
        request.httpBody = httpbody
        
        var cancellable: AnyCancellable?
        cancellable = URLSession.shared.dataTaskPublisher(for: request)
            .subscribe(on: DispatchQueue.global(qos: .default))
            .tryMap({try handleURLResponse(output: $0)})
            .decode(type: T.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                if let handleCompletion = handleCompletion {
                    handleCompletion(completion)
                } else {
                    self.handleCompletion(completion: completion)
                }
            }, receiveValue: { (output) in
                completion(output)
                cancellable?.cancel()
            })
    }
    
    static func handleURLResponse(output: URLSession.DataTaskPublisher.Output) throws -> Data {
        guard let response = output.response as? HTTPURLResponse else {
            Logger.debug(output.response)
            throw URLError(.badServerResponse)
        }
        
        if response.statusCode == 401 {
            Logger.debug(output.response)
            throw URLError(.userAuthenticationRequired)
        }
        
        if response.statusCode < 200 || response.statusCode >= 300 {
            Logger.debug(output.response)
            throw URLError(.badServerResponse)
        }
        
        return output.data
    }
    
    static func handleCompletion(completion: Subscribers.Completion<Error>) {
        switch completion {
        case .finished:
            break
        case .failure(let e):
            Logger.error(e)
            Logger.debug(Thread.callStackSymbols)
        }
    }
    
    static func getAsHttpBody(body: Dictionary<String, String>) -> Data? {
        var dataString = ""
        for (k, v) in body {
            dataString.append(k)
            dataString.append("=")
            dataString.append(v)
            dataString.append("&")
        }
        
        dataString = String(dataString[..<dataString.index(dataString.startIndex, offsetBy: dataString.count - 1)])
        return dataString.data(using: String.Encoding.ascii, allowLossyConversion: true)
    }
    
}
