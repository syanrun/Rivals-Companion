// ContentView.swift
// Rivals Companion
//
// Created by Ryan Sun on 4/23/25.
//

import Foundation
import SwiftUI
import SwiftData

struct FindResponse: Decodable {
    let uid: String?
    let error: Bool?
    let message: String?
}

struct PlayerResponse: Decodable {
    let message: String?
    let data: PlayerData?
}

struct PlayerData: Decodable {
    let is_profile_private: Bool
    let heroes: HeroData
}

struct HeroData: Decodable {
    let ranked: [String: PlayerHero]
}

struct PlayerHero: Decodable {
    let matches: Int
    let win: Int
    let kills: Int
    let deaths: Int
    let assists: Int
}

struct HeroStat: Identifiable, Decodable {
    let id: String
    let name: String
    var gamesPlayed: Int = 0
    var wins: Int = 0
    var kills: Int = 0
    var deaths: Int = 0
    var assists: Int = 0

    var winRate: Double {
        if gamesPlayed == 0 {
            return 0.0
        }
        return (Double(wins) / Double(gamesPlayed)) * 100.0
    }

    var kda: Double {
        if deaths == 0 {
            return Double(kills + assists)
        }
        return Double(kills + assists) / Double(deaths)
    }
}

// MARK: - Navigation

enum NavigationTarget: Hashable {
    case search(username: String)
    case saved
}

// MARK: - Main Content View

struct ContentView: View {
    @State private var username: String = ""

    var body: some View {
        NavigationStack {
            VStack {
                Spacer()
                Text("Rivals Companion").font(.largeTitle)
                    .foregroundColor(Color.black)
                Spacer()
                Image("icon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 250, height: 250)
                Spacer()
                TextField("",
                          text: $username,
                          prompt: Text("Enter In-Game Name").foregroundColor(Color.gray))
                .foregroundColor(Color.black)
                .autocapitalization(.none)
                .autocorrectionDisabled(true)
                .multilineTextAlignment(.center)
                .padding()
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.2)))
                .padding(.horizontal)

                HStack(spacing: 20) {
                    NavigationLink(value: NavigationTarget.search(username: username)) {
                        Text("Search")
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(RoundedRectangle(cornerRadius:10).fill(username.isEmpty ? Color.gray : Color.blue))
                            .foregroundColor(.white)
                    }
                    .disabled(username.isEmpty)

                    NavigationLink(value: NavigationTarget.saved) {
                        Text("Saved")
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(RoundedRectangle(cornerRadius:10).fill(Color.green))
                            .foregroundColor(.white)
                    }
                }
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.white)
            .navigationDestination(for: NavigationTarget.self) { target in
                switch target {
                case .search(let username):
                    SearchView(searchQuery: username)
                case .saved:
                    SavedView()
                }
            }
        }
    }
}

struct SearchView: View {
    let searchQuery: String
    @State private var heroStats: [HeroStat] = []
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var isSaved = false

    @Environment(\.modelContext) private var modelContext
    @Query private var savedPlayers: [Saved]
    var body: some View {
        VStack(spacing: 15) {
            Text(searchQuery)
                .font(.largeTitle)
                .foregroundColor(.black)
                .padding(.top)

            if isLoading {
                ProgressView("Loading Stats...")
                    .foregroundStyle(.black)
                Spacer()
            } else if let errorMessage = errorMessage {
                Text("Error: \(errorMessage)")
                    .foregroundColor(.red)
                Spacer()
            } else if heroStats.isEmpty {
                Text("No match data found or player profile is private.")
                    .foregroundStyle(.black)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                Spacer()
            } else {
                List {
                    ForEach(heroStats) { hero in
                        HeroStatView(hero: hero)
                            .listRowBackground(Color.white)
                            .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)

                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !isLoading && errorMessage == nil && !heroStats.isEmpty {
                Button {
                    savePlayer()
                } label: {
                    Label(isSaved ? "Saved" : "Save", systemImage: isSaved ? "heart.fill" : "heart")
                }
                .disabled(isSaved)
            }
        }
        .onAppear {
            isSaved = savedPlayers.contains(where: { $0.name.caseInsensitiveCompare(searchQuery) == .orderedSame })
            fetchStats()
        }
        .onChange(of: searchQuery) { oldValue, newValue in
             isSaved = savedPlayers.contains(where: { $0.name.caseInsensitiveCompare(newValue) == .orderedSame })
             fetchStats()
        }
    }

    private func savePlayer() {
        guard !isSaved else { return }

        let newSavedPlayer = Saved(name: searchQuery)
        modelContext.insert(newSavedPlayer)
        isSaved = true
    }


    func fetchStats() {
        isLoading = true
        errorMessage = nil
        heroStats = []

        let apiKey = APIKeys.MRAPI_KEY

        let findPlayerURL = "https://marvelrivalsapi.com/api/v1/find-player/\(searchQuery)"

        guard let url = URL(string: findPlayerURL.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "") else {
            isLoading = false
            errorMessage = "Invalid search query"
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(apiKey, forHTTPHeaderField: "x-api-key")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    isLoading = false
                    errorMessage = "Network error: \(error.localizedDescription)"
                }
                return
            }

            guard let data = data else {
                DispatchQueue.main.async {
                    isLoading = false
                    errorMessage = "No data received"
                }
                return
            }

            do {
                let findResponse = try JSONDecoder().decode(FindResponse.self, from: data)

                if let error = findResponse.error, error == true {
                    DispatchQueue.main.async {
                        isLoading = false
                        errorMessage = findResponse.message ?? "Could not Locate Player ID"
                    }
                    return
                }

                guard let playerUID = findResponse.uid else {
                    DispatchQueue.main.async {
                        isLoading = false
                        errorMessage = "Player not found"
                    }
                    return
                }

                fetchPlayerStats(playerUID: playerUID)

            } catch {
                DispatchQueue.main.async {
                    isLoading = false
                    errorMessage = "Failed to parse data: \(error.localizedDescription)"
                }
            }
        }.resume()
    }

