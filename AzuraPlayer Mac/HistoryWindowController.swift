//
//  HistoryWindowController.swift
//  AzuraPlayer Mac
//

import AppKit
import SwiftUI

@MainActor
class HistoryWindowController: NSWindowController {
    private static var instance: HistoryWindowController?

    static func show() {
        if instance == nil {
            let win = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 860, height: 580),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            let lang = UserDefaults.standard.string(forKey: "appLanguage") ?? "en"
            win.title = tr("History", "Verlauf", lang)
            win.isReleasedWhenClosed = false

            let hostingView = NSHostingView(rootView: HistoryView())
            win.contentView = hostingView
            win.center()

            instance = HistoryWindowController(window: win)

            NotificationCenter.default.addObserver(
                forName: NSWindow.willCloseNotification,
                object: win,
                queue: .main
            ) { _ in
                Task { @MainActor in
                    HistoryWindowController.instance = nil
                }
            }
        }

        instance?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
