//
//  ObservableObject.swift
//  Mistralis
//
//  Created by Petros Dhespollari on 17/3/24.
//

import SwiftUI

class ReloadState: ObservableObject {
    @Published var shouldReload: Bool = false
}
