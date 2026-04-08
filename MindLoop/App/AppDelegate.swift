//
//  AppDelegate.swift
//  MindLoop
//
//  Minimal UIApplicationDelegate to receive background URLSession events.
//  iOS wakes the app and calls `handleEventsForBackgroundURLSession` when a
//  background download session has completion events to deliver. We hand the
//  completion handler to `ModelDownloader`, which invokes it from
//  `urlSessionDidFinishEvents(forBackgroundURLSession:)` so iOS can suspend
//  us again cleanly.
//

import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {

    /// Called by iOS when a background URLSession has finished all pending
    /// events. We stash the completion handler on the shared `ModelDownloader`
    /// instance so it can be invoked after the delegate processes events.
    func application(
        _ application: UIApplication,
        handleEventsForBackgroundURLSession identifier: String,
        completionHandler: @escaping () -> Void
    ) {
        guard identifier == ModelDownloader.sessionIdentifier else {
            // Unknown session identifier — call completion immediately so iOS
            // doesn't think we're misbehaving.
            completionHandler()
            return
        }

        // `ModelDownloader.shared` is @MainActor-isolated; hop to it.
        Task { @MainActor in
            ModelDownloader.shared.backgroundCompletionHandler = completionHandler
        }
    }
}
