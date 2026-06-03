//
//  ZaineWatchApp.swift
//  ZaineWatch Watch App
//
//  Created by  梅垿麟 on 2026/5/21.
//

import SwiftUI

@main
struct ZaineWatchApp: App {
    @StateObject private var connectivityManager = WatchConnectivityManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(connectivityManager)
        }
    }
}
