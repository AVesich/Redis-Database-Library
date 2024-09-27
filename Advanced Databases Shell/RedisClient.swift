//
//  RedisClient.swift
//  Advanced Databases Shell
//
//  Created by Austin Vesich on 9/26/24.
//

import Foundation
import SwiftRedis

struct RedisClient {
    // Singleton instance
    public static let shared = RedisClient()
    
    // MARK: - Properties
    private let redis = Redis()
    
    init() {
        redis.connect(host: "localhost", port: 6379) { error in
            if let error {
                fatalError(error.localizedDescription) // We NEED redis for the app to work
            }
        }
    }
    
    // MARK: - Methods
    public func ping() {
        redis.ping { err in
            if err == nil {
                print("PONG received, everything is working!\n")
            }
        }
    }
    
    public func storeObject(withName key: String, andData keyValues: [(String, String)], changeExisting: Bool = false) async -> Bool {
        let exists: Bool = await withCheckedContinuation { continuation in
            redis.hkeys(key) { fields, error in
                let hasFields = (fields?.count ?? 0) > 0
                continuation.resume(returning: hasFields) // Object exists if we have fields
            }
        }
        
        
        if exists && !changeExisting {
            return false
        }
        
        let success: Bool = await withCheckedContinuation { continuation in
            redis.hmsetArrayOfKeyValues(key, fieldValuePairs: keyValues) { success, error in
                if let error {
                    continuation.resume(returning: false)
                }
                continuation.resume(returning: success)
            }
        }
        
        return success
    }
}
