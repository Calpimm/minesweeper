import SwiftUI

struct LeaderboardView: View {
    let online: OnlineService
    @State var level: Level

    private enum Phase {
        case loading
        case loaded(Leaderboard)
        case failed(String)
    }

    @State private var phase = Phase.loading
    @State private var reload = 0

    var body: some View {
        VStack(spacing: 0) {
            Picker("Level", selection: $level) {
                ForEach(Level.ranked, id: \.self) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(12)

            Divider()
            content.frame(maxWidth: .infinity, maxHeight: .infinity)
            Divider()

            HStack {
                footer
                Spacer()
                Button("Refresh") { reload += 1 }
                    .keyboardShortcut("r")
            }
            .padding(12)
        }
        .frame(width: 400, height: 480)
        .task(id: "\(level.rawValue)-\(reload)") { await load() }
    }

    @ViewBuilder private var content: some View {
        switch phase {
        case .loading:
            ProgressView()
        case .failed(let message):
            Text(message).foregroundStyle(.secondary).multilineTextAlignment(.center).padding()
        case .loaded(let board) where board.entries.isEmpty:
            Text("No times yet. Be the first!").foregroundStyle(.secondary)
        case .loaded(let board):
            List(board.entries) { entry in
                HStack {
                    Text("\(entry.rank).").monospacedDigit().foregroundStyle(.secondary).frame(width: 36, alignment: .trailing)
                    Text(entry.name).fontWeight(entry.name == online.account?.name ? .bold : .regular)
                    Spacer()
                    Text(formatTime(entry.timeMs)).monospacedDigit()
                }
            }
        }
    }

    @ViewBuilder private var footer: some View {
        if !online.isSignedIn {
            Text("Win a game to join the leaderboard.").foregroundStyle(.secondary)
        } else if case .loaded(let board) = phase, let me = board.me {
            Text("Your best: #\(me.rank) · \(formatTime(me.timeMs))")
        } else if let name = online.account?.name {
            Text("Playing as \(name)").foregroundStyle(.secondary)
        }
    }

    private func load() async {
        phase = .loading
        do {
            phase = .loaded(try await online.leaderboard(level))
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }
}
