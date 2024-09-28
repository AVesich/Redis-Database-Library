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
    
    public func objectExists(withKey key: String) async -> Bool {
        let exists: Bool = await withCheckedContinuation { continuation in
            redis.hkeys(key) { fields, error in
                if let error {
                    continuation.resume(returning: true) // Assume it does exist in the case of a failure. This will error on the side of caution when adding a new item.
                }
                let hasFields = (fields?.count ?? 0) > 0
                continuation.resume(returning: hasFields) // Object exists if we have fields
            }
        }

        return exists
    }
    
    public func removeObject(withKey key: String) async -> Bool {
        let success: Bool = await withCheckedContinuation { continuation in
            redis.del(key) { success, error in
                continuation.resume(returning: error == nil) // Assume if there was no error, we were successful. We can double-check by validating the # of removed keys by checking if it existed beforehand, but I don't think it's worth doing edge case handling and verification like that for a simple app.
            }
        }
        
        return success
    }
    
    public func storeObject(withKey key: String, andData keyValues: [(String, String)], changeExisting: Bool = false) async -> Bool {
        let exists: Bool = await withCheckedContinuation { continuation in
            redis.hkeys(key) { fields, error in
                if let error {
                    continuation.resume(returning: true) // Assume it does exist in the case of a failure. This will error on the side of caution when adding a new item.
                }
                let hasFields = (fields?.count ?? 0) > 0
                continuation.resume(returning: hasFields) // Object exists if we have fields
            }
        }
        
        
        if exists && !changeExisting {
            return false
        }
        
        let success: Bool = await withCheckedContinuation { continuation in
            redis.hmsetArrayOfKeyValues(key, fieldValuePairs: keyValues) { success, error in
                if error != nil {
                    continuation.resume(returning: false)
                }
                continuation.resume(returning: success)
            }
        }
        
        return success
    }
    
    public func addToArray(_ value: String, withKey key: String) async -> Bool {
        let success: Bool = await withCheckedContinuation { continuation in
            redis.rpush(key, values: value) { afterLength, error in
                if error != nil {
                    continuation.resume(returning: false) // Error
                }
                continuation.resume(returning: true) // Assume success if no error
            }
        }
        
        return success
    }
    
//    public func getObjectsFromHSet(withKeyPredicate predicate: String, andField field: String) async -> [String] {
//        let results: [String] = await withCheckedContinuation { continuation in
//            redis.sort(key: , get: field) { responseStrings, error in
//                if let error {
//                    continuation.resume(returning: [String]())
//                }
//                continuation.resume(returning: responseStrings?.compactMap{ $0?.asString } ?? [String]())
//            }
//        }
//        
//        return results
//    }
}
