//
//  Utilities.swift
//  Mistralis
//
//  Created by Petros Dhespollari on 10/01/2025.
//

import Cocoa

extension NSImage {
    func resized(to size: CGSize) -> NSImage {
        let newImage = NSImage(size: size)
        newImage.lockFocus()
        draw(
            in: NSRect(origin: .zero, size: size), from: .zero,
            operation: .copy, fraction: 1.0)
        newImage.unlockFocus()
        return newImage
    }
}
