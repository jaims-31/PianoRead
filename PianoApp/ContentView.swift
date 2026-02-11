import SwiftUI
import AVFoundation
import FirebaseAuth
import GoogleSignIn
import FacebookLogin
import Combine
import UniformTypeIdentifiers
import PDFKit

// --- 1. GESTIONNAIRE JEU DE NOTES ---
enum Difficulty {
    case facile, moyen, difficile
}

enum ClefType {
    case sol, fa
}

class NoteGameManager: ObservableObject {
    @Published var currentNote: String = ""
    @Published var noteOffset: CGFloat = 0
    @Published var score: Int = 0
    @Published var feedbackEmoji: String = " "
    @Published var currentClef: ClefType = .sol
    
    private var remainingNotes: [String] = []
    var currentDifficulty: Difficulty = .facile
    
    let solNotesPositions: [String: CGFloat] = [
        "DO_G2": 94.25, "RÉ_G2": 87.0, "MI_G": 79.75, "FA_G": 72.5, "SOL_G": 65.25, "LA_G": 58.0, "SI_G": 50.75,
        "DO": 43.5, "RÉ": 36.25, "MI": 29.0, "FA": 21.75, "SOL": 14.5, "LA": 7.25, "SI": 0,
        "DO_A": -7.25, "RÉ_A": -14.5, "MI_A": -21.75, "FA_A": -29.0, "SOL_A": -36.25, "LA_A": -43.5, "SI_A": -50.75,
        "DO_A2": -58.0, "RÉ_A2": -65.25, "MI_A2": -72.5, "FA_A2": -79.75, "SOL_A2": -87.0
    ]
    
    let faNotesPositions: [String: CGFloat] = [
        "DO_G3": 108.75, "RÉ_G3": 101.5, "MI_G2": 94.25, "FA_G2": 87.0, "SOL_G2": 79.75, "LA_G2": 72.5, "SI_G2": 65.25,
        "DO_G2": 58.0, "RÉ_G2": 50.75, "MI_G": 43.5, "FA_G": 36.25, "SOL_G": 29.0, "LA_G": 21.75, "SI_G": 14.5,
        "DO": 7.25, "RÉ": 0, "MI": -7.25, "FA": -14.5, "SOL": -21.75, "LA": -29.0, "SI": -36.25,
        "DO_A": -43.5, "RÉ_A": -50.75, "MI_A": -58.0, "FA_A": -65.25, "SOL_A": -72.5, "LA_A": -79.75, "SI_A": -87.0
    ]
    
    var levelNotes: [String] {
        let pool = currentClef == .sol ? Array(solNotesPositions.keys) : Array(faNotesPositions.keys)
        switch currentDifficulty {
        case .facile:
            return currentClef == .sol ? ["DO", "RÉ", "MI", "FA", "SOL", "LA", "SI", "DO_A"] : ["SOL_G", "LA_G", "SI_G", "DO", "RÉ", "MI", "FA", "SOL"]
        case .moyen:
            return pool.filter { !($0.contains("2") || $0.contains("3")) }
        case .difficile:
            return pool
        }
    }
    
    let noteNames = ["DO", "RÉ", "MI", "FA", "SOL", "LA", "SI"]
    
    func startGame(difficulty: Difficulty, clef: ClefType) {
        self.currentDifficulty = difficulty
        self.currentClef = clef
        self.score = 0
        self.remainingNotes = []
        generateNewNote()
    }
    
    func generateNewNote() {
        if remainingNotes.isEmpty { remainingNotes = levelNotes.shuffled() }
        currentNote = remainingNotes.removeLast()
        noteOffset = currentClef == .sol ? solNotesPositions[currentNote]! : faNotesPositions[currentNote]!
        feedbackEmoji = " "
    }
    
    func checkAnswer(_ answer: String) {
        let correctBaseNote = currentNote.components(separatedBy: "_")[0]
        if answer == correctBaseNote {
            score += 1
            feedbackEmoji = "✅"
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { self.generateNewNote() }
        } else {
            feedbackEmoji = "❌"
        }
    }
}

// --- 2. COMPOSANT LECTEUR PDF ---
struct PDFKitView: UIViewRepresentable {
    let url: URL
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = PDFDocument(url: url)
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        return pdfView
    }
    func updateUIView(_ uiView: PDFView, context: Context) {}
}

