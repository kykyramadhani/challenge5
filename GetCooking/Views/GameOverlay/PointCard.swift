//
//  PointCard.swift
//  GetCooking
//
//  Created by Owen Limantoro on 13/08/26.
//

import SwiftUI

struct PointCard: View {
    var score: Int
    
    var body: some View {
        HStack {
            Image(systemName: "star.fill")
                .font(.system(size: 36, weight: .bold))

            Text("\(score) pts")
                .font(.system(size: 36, weight: .bold))
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 22)
        .foregroundStyle(.black)
        .background(
            Capsule()
                .fill(.appPrimary)
        )
    }
}

#Preview {
    PointCard(score: 10)
}
