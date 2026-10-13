import Foundation
import TMaps

/// What a shop page needs. In a real app this arrives from your backend.
struct Store {
    let name: String
    let tagline: String
    let position: TLatLng
    let address: String
    let rating: Double
    let reviews: Int
    let priceLevel: String
    let phone: String
    let about: String
    let specialties: [String]
    /// Monday first. `nil` hours mean closed that day.
    let hours: [(day: String, hours: String?)]
}

extension Store {
    static let darZaytoun = Store(
        name: "Dar Zaytoun",
        tagline: "Épicerie fine · Olive oil, harissa and spices",
        position: TLatLng(latitude: 36.87090, longitude: 10.34790),
        address: "14 Rue Sidi Bou Fares, Sidi Bou Saïd 2026",
        rating: 4.8,
        reviews: 212,
        priceLevel: "€€",
        phone: "+21671000000",
        about: "Three generations of the same family have pressed olives in the Sahel. The " +
            "Sidi Bou Saïd shop opened in 1998 and still sells what the grove produces: single-estate " +
            "oil bottled the week it is pressed, harissa ground slowly, and dates brought up from " +
            "Kebili every winter.",
        specialties: ["Olive oil", "Harissa", "Deglet Nour dates", "Spices", "Ceramics"],
        hours: [
            ("Monday", "09:00 – 19:00"),
            ("Tuesday", "09:00 – 19:00"),
            ("Wednesday", "09:00 – 19:00"),
            ("Thursday", "09:00 – 19:00"),
            ("Friday", "09:00 – 13:00, 15:00 – 20:00"),
            ("Saturday", "09:00 – 20:00"),
            ("Sunday", nil),
        ]
    )

    /// Index into `hours` for today: `hours` is Monday-first, `Calendar.weekday` is Sunday = 1.
    static func todayIndex(_ date: Date = Date()) -> Int {
        (Calendar(identifier: .gregorian).component(.weekday, from: date) + 5) % 7
    }

    /// Apple Maps directions to the shop. Opens the Maps app, or the web if it was removed.
    var directionsURL: URL {
        var comps = URLComponents(string: "https://maps.apple.com/")!
        comps.queryItems = [
            URLQueryItem(name: "daddr", value: "\(position.latitude),\(position.longitude)"),
            URLQueryItem(name: "q", value: name),
        ]
        return comps.url!
    }

    var phoneURL: URL { URL(string: "tel:\(phone)")! }
}
