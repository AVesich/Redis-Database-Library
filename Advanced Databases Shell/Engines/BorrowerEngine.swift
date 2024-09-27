//
//  BookEngine.swift
//  Advanced Databases Shell
//
//  Created by Austin Vesich on 9/24/24.
//

import Foundation

struct BorrowerEngine: Engine {
    
    // MARK: - Properties
    // Currently the min args are the max args so I don't need to review later after verifying intended behavior with sriram
    internal var commands: [String: Command] {[
        "add borrower" : Command(maxArgs: 3, handler: addBorrower),
        "rm borrower" : Command(maxArgs: 1, handler: removeBorrower),
        "edit borrower" : Command(maxArgs: 4, handler: editBorrower),
        "borrowed by" : Command(maxArgs: 1, handler: borrowedBy),
        "search borrowers" : Command(maxArgs: 2, handler: search)
    ]}

    // MARK: - Methods
    public func getResult(for command: String, with args: [String]) async -> String? {
        if !validateCommand(command) {
            return nil
        }
        // TODO: - todo
        return ""
    }
    
    private func addBorrower(with argCount: Int, and args: [String]) async -> String? { // Args are name, username, phone
        guard args.count == argCount else {
            return nil
        }
        
        let borrower = Borrower(args: args)
        let success = await RedisClient.shared.storeObject(withName: "borrower-\(args[1])", andData: borrower.pairs) // borrower-<username> is the key
        
        return success ? "Borrower added successfully!" : "Adding borrower failed! Make sure a borrower with this username doesn't already exist."
    }
    
    private func removeBorrower(with argCount: Int, and args: [String]) async -> String? { // Args are username
        return ""
    }

    private func editBorrower(with argCount: Int, and args: [String]) async -> String? { // Args are username, new name, new user, new phone
        return ""
    }
    
    private func borrowedBy(with argCount: Int, and args: [String]) async -> String? { // Args are username
        return ""
    }
    
    private func search(with argCount: Int, and args: [String]) async -> String? { // Args are search type, query
        return ""
    }
}
