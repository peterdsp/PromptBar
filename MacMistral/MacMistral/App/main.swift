//
//  main.swift
//  MacMistral
//
//  Created by Petros Dhespollari on 16/3/24.
//

import AppKit
import Foundation

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate

_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
