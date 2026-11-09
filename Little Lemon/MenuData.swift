import Foundation
import CoreData
import Combine

struct MenuResponse: Decodable {
    let menu: [MenuItem]
}

struct MenuItem: Codable, Hashable, Identifiable {
    let id: Int
    let title: String
    let description: String
    let price: String
    let image: String
    let category: String

    var amount: Decimal { Decimal(string: price, locale: Locale(identifier: "en_US_POSIX")) ?? 0 }
    var displayPrice: String { amount.formatted(.currency(code: "USD")) }
}

enum MenuOrder: String, CaseIterable {
    case name = "Name"
    case price = "Price"
}

func matchingMenu(_ items: [MenuItem], search: String, category: String?, order: MenuOrder) -> [MenuItem] {
    let term = search.trimmingCharacters(in: .whitespacesAndNewlines)
    return items.filter { item in
        (category == nil || item.category == category) &&
        (term.isEmpty || item.title.range(of: term, options: [.caseInsensitive, .diacriticInsensitive]) != nil)
    }.sorted { lhs, rhs in
        if order == .price && lhs.amount != rhs.amount { return lhs.amount < rhs.amount }
        return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
    }
}

@MainActor
final class MenuStore: ObservableObject {
    @Published private(set) var items: [MenuItem] = []
    @Published private(set) var notice: String?
    private let container: NSPersistentContainer
    private static let endpoint = URL(string: "https://raw.githubusercontent.com/Meta-Mobile-Developer-PC/Working-With-Data-API/main/menu.json")!
    private var ready = false
    private var busy = false

    init() {
        let model = NSManagedObjectModel()
        let dish = NSEntityDescription()
        dish.name = "Dish"
        dish.managedObjectClassName = NSStringFromClass(NSManagedObject.self)
        dish.properties = ["id", "title", "descriptionText", "price", "image", "category"].map { key in
            let attribute = NSAttributeDescription()
            attribute.name = key
            attribute.attributeType = key == "id" ? .integer64AttributeType : .stringAttributeType
            attribute.isOptional = false
            return attribute
        }
        dish.uniquenessConstraints = [["id"]]
        model.entities = [dish]
        container = NSPersistentContainer(name: "LittleLemonMenu", managedObjectModel: model)

        if let url = Bundle.main.url(forResource: "menu", withExtension: "json"),
           let bytes = try? Data(contentsOf: url),
           let bundled = try? JSONDecoder().decode(MenuResponse.self, from: bytes) {
            items = bundled.menu
        }
        container.loadPersistentStores { [weak self] _, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard error == nil else {
                    self.notice = "Device storage is unavailable. Showing the included menu."
                    return
                }
                self.ready = true
                if let cached = try? self.cachedItems(), !cached.isEmpty { self.items = cached }
                await self.refresh()
            }
        }
    }

    func refresh() async {
        guard ready, !busy else { return }
        busy = true
        defer { busy = false }
        do {
            let (data, response) = try await URLSession.shared.data(from: Self.endpoint)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                throw URLError(.badServerResponse)
            }
            let next = try JSONDecoder().decode(MenuResponse.self, from: data).menu
            guard !next.isEmpty, Set(next.map(\.id)).count == next.count,
                  next.allSatisfy({ !$0.title.isEmpty && !$0.category.isEmpty && Decimal(string: $0.price) != nil }) else {
                throw URLError(.cannotParseResponse)
            }
            try save(next)
            items = next
            notice = nil
        } catch {
            container.viewContext.rollback()
            notice = "Showing the saved menu. Pull down to try again."
        }
    }

    private func cachedItems() throws -> [MenuItem] {
        try container.viewContext.fetch(NSFetchRequest<NSManagedObject>(entityName: "Dish")).compactMap { row in
            guard let id = row.value(forKey: "id") as? NSNumber,
                  let title = row.value(forKey: "title") as? String,
                  let detail = row.value(forKey: "descriptionText") as? String,
                  let price = row.value(forKey: "price") as? String,
                  let image = row.value(forKey: "image") as? String,
                  let category = row.value(forKey: "category") as? String else { return nil }
            return MenuItem(id: id.intValue, title: title, description: detail, price: price, image: image, category: category)
        }
    }

    private func save(_ menu: [MenuItem]) throws {
        let context = container.viewContext
        let rows = try context.fetch(NSFetchRequest<NSManagedObject>(entityName: "Dish"))
        var byID = Dictionary(uniqueKeysWithValues: rows.compactMap { row -> (Int, NSManagedObject)? in
            guard let id = row.value(forKey: "id") as? NSNumber else { return nil }
            return (id.intValue, row)
        })
        for item in menu {
            let row = byID.removeValue(forKey: item.id) ?? NSEntityDescription.insertNewObject(forEntityName: "Dish", into: context)
            row.setValue(item.id, forKey: "id")
            row.setValue(item.title, forKey: "title")
            row.setValue(item.description, forKey: "descriptionText")
            row.setValue(item.price, forKey: "price")
            row.setValue(item.image, forKey: "image")
            row.setValue(item.category, forKey: "category")
        }
        byID.values.forEach { context.delete($0) }
        if context.hasChanges { try context.save() }
    }
}
