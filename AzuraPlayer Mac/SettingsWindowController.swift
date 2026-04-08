//
//  SettingsWindowController.swift
//  AzuraPlayer Mac
//

import AppKit
import SwiftUI

@MainActor
class SettingsWindowController: NSWindowController {
    private static var instance: SettingsWindowController?

    static func show() {
        if instance == nil {
            let hosting = NSHostingController(
                rootView: SettingsView()
                    .environmentObject(StationStore.shared)
            )
            let win = NSWindow(contentViewController: hosting)
            win.title = "Einstellungen"
            win.styleMask = [.titled, .closable, .miniaturizable]
            win.setContentSize(NSSize(width: 480, height: 360))
            win.center()
            instance = SettingsWindowController(window: win)

            NotificationCenter.default.addObserver(
                forName: NSWindow.willCloseNotification,
                object: win,
                queue: .main
            ) { _ in
                Task { @MainActor in
                    SettingsWindowController.instance = nil
                }
            }
        }

        instance?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
