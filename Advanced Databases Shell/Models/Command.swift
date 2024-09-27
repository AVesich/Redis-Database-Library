//
//  Command.swift
//  Task 1
//
//  Created by Austin Vesich on 9/27/24.
//

import Foundation

struct Command {
    let maxArgs: Int
    let handler: (Int, [String]) async -> String? // Command handlers take args and return a command result string
}