    func fetchPlayerStats(playerUID: String) {
        let playerStatsURL = "https://API.Lunarify.app/api/v1/player/\(playerUID)"

        let apiKey = APIKeys.LUNARAPI_KEY

        guard let url = URL(string: playerStatsURL) else {
            DispatchQueue.main.async {
                isLoading = false
                errorMessage = "Invalid player ID URL"
            }
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue(apiKey, forHTTPHeaderField: "x-api-key")

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false

                if let error = error {
                    errorMessage = "Network error fetching stats: \(error.localizedDescription)"
                    return
                }

                guard let data = data else {
                    errorMessage = "No player data received"
                    return
                }

                do {
                    let playerResponse = try JSONDecoder().decode(PlayerResponse.self, from: data)

                    guard let playerData = playerResponse.data else {
                         errorMessage = playerResponse.message ?? "Failed to retrieve player data"
                         return
                     }


                    if playerData.heroes.ranked.count == 0 {
                         errorMessage = "No Ranked Match Data Found (Profile might be private)"
                         return
                    }

                    var stats: [HeroStat] = []

                    let heroNames: [String: String] = [
                         "1011" : "Bruce Banner",
                         "1014" : "The Punisher",
                         "1015" : "Storm",
                         "1016" : "Loki",
                         "1017" : "Human Torch",
                         "1018" : "Doctor Strange",
                         "1020" : "Mantis",
                         "1021" : "Hawkeye",
                         "1022" : "Captain America",
                         "1023" : "Rocket Raccoon",
                         "1024" : "Hela",
                         "1025" : "Cloak & Dagger",
                         "1026" : "Black Panther",
                         "1027" : "Groot",
                         "1029" : "Magik",
                         "1030" : "Moon Knight",
                         "1031" : "Luna Snow",
                         "1032" : "Squirrel Girl",
                         "1033" : "Black Widow",
                         "1034" : "Iron Man",
                         "1035" : "Venom",
                         "1036" : "Spider-Man",
                         "1037" : "Magneto",
                         "1038" : "Scarlet Witch",
                         "1039" : "Thor",
                         "1040" : "Mister Fantastic",
                         "1041" : "Winter Soldier",
                         "1042" : "Peni Parker",
                         "1043" : "Star-Lord",
                         "1045" : "Namor",
                         "1046" : "Adam Warlock",
                         "1047" : "Jeff The Land Shark",
                         "1048" : "Psylocke",
                         "1049" : "Wolverine",
                         "1050" : "Invisible Woman",
                         "1051" : "The Thing",
                         "1052" : "Iron Fist",
                         "1053" : "Emma Frost"
                    ]

                    for (heroIdString, heroData) in playerData.heroes.ranked {
                        if heroData.matches > 0 {
                            let heroName = heroNames[heroIdString] ?? "Unknown Hero (\(heroIdString))"
                            let heroStat = HeroStat(id: heroIdString, name: heroName, gamesPlayed: heroData.matches, wins: heroData.win, kills: heroData.kills, deaths: heroData.deaths, assists: heroData.assists)
                            stats.append(heroStat)
                        }
                    }

                    self.heroStats = stats.sorted { $0.gamesPlayed > $1.gamesPlayed }

                } catch {
                    errorMessage = "Failed to parse player data: \(error.localizedDescription)"
                }
            }
        }.resume()
    }
}

struct HeroStatView: View {
    let hero: HeroStat

    var body: some View {
        HStack {
            VStack(alignment: .center, spacing: 5) {
                Image(hero.name)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .padding(.bottom, 5)
                Text(hero.name.capitalized)
                    .foregroundStyle(.black)
                    .font(.headline)
                Text("\(hero.gamesPlayed) games")
                    .foregroundStyle(.black)
                    .font(.subheadline)
                Text(String(format: "%.1f%% WR", hero.winRate))
                    .font(.subheadline)
                    .foregroundColor(hero.winRate >= 50 ? .green : .red)
                Text(String(format: "%.2f KDA", hero.kda))
                    .foregroundStyle(.black)
                    .font(.subheadline)
            }
            .padding()
            .frame(maxWidth: .infinity)
        }
    }
}

struct SavedView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss
    @Query(sort: \Saved.name) private var savedPlayers: [Saved]

    var body: some View {
        VStack {
            Text("Saved Players")
                .foregroundColor(.black)
                .font(.title)
                .padding(.top)

            if savedPlayers.isEmpty {
                Spacer()
                Text("No saved players yet.")
                    .foregroundColor(.gray)
                Spacer()
            } else {
                List {
                    ForEach(savedPlayers) { player in
                         NavigationLink(value: NavigationTarget.search(username: player.name)) {
                            Text(player.name)
                                .foregroundColor(.black)
                         }
                         .listRowBackground(Color.white)
                         .listRowSeparator(.hidden)
                        
                    }
                    .onDelete(perform: deletePlayers)
                }
                .listStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
        .navigationTitle("Saved")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func deletePlayers(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                let player = savedPlayers[index]
                modelContext.delete(player)
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Saved.self, inMemory: true)
}
