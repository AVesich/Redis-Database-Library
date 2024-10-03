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
    
    // MARK: - Objects
    public func objectExists(withKey key: String) async -> Bool {
        let exists: Bool = await withCheckedContinuation { continuation in
            redis.hkeys(key) { fields, error in
                let hasFields = (fields?.count ?? 0) > 0
                continuation.resume(returning: error != nil || hasFields) // Assume object exists if theres an error, and we know it exists if we have fields
            }
        }
        
        return exists
    }
    
    public func storeObject(withKey key: String, andData keyValues: [(String, String)], changeExisting: Bool = false) async -> Bool {
        let exists = await objectExists(withKey: key)
        
        if exists && !changeExisting {
            return false
        }
        
        let success: Bool = await withCheckedContinuation { continuation in
            redis.hmsetArrayOfKeyValues(key, fieldValuePairs: keyValues) { success, error in
                continuation.resume(returning: error == nil && success)
            }
        }
        
        return success
    }
    
    public func removeObject(withKey key: String) async -> Bool {
        let success: Bool = await withCheckedContinuation { continuation in
            redis.del(key) { success, error in
                continuation.resume(returning: error == nil) // Assume if there was no error, we were successful. We can double-check by validating the # of removed keys by checking if it existed beforehand, but I don't think it's worth doing edge case handling and verification like that for a simple app.
            }
        }
        
        return success
    }
    
    // MARK: - HashSets
    public func addToHashSet(_ pair: (String, String), withKey key: String, changeExisting: Bool = false) async -> Bool {
        // Check for subkey existing
        let exists: Bool = await withCheckedContinuation { continuation in
            redis.hget(key, field: pair.0) { response, error in
                continuation.resume(returning: error != nil || response != nil) // Error on the side of existence if there's an error, and if there's a response it exists
            }
        }
        
        if exists && !changeExisting {
            return false
        }
        
        let success = await storeObject(withKey: key, andData: [pair], changeExisting: true) // We are fine with changing the hash set, as we are adding an element to it
        
        return success
    }
    
    public func incrementInHashSet(_ subKey: String, withKey key: String, incrAmount: Int = 1) async -> Bool {
        // Check for subkey existing
        let success: Bool = await withCheckedContinuation { continuation in
            redis.hincr(key, field: subKey, by: 1) { response, error in
                continuation.resume(returning: error != nil)
            }
        }
                
        return success
    }

    public func decrementInHashSet(_ subKey: String, withKey key: String) async -> Bool {
        return await incrementInHashSet(subKey, withKey: key, incrAmount: -1)
    }
    
    public func getFromHashSet(withKey key: String, andSubKey subKey: String) async -> String? {
        let result: String? = await withCheckedContinuation { continuation in
            redis.hget(key, field: subKey) { response, error in
                if error != nil {
                    continuation.resume(returning: nil)
                }
                continuation.resume(returning: response?.asString)
            }
        }
        
        return result
    }
    
    public func getAllKeysFromHashSet(withKey key: String) async -> [String] {
        let result: [String] = await withCheckedContinuation { continuation in
            redis.hkeys(key) { responseStrings, _ in
                let values = responseStrings ?? [String]()
                return continuation.resume(returning: values)
            }
        }
        
        return result
    }
    
    public func getAllValuesFromHashSet(withKey key: String) async -> [String] {
        let result: [String] = await withCheckedContinuation { continuation in
            redis.hvals(key) { responseStrings, _ in
                let values = responseStrings?.compactMap { $0?.asString } ?? [String]()
                return continuation.resume(returning: values)
            }
        }
        
        return result
    }
    
    public func removeFromHashSet(withKey key: String, andSubKey subKey: String) async -> Bool {
        let success: Bool = await withCheckedContinuation { continuation in
            redis.hdel(key, fields: subKey) { numRemoved, error in
                continuation.resume(returning: error == nil && numRemoved != nil)
            }
        }
        
        return success
    }
    
    // MARK: - Arrays
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
    
    public func getValuesFromArray(withKey key: String) async -> [String] {
        let values: [String] = await withCheckedContinuation { continuation in
            redis.lrange(key, start: 0, end: -1) { responseStrings, _ in
                let values = responseStrings?.compactMap { $0?.asString } ?? [String]()
                return continuation.resume(returning: values)
            }
        }
        
        return values
    }
    
    // MARK: - ZSets
    public func addToZSet(_ value: String, withScore score: Int = 1, atKey key: String) async -> Bool {
        let success: Bool = await withCheckedContinuation { continuation in
            redis.zadd(key, tuples: (score, value)) { _, error in
                continuation.resume(returning: error == nil)
            }
        }
        
        return success
    }
    
    public func removeFromZSet(_ value: String, withKey key: String) async -> Bool {
        let success: Bool = await withCheckedContinuation { continuation in
            redis.zrem(key, members: value) { _, error in
                continuation.resume(returning: error == nil)
            }
        }
        
        return success
    }
    
    public func removeFromZSet(withKey key: String, usingScore score: Int) async -> Bool {
        let success: Bool = await withCheckedContinuation { continuation in
            redis.zremrangebyscore(key, min: String(score), max: String(score)) { _, error in
                continuation.resume(returning: error == nil)
            }
        }
        
        return success
    }

    
    public func getSortedZSetValues(atKey key: String) async -> [String] {
        let values: [String] = await withCheckedContinuation { continuation in
            redis.zrangebylex(key, min: "-", max: "+") { responseStrings, _ in
                let values = responseStrings?.compactMap { $0?.asString } ?? [String]()
                return continuation.resume(returning: values)
            }
        }
        
        return values
    }
    
    // MARK: - Sets
    public func addToSet(_ value: String, atKey key: String) async -> Bool {
        let success: Bool = await withCheckedContinuation { continuation in
            redis.sadd(key, members: value) { _, error in
                continuation.resume(returning: error == nil)
            }
        }
        
        return success
    }
    
    public func getValuesFromSet(withKey key: String) async -> [String] {
        let values: [String] = await withCheckedContinuation { continuation in
            redis.smembers(key) { responseStrings, _ in
                let values = responseStrings?.compactMap { $0?.asString } ?? [String]()
                return continuation.resume(returning: values)
            }
        }
        
        return values
    }
    
    public func getSetSize(withKey key: String) async -> Int {
        let size: Int = await withCheckedContinuation { continuation in
            redis.scard(key) { count, _ in
                continuation.resume(returning: count ?? 0)
            }
        }
        
        return size
    }
    
    public func removeFromSet(_ value: String, atKey key: String) async -> Bool {
        let success: Bool = await withCheckedContinuation { continuation in
            redis.srem(key, members: value) { _, error in
                continuation.resume(returning: error == nil)
            }
        }

        return success
    }
}
