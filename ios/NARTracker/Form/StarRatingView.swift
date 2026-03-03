import SwiftUI

struct StarRatingView: View {
    let label: String
    @Binding var rating: Int

    var body: some View {
        HStack {
            Text(label)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 6) {
                ForEach(1...5, id: \.self) { star in
                    Image(systemName: star <= rating ? "star.fill" : "star")
                        .foregroundStyle(star <= rating ? Color.yellow : Color.secondary)
                        .font(.title2)
                        .onTapGesture { rating = star }
                }
            }
        }
        .padding(.vertical, 4)
    }
}
