//
//  ZaineWatch_Watch_AppApp.swift
//  ZaineWatch Watch App Watch App
//
//  在呢+ Watch App 入口
//

import SwiftUI

@main
struct ZaineWatch_Watch_App_Watch_AppApp: App {
    @StateObject private var connectivityManager = WatchConnectivityManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(connectivityManager)
        }
    }
}
