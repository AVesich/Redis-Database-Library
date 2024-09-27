//
//  Engine.swift
//  Advanced Databases Shell
//
//  Created by Austin Vesich on 9/24/24.
//

protocol Engine {
    var commands: [String : Command] { get } // Command : min(# args)
    
    func getResult(for command: String, with args: [String]) async -> String?
}

extension Engine {
    func validateCommand(_ command: String) -> Bool {
        return commands.keys.contains(command)
    }
}
