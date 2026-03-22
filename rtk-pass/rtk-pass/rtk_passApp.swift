//
//  rtk_passApp.swift
//  rtk-pass
//
//  Created by aristarh on 21.03.2026.
//

import SwiftUI

@main
struct rtk_passApp: App {
    @StateObject private var screenCaptureMonitor = ScreenCaptureMonitor()

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                ScreenProtectionOverlay(isVisible: screenCaptureMonitor.isProtectionOverlayVisible)
            }
            .environmentObject(screenCaptureMonitor)
        }
    }
}
