import Foundation

struct Guest: Codable, Equatable {
    var first = ""
    var last = ""
    var email = ""
    var phone = ""
    var orderUpdates = true
    var newsletter = false

    var validName: Bool {
        !first.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !last.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    var validEmail: Bool {
        email.trimmingCharacters(in: .whitespacesAndNewlines)
            .range(of: #"^[^\s@]+@[^\s@]+\.[^\s@]+$"#, options: .regularExpression) != nil
    }
    var initials: String { (String(first.prefix(1)) + String(last.prefix(1))).uppercased() }
    func normalized() -> Guest {
        var copy = self
        copy.first = first.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.last = last.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.phone = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        return copy
    }
}
