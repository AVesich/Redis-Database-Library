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
        "edit borrower" : Command(maxArgs: 3, handler: editBorrower),
        "borrowed by" : Command(maxArgs: 1, handler: borrowedBy),
        "search borrowers" : Command(maxArgs: 2, handler: search)
    ]}

    // MARK: - Methods
    public func getResult(for command: String, with args: [String]) async -> String? {
        if !validateCommand(command) {
            return nil
        }

        return await commands[command]?.handler(commands[command]!.maxArgs, args)
    }
    
    private func addBorrower(with argCount: Int, and args: [String]) async -> String? { // Args are name, username, phone
        guard args.count == argCount else {
            return nil
        }
        
        let borrower = Borrower(args: args)
        let success = await RedisClient.shared.storeObject(withKey: .borrowerKey(for: args[1]), andData: borrower.pairs) // borrower-<username> is the key
        
        return success ? "Borrower added successfully!" : "Adding borrower failed! Make sure a borrower with this username doesn't already exist."
    }
    
    private func removeBorrower(with argCount: Int, and args: [String]) async -> String? { // Args are username
        guard args.count == argCount else {
            return nil
        }
        
        let success = await RedisClient.shared.removeObject(withKey: .borrowerKey(for: args[0])) // book-<isbn> is the key
        
        return success ? "Borrower removed successfully!" : "Removing borrower failed!"
    }

    private func editBorrower(with argCount: Int, and args: [String]) async -> String? { // Args are username, new name, new phone
        guard args.count == argCount else {
            return nil
        }
        
        let userExists = await RedisClient.shared.objectExists(withKey: .borrowerKey(for: args[0]))
        // Only continue if we don't need a new username or if the new one isn't in use
        if !userExists {
            return "Borrower with username \(args[0]) does not exist."
        }
        
        let borrower = Borrower(args: [args[1], args[0], args[2]]) // Swap user and new name
        let success = await RedisClient.shared.storeObject(withKey: .borrowerKey(for: args[0]), andData: borrower.pairs, changeExisting: true) // We change the existing only if the user's match. We don't want to overwrite an existing book already using the new isbn
                        
        return success ? "Borrower edited successfully!" : "Editing borrower failed!"
    }
    
    private func borrowedBy(with argCount: Int, and args: [String]) async -> String? { // Args are username
        return ""
    }
    
    private func search(with argCount: Int, and args: [String]) async -> String? { // Args are search type, query
        return ""
    }
}
