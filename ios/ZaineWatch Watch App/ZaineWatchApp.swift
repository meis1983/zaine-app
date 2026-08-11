//
//  ZaineWatchApp.swift
//  ZaineWatch Watch App
//

import SwiftUI

@main
struct ZaineWatch_Watch_AppApp: App {
    @StateObject private var watchManager = WatchConnectivityManager.shared
    
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                ContentView()
                    .environmentObject(watchManager)
                    .onAppear {
                        // Initialize WatchConnectivity on app launch
                        _ = WatchConnectivityManager.shared
                    }
            }
        }
    }
}