// --- 3. VUE PRINCIPALE ---
struct ContentView: View {
    @AppStorage("isLoggedIn") private var isLoggedIn = false
    @AppStorage("userEmail") private var userEmail = ""
    @State private var selectedTab = 0
    @StateObject var gameManager = NoteGameManager()
    
    var body: some View {
        if !isLoggedIn {
            LoginView(isLoggedIn: $isLoggedIn, userEmail: $userEmail)
        } else {
            TabView(selection: $selectedTab) {
                NavigationStack {
                    HomeView(game: gameManager)
                        .navigationTitle("") // Titre supprimé ici
                        .toolbar { logoutButton }
                }
                .tabItem { Label("Accueil", systemImage: "house.fill") }.tag(0)
                
                NavigationStack {
                    ImportDocumentsView()
                        .navigationTitle("Ma Bibliothèque")
                }
                .tabItem { Label("Documents", systemImage: "doc.badge.plus") }.tag(1)
            }
            .accentColor(.green)
            .environmentObject(gameManager)
            .preferredColorScheme(.dark)
        }
    }
    
    var logoutButton: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button("Déconnexion") { try? Auth.auth().signOut(); isLoggedIn = false }
                .font(.caption).foregroundColor(.red)
        }
    }
}

// --- 4. VUE BIBLIOTHÈQUE ---
struct ImportDocumentsView: View {
    @State private var savedFiles: [URL] = []
    @State private var showFileImporter = false
    @State private var selectedPDF: URL?

    var body: some View {
        VStack {
            if savedFiles.isEmpty {
                VStack(spacing: 30) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 80)).foregroundColor(.green).padding(.top, 50)
                    Text("Votre bibliothèque est vide.")
                        .foregroundColor(.secondary)
                    Button(action: { showFileImporter = true }) {
                        Text("Ajouter une partition (PDF)")
                            .font(.headline).padding().frame(maxWidth: .infinity)
                            .background(Color.green).foregroundColor(.black).cornerRadius(15)
                    }.padding(.horizontal, 40)
                    Spacer()
                }
            } else {
                List {
                    ForEach(savedFiles, id: \.self) { url in
                        HStack {
                            Image(systemName: "doc.fill").foregroundColor(.green)
                            Text(url.lastPathComponent).lineLimit(1)
                            Spacer()
                            Button(action: { selectedPDF = url }) {
                                Image(systemName: "eye.fill").foregroundColor(.blue)
                            }.buttonStyle(BorderlessButtonStyle())
                        }
                    }
                    .onDelete(perform: deleteFiles)
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showFileImporter = true }) {
                    Image(systemName: "plus.circle.fill").font(.title3).foregroundColor(.green)
                }
            }
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                for url in urls { saveFileToApp(from: url) }
            case .failure(let error):
                print("Erreur : \(error.localizedDescription)")
            }
        }
        .sheet(item: $selectedPDF) { url in
            NavigationStack {
                PDFKitView(url: url)
                    .navigationTitle(url.lastPathComponent)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Fermer") { selectedPDF = nil }
                        }
                    }
            }
        }
        .onAppear { loadSavedFiles() }
    }

    func loadSavedFiles() {
        let fileManager = FileManager.default
        guard let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        do {
            let content = try fileManager.contentsOfDirectory(at: docs, includingPropertiesForKeys: nil)
            savedFiles = content.filter { $0.pathExtension.lowercased() == "pdf" }
        } catch {
            print("Erreur lecture: \(error)")
        }
    }

    func saveFileToApp(from sourceURL: URL) {
        let fileManager = FileManager.default
        guard let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let destinationURL = docs.appendingPathComponent(sourceURL.lastPathComponent)
        
        if sourceURL.startAccessingSecurityScopedResource() {
            defer { sourceURL.stopAccessingSecurityScopedResource() }
            do {
                if fileManager.fileExists(atPath: destinationURL.path) {
                    try fileManager.removeItem(at: destinationURL)
                }
                try fileManager.copyItem(at: sourceURL, to: destinationURL)
                loadSavedFiles()
            } catch {
                print("Erreur copie: \(error)")
            }
        }
    }

    func deleteFiles(at offsets: IndexSet) {
        let fileManager = FileManager.default
        offsets.forEach { index in
            try? fileManager.removeItem(at: savedFiles[index])
        }
        loadSavedFiles()
    }
}

extension URL: Identifiable {
    public var id: String { self.absoluteString }
}

