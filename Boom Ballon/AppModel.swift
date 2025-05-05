//
//  AppModel.swift
//  Boom Ballon
//
//  Created by Vision Tartanga on 31/3/25.
//

import SwiftUI

/// Maintains app-wide state
@MainActor
@Observable

class AppModel {
    let immersiveSpaceID = "ImmersiveSpace"
    enum ImmersiveSpaceState {
        case closed
        case inTransition
        case open
    }
    var immersiveSpaceState = ImmersiveSpaceState.closed
}
