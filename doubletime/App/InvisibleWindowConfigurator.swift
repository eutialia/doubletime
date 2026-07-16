//
//  InvisibleWindowConfigurator.swift
//  doubletime
//

import AppKit
import SwiftUI

struct InvisibleWindowConfigurator: NSViewRepresentable {
    @MainActor
    final class Coordinator {
        var configured = false
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView {
        NSView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard !context.coordinator.configured else { return }
        let coord = context.coordinator
        Task { @MainActor [weak nsView] in
            guard let window = nsView?.window, !coord.configured else { return }
            coord.configured = true
            window.alphaValue = 0
            window.ignoresMouseEvents = true
            window.collectionBehavior = [.stationary, .ignoresCycle]
        }
    }
}
