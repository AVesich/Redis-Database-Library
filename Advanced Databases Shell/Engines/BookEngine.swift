//
//  BookEngine.swift
//  Advanced Databases Shell
//
//  Created by Austin Vesich on 9/24/24.
//

struct BookEngine: Engine {
    
    // MARK: - Properties
    // Currently the min args are the max args so I don't need to review later after verifying intended behavior with sriram
    internal let commands = [
        "add book" : 4,
        "rm book" : 1,
        "edit book" : 4,
        "search books" : 2,
        "list books" : 1,
        "checkout book" : 2,
        "borrower of" : 1
    ]

    // MARK: - Methods
    public func getResult(for command: String) -> String? {
        if !validateCommand(command) {
            return nil
        }
        // TODO: - todo
        return ""
    }
}