// --- 5. VUE ACCUEIL ---
struct HomeView: View {
    @ObservedObject var game: NoteGameManager
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                Image(systemName: "music.note.house.fill")
                    .font(.system(size: 50)).foregroundColor(.green)
                Text("Bienvenue") // "sur 100%Piano" supprimé ici
                    .font(.title3).bold()
            }
            .padding(.top, 30).padding(.bottom, 20)

            List {
                Section(header: Text("DÉMARRER UN ENTRAÎNEMENT")) {
                    NavigationLink(destination: LevelSelectionView(game: game, clef: .sol)) {
                        HStack {
                            Image(systemName: "clef.treble").foregroundColor(.green).font(.title2).frame(width: 30)
                            Text("Clé de Sol").fontWeight(.medium)
                        }.padding(.vertical, 4)
                    }
                    NavigationLink(destination: LevelSelectionView(game: game, clef: .fa)) {
                        HStack {
                            Image(systemName: "clef.bass").foregroundColor(.blue).font(.title2).frame(width: 30)
                            Text("Clé de Fa").fontWeight(.medium)
                        }.padding(.vertical, 4)
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
        }
    }
}

// --- 6. VUES DU JEU ---
struct LevelSelectionView: View {
    @ObservedObject var game: NoteGameManager
    let clef: ClefType
    var body: some View {
        VStack(spacing: 20) {
            Text("Difficulté : \(clef == .sol ? "Clé de Sol" : "Clé de Fa")").font(.headline).foregroundColor(.secondary).padding(.top)
            LevelBtn(title: "FACILE", color: .green, diff: .facile, clef: clef, game: game)
            LevelBtn(title: "MOYEN", color: .orange, diff: .moyen, clef: clef, game: game)
            LevelBtn(title: "DIFFICILE", color: .red, diff: .difficile, clef: clef, game: game)
            Spacer()
        }.navigationTitle(clef == .sol ? "Clé de Sol" : "Clé de Fa")
    }
}

struct LevelBtn: View {
    let title: String; let color: Color; let diff: Difficulty; let clef: ClefType; let game: NoteGameManager
    var body: some View {
        NavigationLink(destination: GamePlayView()) {
            Text(title).font(.title2).bold().frame(maxWidth: .infinity).padding(.vertical, 25)
                .background(color.opacity(0.15)).foregroundColor(color).cornerRadius(15)
                .overlay(RoundedRectangle(cornerRadius: 15).stroke(color, lineWidth: 2))
        }
        .padding(.horizontal, 30)
        .simultaneousGesture(TapGesture().onEnded { game.startGame(difficulty: diff, clef: clef) })
    }
}

struct GamePlayView: View {
    @EnvironmentObject var game: NoteGameManager
    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Score : \(game.score)").font(.system(size: 25, weight: .black))
                Spacer()
                Text(game.feedbackEmoji).font(.system(size: 40))
            }.padding(.horizontal).padding(.top, 20)

            ZStack {
                RoundedRectangle(cornerRadius: 20).fill(Color.white)
                VStack(spacing: 13) {
                    ForEach(0..<5) { _ in Rectangle().fill(Color.black).frame(height: 1.5) }
                }.frame(width: 320)
                
                Text(game.currentClef == .sol ? "𝄞" : "𝄢")
                    .font(.system(size: game.currentClef == .sol ? 95 : 75))
                    .foregroundColor(.black)
                    .offset(x: -125, y: game.currentClef == .sol ? -8 : -10)
                
                Group {
                    if game.noteOffset >= 43.5 { Rectangle().fill(Color.black).frame(width: 40, height: 2).offset(y: 43.5) }
                    if game.noteOffset >= 58.0 { Rectangle().fill(Color.black).frame(width: 40, height: 2).offset(y: 58.0) }
                    if game.noteOffset >= 72.5 { Rectangle().fill(Color.black).frame(width: 40, height: 2).offset(y: 72.5) }
                    if game.noteOffset >= 87.0 { Rectangle().fill(Color.black).frame(width: 40, height: 2).offset(y: 87.0) }
                    if game.noteOffset >= 101.5 { Rectangle().fill(Color.black).frame(width: 40, height: 2).offset(y: 101.5) }
                    if game.noteOffset >= 116.0 { Rectangle().fill(Color.black).frame(width: 40, height: 2).offset(y: 116.0) }
                    
                    if game.noteOffset <= -43.5 { Rectangle().fill(Color.black).frame(width: 40, height: 2).offset(y: -43.5) }
                    if game.noteOffset <= -58.0 { Rectangle().fill(Color.black).frame(width: 40, height: 2).offset(y: -58.0) }
                    if game.noteOffset <= -72.5 { Rectangle().fill(Color.black).frame(width: 40, height: 2).offset(y: -72.5) }
                    if game.noteOffset <= -87.0 { Rectangle().fill(Color.black).frame(width: 40, height: 2).offset(y: -87.0) }
                    
                    Ellipse()
                        .fill(game.feedbackEmoji == "❌" ? Color.red : Color.black)
                        .frame(width: 21, height: 12)
                        .offset(y: game.noteOffset)
                }
            }
            .frame(height: 300).padding(.horizontal, 10)

            HStack(spacing: 6) {
                ForEach(game.noteNames, id: \.self) { note in
                    Button(action: { game.checkAnswer(note) }) {
                        Text(note).font(.system(size: 14, weight: .bold))
                            .frame(maxWidth: .infinity).frame(height: 60)
                            .background(Color(white: 0.2)).foregroundColor(.white).cornerRadius(8)
                    }
                }
            }.padding(.horizontal, 10).padding(.bottom, 30)
            Spacer()
        }
        .navigationTitle(game.currentClef == .sol ? "Clé de Sol" : "Clé de Fa")
    }
}

