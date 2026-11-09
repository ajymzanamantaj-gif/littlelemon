import SwiftUI
import UIKit

enum Palette {
    static let green = Color(red: 0.19, green: 0.31, blue: 0.26)
    static let gold = Color(red: 0.98, green: 0.83, blue: 0.22)
    static let cream = Color(red: 0.98, green: 0.97, blue: 0.94)
}

@MainActor
struct ContentView: View {
    @AppStorage("littlelemon.guest.v1") private var savedGuest = Data()
    @StateObject private var menu = MenuStore()

    var body: some View {
        Group {
            if let guest = try? JSONDecoder().decode(Guest.self, from: savedGuest) {
                HomeView(guest: guest, menu: menu, save: save, logout: { savedGuest = Data() })
            } else {
                OnboardingView(finish: save)
            }
        }
        .tint(Palette.green)
    }

    private func save(_ guest: Guest) {
        if let data = try? JSONEncoder().encode(guest.normalized()) { savedGuest = data }
    }
}

struct PrimaryButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.headline).frame(maxWidth: .infinity).padding(.vertical, 14)
            .background(Palette.gold).foregroundStyle(.black)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

struct OnboardingView: View {
    @State private var guest = Guest()
    @State private var step = 0
    let finish: (Guest) -> Void
    private let titles = ["Welcome to Little Lemon", "How can we reach you?", "Your preferences"]
    private let context = ["Enter your name to start your guest profile.",
                           "Use an email address for your profile. Phone is optional.",
                           "Choose which updates you would like to receive."]
    private var canContinue: Bool { step == 0 ? guest.validName : guest.validEmail }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("LITTLE LEMON  /  CHICAGO").font(.caption.weight(.bold)).tracking(2)
                    ProgressView(value: Double(step + 1), total: 3).tint(Palette.green)
                    Text("Step \(step + 1) of 3").font(.subheadline).foregroundStyle(.secondary)
                    Text(titles[step]).font(.system(.largeTitle, design: .serif).weight(.semibold))
                    Text(context[step])
                    switch step {
                    case 0:
                        GuestField("First name", text: $guest.first, content: .givenName)
                        GuestField("Last name", text: $guest.last, content: .familyName)
                    case 1:
                        GuestField("Email", text: $guest.email, content: .emailAddress)
                            .keyboardType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled()
                        GuestField("Phone (optional)", text: $guest.phone, content: .telephoneNumber).keyboardType(.phonePad)
                    default:
                        Toggle("Order updates", isOn: $guest.orderUpdates)
                        Toggle("Restaurant newsletter", isOn: $guest.newsletter)
                    }
                    Button(step == 2 ? "Finish registration" : "Next") {
                        if step == 2 { finish(guest) } else { step += 1 }
                    }
                    .buttonStyle(PrimaryButton()).disabled(!canContinue).opacity(canContinue ? 1 : 0.45)
                }.padding(24)
            }
            .navigationTitle("Guest registration").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if step > 0 {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button { step -= 1 } label: { Label("Back", systemImage: "chevron.left") }
                    }
                }
            }
        }
    }
}

struct GuestField: View {
    let title: String
    @Binding var text: String
    let content: UITextContentType
    init(_ title: String, text: Binding<String>, content: UITextContentType) {
        self.title = title
        _text = text
        self.content = content
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.subheadline.weight(.semibold))
            TextField(title, text: $text)
                .textContentType(content).textFieldStyle(.roundedBorder).accessibilityLabel(title)
        }
    }
}

struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var edited: Guest
    let save: (Guest) -> Void
    let logout: () -> Void

    init(guest: Guest, save: @escaping (Guest) -> Void, logout: @escaping () -> Void) {
        _edited = State(initialValue: guest)
        self.save = save
        self.logout = logout
    }

    var body: some View {
        Form {
            Section("Personal information") {
                GuestField("First name", text: $edited.first, content: .givenName)
                GuestField("Last name", text: $edited.last, content: .familyName)
                GuestField("Email", text: $edited.email, content: .emailAddress)
                    .keyboardType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled()
                GuestField("Phone (optional)", text: $edited.phone, content: .telephoneNumber).keyboardType(.phonePad)
            }
            Section("Notifications") {
                Toggle("Order updates", isOn: $edited.orderUpdates)
                Toggle("Restaurant newsletter", isOn: $edited.newsletter)
            }
            Section {
                Button("Save changes") { save(edited); dismiss() }
                    .disabled(!edited.validName || !edited.validEmail)
                Button("Discard changes") { dismiss() }
            }
            Section { Button("Log out", role: .destructive, action: logout) }
        }.navigationTitle("Profile")
    }
}
