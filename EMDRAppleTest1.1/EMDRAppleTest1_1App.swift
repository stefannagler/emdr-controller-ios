//
//  EMDRAppleTest1_1App.swift
//  EMDRAppleTest1.1
//
//  Created by Stefan Nagler on 26/11/2024.
//

import SwiftUI

@main
struct EMDRAppleTest1_1App: App {
    // Initialize BluetoothManager at the app level
    @StateObject private var bluetoothManager: BluetoothManager = {
        let manager = BluetoothManager()
        // Any additional setup if needed
        return manager
    }()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(bluetoothManager) // Pass bluetoothManager to all views
        }
    }
}
