import SwiftUI
import AppKit
import UserNotifications

final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().delegate = self
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}

@main
struct SeifertSecurityReaderApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = NewsStore()

    var body: some Scene {
        WindowGroup("seifert-it Security Reader") {
            ContentView(store: store)
                .frame(minWidth: 1050, minHeight: 680)
                .preferredColorScheme(.light)
        }
        .windowStyle(.titleBar)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Feeds aktualisieren") { Task { await store.refresh() } }.keyboardShortcut("r", modifiers: .command)
            }
        }
    }
}
