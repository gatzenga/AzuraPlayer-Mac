import Foundation

/// Returns the English or German string based on the stored language preference.
@inline(__always)
func tr(_ en: String, _ de: String, _ lang: String = "en") -> String {
    lang == "de" ? de : en
}
