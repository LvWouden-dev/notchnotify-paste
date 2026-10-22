//
//  NotchNotify Paste: the optional helper for NotchNotify.
//
//  Lives in the menu bar. When NotchNotify has put dictated text on the clipboard it posts a
//  payload-free notification; this app then presses ⌘V in the frontmost app. It reads nothing
//  from the clipboard and has no network access. It needs Accessibility access to press the key,
//  which is why it is a separate, non-sandboxed app that the user installs on their own.
//
//  Not built or tested yet: see README.md.
//

import AppKit
import ApplicationServices
import Carbon.HIToolbox
import ServiceManagement

private let pasteRequest = Notification.Name("com.notchnotify.paste.request")

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private let accessItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let loginItem = NSMenuItem(title: "Open at Login", action: #selector(toggleLogin), keyEquivalent: "")

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "text.cursor", accessibilityDescription: "NotchNotify Paste")
        let menu = NSMenu()
        menu.delegate = self
        accessItem.isEnabled = false
        menu.addItem(accessItem)
        let grant = NSMenuItem(title: "Grant Accessibility Access…", action: #selector(grantAccess), keyEquivalent: "")
        grant.target = self
        menu.addItem(grant)
        menu.addItem(.separator())
        loginItem.target = self
        menu.addItem(loginItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit NotchNotify Paste", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        item.menu = menu
        statusItem = item

        DistributedNotificationCenter.default().addObserver(
            self, selector: #selector(pasteRequested),
            name: pasteRequest, object: nil,
            suspensionBehavior: .deliverImmediately)

        // Ask once at first launch so pasting works right away.
        if !AXIsProcessTrusted() { grantAccess() }
    }

    @objc private func grantAccess() {
        // The string value of kAXTrustedCheckOptionPrompt (the constant itself trips Swift 6's checks).
        _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
    }

    @objc private func toggleLogin() {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled { try service.unregister() } else { try service.register() }
        } catch {
            NSSound.beep()
        }
    }

    @objc private func pasteRequested() {
        guard AXIsProcessTrusted() else { return }
        Task { await Self.pressPaste() }
    }

    /// Waits (max 1 s) until the dictation shortcut's modifier keys are released, then presses ⌘V.
    private static func pressPaste() async {
        let modifiers: NSEvent.ModifierFlags = [.control, .option, .shift, .command]
        var waited = 0
        while !NSEvent.modifierFlags.intersection(modifiers).isEmpty && waited < 33 {
            try? await Task.sleep(for: .milliseconds(30))
            waited += 1
        }
        let source = CGEventSource(stateID: .combinedSessionState)
        let down = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }
}

extension AppDelegate: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        accessItem.title = AXIsProcessTrusted()
            ? "Ready: pastes dictation from NotchNotify"
            : "Needs Accessibility access to paste"
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }
}

// Top-level code is not main-actor isolated in Swift 5 mode, but it does run on the main thread.
MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()   // stays alive: run() below never returns
    app.delegate = delegate
    app.run()
}
