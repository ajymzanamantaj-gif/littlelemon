import SwiftUI

struct HomeView: View {
    let guest: Guest
    @ObservedObject var menu: MenuStore
    let save: (Guest) -> Void
    let logout: () -> Void
    @State private var search = ""
    @State private var category: String?
    @State private var order = MenuOrder.name
    @State private var basket: [MenuItem: Int] = [:]

    private var categories: [String] {
        let all = Set(menu.items.map(\.category))
        let standard = ["starters", "mains", "desserts", "drinks"]
        return standard.filter(all.contains) + all.subtracting(standard).sorted()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    hero
                    VStack(alignment: .leading, spacing: 15) {
                        HStack {
                            Text("Order for pickup").font(.title2.bold())
                            Spacer()
                            Menu {
                                Picker("Sort menu", selection: $order) {
                                    ForEach(MenuOrder.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                                }
                            } label: { Image(systemName: "arrow.up.arrow.down.circle").font(.title2) }
                            .accessibilityLabel("Sort menu")
                        }
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                categoryButton("All", value: nil)
                                ForEach(categories, id: \.self) { categoryButton($0.capitalized, value: $0) }
                            }
                        }
                        if let notice = menu.notice { Text(notice).font(.footnote).foregroundStyle(.secondary) }
                        let entries = matchingMenu(menu.items, search: search, category: category, order: order)
                        if entries.isEmpty {
                            Text("No dishes match your search.").padding(.vertical)
                            Button("Clear filters") { category = nil; search = "" }
                        }
                        ForEach(entries) { item in
                            NavigationLink {
                                DishPage(item: item) { basket[item, default: 0] += 1 }
                            } label: {
                                HStack(alignment: .center, spacing: 16) {
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(item.title).font(.headline)
                                        Text(item.description).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
                                        Text(item.displayPrice).font(.subheadline.bold()).foregroundStyle(Palette.green)
                                    }
                                    Spacer(minLength: 0)
                                    DishPhoto(item: item).frame(width: 76, height: 76)
                                }.contentShape(Rectangle())
                            }.buttonStyle(.plain)
                            Divider()
                        }
                    }.padding(20)
                }
            }
            .refreshable { await menu.refresh() }
            .navigationTitle("Little Lemon").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    NavigationLink {
                        BasketView(basket: $basket)
                    } label: { Label("Bag \(basket.values.reduce(0,+))", systemImage: "bag") }
                    .accessibilityLabel("Order bag, \(basket.values.reduce(0,+)) items")
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink {
                        ProfileView(guest: guest, save: save, logout: logout)
                    } label: {
                        Text(guest.initials).font(.caption.bold()).padding(8)
                            .background(Palette.gold, in: Circle())
                    }.accessibilityLabel("Profile")
                }
            }
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Little Lemon").font(.system(.largeTitle, design: .serif).bold()).foregroundStyle(Palette.gold)
                    Text("Chicago").font(.system(.title3, design: .serif).bold())
                    Text("A family-run Mediterranean kitchen serving bright salads, grilled dishes and house desserts.")
                        .font(.subheadline)
                }
                Spacer(minLength: 0)
                if let featured = menu.items.first(where: { $0.id == 1 }) {
                    DishPhoto(item: featured).frame(width: 96, height: 122)
                }
            }
            HStack {
                Image(systemName: "magnifyingglass").accessibilityHidden(true)
                TextField("Search the menu", text: $search)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                if !search.isEmpty {
                    Button { search = "" } label: { Image(systemName: "xmark.circle.fill") }.accessibilityLabel("Clear search")
                }
            }.padding(11).foregroundStyle(.primary).background(.background, in: RoundedRectangle(cornerRadius: 10))
            .environment(\.colorScheme, .light)
        }.padding(20).frame(maxWidth: .infinity, alignment: .leading).foregroundStyle(.white).background(Palette.green)
    }

    private func categoryButton(_ title: String, value: String?) -> some View {
        Button { category = value } label: {
            Text(title).font(.subheadline.bold()).padding(.horizontal, 13).padding(.vertical, 9)
                .foregroundStyle(category == value ? Color.white : Palette.green)
                .background(category == value ? Palette.green : Palette.cream, in: Capsule())
        }.accessibilityAddTraits(category == value ? .isSelected : [])
    }
}

struct DishPhoto: View {
    let item: MenuItem
    var body: some View {
        GeometryReader { geometry in
            AsyncImage(url: URL(string: item.image)) { phase in
                if let photo = phase.image {
                    photo.resizable().scaledToFill()
                } else {
                    ZStack {
                        Palette.cream
                        Image(systemName: "fork.knife").font(.title3).foregroundStyle(Palette.green)
                    }
                }
            }.frame(width: geometry.size.width, height: geometry.size.height)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }.accessibilityHidden(true)
    }
}

struct DishPage: View {
    let item: MenuItem
    let add: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                DishPhoto(item: item).frame(height: 235)
                Text(item.category.capitalized).font(.subheadline).foregroundStyle(.secondary)
                Text(item.title).font(.system(.largeTitle, design: .serif).bold())
                Text(item.description)
                Button("Add to bag • \(item.displayPrice)") { add(); dismiss() }.buttonStyle(PrimaryButton())
            }.frame(maxWidth: .infinity, alignment: .leading).padding(20)
        }.navigationTitle("Dish details").navigationBarTitleDisplayMode(.inline)
    }
}

struct BasketView: View {
    @Binding var basket: [MenuItem: Int]
    @State private var ordered = false

    private var total: Decimal {
        basket.reduce(Decimal.zero) { $0 + $1.key.amount * Decimal($1.value) }
    }

    var body: some View {
        List {
            if basket.isEmpty { Text("Your bag is empty.").foregroundStyle(.secondary) }
            ForEach(basket.keys.sorted { $0.title < $1.title }) { item in
                Stepper(value: Binding(get: { basket[item] ?? 0 }, set: { count in
                    if count == 0 { basket.removeValue(forKey: item) } else { basket[item] = count }
                }), in: 0...99) {
                    VStack(alignment: .leading) {
                        Text(item.title).font(.headline)
                        Text("\(basket[item] ?? 0) × \(item.displayPrice)").font(.subheadline)
                    }
                }
            }
            if !basket.isEmpty {
                LabeledContent("Total", value: total.formatted(.currency(code: "USD")))
                Button("Place demo order") { basket.removeAll(); ordered = true }.buttonStyle(PrimaryButton())
            }
        }
        .navigationTitle("Your bag")
        .alert("Demo order placed", isPresented: $ordered, actions: {
            Button("Done", role: .cancel) {}
        }, message: {
            Text("Your pickup order was recorded for this demo.")
        })
    }
}
