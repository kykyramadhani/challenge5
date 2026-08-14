//
//  HeartCard.swift
//  GetCooking
//
//  Created by Owen Limantoro on 13/08/26.
//

import SwiftUI

struct HeartCard: View {
    var hearts : Int
    
    var body: some View {
        HStack {
            ForEach(1...hearts, id: \.self) {_ in
                Image(systemName: "heart.fill")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(.accent)
                
            }
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 22)
        .foregroundStyle(.black)
        .background(
            Capsule()
                .fill(Color("Primary"))
        )
    }
}

#Preview {
    HeartCard(hearts: 3)
}
