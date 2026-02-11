import SwiftUI
import FirebaseCore
import FacebookCore

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Initialisation de Firebase
        FirebaseApp.configure()
        
        // Forçage manuel des identifiants Facebook pour garantir le fonctionnement
        Settings.shared.appID = "1756753791968550"
        Settings.shared.clientToken = "96fd8ab5c5d4e4ead92358c5705ea588"
        Settings.shared.displayName = "PianoApp"
        
        ApplicationDelegate.shared.application(application, didFinishLaunchingWithOptions: launchOptions)
        
        return true
    }
}

@main
struct PianoAppApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    // VERSION FINALE : On supprime totalement les dictionnaires d'options
                    // pour éviter l'avertissement 'OpenURLOptionsKey' obsolète.
                    ApplicationDelegate.shared.application(
                        UIApplication.shared,
                        open: url,
                        sourceApplication: nil,
                        annotation: nil
                    )
                }
        }
    }
}
