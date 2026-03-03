import SwiftUI

struct EmojiRatingView: View {
    let label: String
    let emojis: [String]  // count must be 5, index 0 = worst
    @Binding var rating: Int

    var body: some View {
        HStack {
            Text(label)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 12) {
                ForEach(1...5, id: \.self) { i in
                    Text(emojis[i - 1])
                        .font(.title2)
                        .opacity(rating == i ? 1.0 : 0.35)
                        .onTapGesture { rating = i }
                }
            }
        }
        .padding(.vertical, 4)
    }
}
