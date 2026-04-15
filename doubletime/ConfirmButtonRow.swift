//
//  ConfirmButtonRow.swift
//  doubletime
//

import SwiftUI

struct ConfirmButtonRow: View {
    let applyAction: () -> Void
    let cancelAction: () -> Void
    let isApplyEnabled: Bool

    var body: some View {
        HStack {
            Spacer()
            Button("Cancel", action: cancelAction)
                .keyboardShortcut(.cancelAction)
            Button("Apply", action: applyAction)
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(!isApplyEnabled)
        }
    }
}
