import Foundation

extension UserDefaults {
    @objc dynamic var showSongTitleInMenuBar: Bool {
        get { bool(forKey: "showSongTitleInMenuBar") }
        set { set(newValue, forKey: "showSongTitleInMenuBar") }
    }
}
