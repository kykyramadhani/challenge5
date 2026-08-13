//
//  StatBadge.swift
//  GetCooking
//
//  Created by Owen Limantoro on 12/08/26.
//

import SwiftUI

struct StatBadge: View {
    let icon: String
    let value: String
    var tint: Color = .primary

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .monospacedDigit()
                .foregroundStyle(tint)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(.ultraThinMaterial, in: Capsule())
    }
}

#Preview {
    StatBadge(icon: "person.crop.circle", value: "100", tint: .red)
}
