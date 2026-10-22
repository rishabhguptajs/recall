import SwiftUI

final class SearchModel: ObservableObject {
    @Published var query = ""
    /// Bumped each time the panel opens so the field grabs focus.
    @Published var focusToken = 0
}

struct SearchView: View {
    @ObservedObject var model: SearchModel
    var onClose: () -> Void
    @FocusState private var fieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.secondary)
                TextField("Search your Mac…", text: $model.query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 24))
                    .focused($fieldFocused)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            Divider()
            Spacer()
            Text("Type to search files, screenshots and clipboard")
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(width: 680, height: 420)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .onChange(of: model.focusToken) { fieldFocused = true }
        .onAppear { fieldFocused = true }
    }
}