// --- 7. AUTHENTIFICATION ---
struct LoginView: View {
    @Binding var isLoggedIn: Bool
    @Binding var userEmail: String
    @State private var showRegistration = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 25) {
                Image("piano_accueil")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 300, height: 350)
                    .cornerRadius(30)
                    .padding(.top, 20)
                
                Text("Connecte-toi afin d'accéder aux exercices et devenir un expert en lecture de notes !")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
                
                VStack(spacing: 20) {
                    SocialLoginButton(icon: "google_logo", label: "Continuer avec Google", isSystem: false) { signInWithGoogle() }
                    SocialLoginButton(icon: "facebook_logo", label: "Continuer avec Facebook", isSystem: false) { signInWithFacebook() }
                    SocialLoginButton(icon: "envelope.fill", label: "S'inscrire par E-mail", isSystem: true) { showRegistration = true }
                }
                .padding(.horizontal, 25)
                
                Spacer()
            }
            .sheet(isPresented: $showRegistration) { NavigationStack { RegistrationForm() } }
        }
    }
    
    func signInWithFacebook() {
        let loginManager = LoginManager()
        loginManager.logIn(permissions: ["public_profile", "email"], from: nil) { result, error in
            if error == nil, let token = AccessToken.current?.tokenString {
                let credential = FacebookAuthProvider.credential(withAccessToken: token)
                Auth.auth().signIn(with: credential) { authResult, _ in
                    self.userEmail = authResult?.user.email ?? "Utilisateur"; self.isLoggedIn = true
                }
            }
        }
    }
    
    func signInWithGoogle() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else { return }
        GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController) { result, _ in
            guard let user = result?.user, let idToken = user.idToken?.tokenString else { return }
            let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: user.accessToken.tokenString)
            Auth.auth().signIn(with: credential) { authResult, _ in
                self.userEmail = authResult?.user.email ?? ""; self.isLoggedIn = true
            }
        }
    }
}

struct SocialLoginButton: View {
    let icon: String; let label: String; let isSystem: Bool; let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack {
                if isSystem {
                    Image(systemName: icon)
                        .font(.title3)
                } else {
                    Image(icon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 22, height: 22)
                }
                Spacer()
                Text(label)
                    .fontWeight(.semibold)
                Spacer()
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 20)
            .background(Color(white: 0.15))
            .foregroundColor(.white)
            .cornerRadius(15)
        }
    }
}

struct RegistrationForm: View {
    @Environment(\.dismiss) var dismiss
    @AppStorage("isLoggedIn") var isLoggedIn = false
    @State private var email = ""; @State private var password = ""
    var body: some View {
        Form {
            Section(header: Text("Créer un compte")) {
                TextField("Email", text: $email); SecureField("Mot de passe", text: $password)
            }
            Button("S'inscrire") {
                Auth.auth().createUser(withEmail: email, password: password) { _, _ in isLoggedIn = true; dismiss() }
            }
        }.navigationTitle("Inscription")
    }
}

#Preview {
    ContentView()
}
