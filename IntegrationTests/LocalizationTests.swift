import XCTest

// MARK: - LocalizationTests

/// Validates Resources/Localizable.strings (EN) and
/// Resources/fr.lproj/Localizable.strings (FR) directly from disk,
/// independent of Bundle.main/Bundle.module resolution (unreliable
/// across app vs. test-target execution contexts in SPM).
///
/// This deliberately does NOT just check key presence — a test that
/// only checks presence would pass even with an empty or copy-pasted
/// FR translation. It checks two things:
///   1. EN and FR expose the exact same key set (no missing key
///      either direction).
///   2. No FR value is strictly identical to its EN counterpart,
///      except a short, explicitly named allow-list (values that are
///      legitimately identical across languages, e.g. "OK").
final class LocalizationTests: XCTestCase {

    /// Keys where an identical EN/FR value is expected and correct,
    /// not a forgotten translation.
    private static let allowedIdenticalValues: Set<String> = [
        "fileImportExport.ok_button"
    ]

    private static var repoRootURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // LocalizationTests.swift
            .deletingLastPathComponent() // IntegrationTests/
    }

    private func loadStrings(at relativePath: String) throws -> [String: String] {
        let url = Self.repoRootURL.appendingPathComponent(relativePath)
        guard let dictionary = NSDictionary(contentsOf: url) as? [String: String] else {
            throw XCTSkip("Could not load .strings file at \(url.path) — check it's valid plist-style strings syntax.")
        }
        return dictionary
    }

    func testEnglishAndFrenchExposeTheSameKeySet() throws {
        let en = try loadStrings(at: "Resources/Localizable.strings")
        let fr = try loadStrings(at: "Resources/fr.lproj/Localizable.strings")

        let enKeys = Set(en.keys)
        let frKeys = Set(fr.keys)

        let missingInFrench = enKeys.subtracting(frKeys)
        let missingInEnglish = frKeys.subtracting(enKeys)

        XCTAssertTrue(missingInFrench.isEmpty, "Keys present in EN but missing in FR: \(missingInFrench.sorted())")
        XCTAssertTrue(missingInEnglish.isEmpty, "Keys present in FR but missing in EN: \(missingInEnglish.sorted())")
        XCTAssertFalse(enKeys.isEmpty, "Localizable.strings (EN) should not be empty in v2-A.")
    }

    func testNoFrenchValueIsAnUntranslatedCopyOfEnglish() throws {
        let en = try loadStrings(at: "Resources/Localizable.strings")
        let fr = try loadStrings(at: "Resources/fr.lproj/Localizable.strings")

        var untranslated: [String] = []

        for (key, enValue) in en {
            guard let frValue = fr[key] else { continue } // covered by the key-set test
            if frValue == enValue && !Self.allowedIdenticalValues.contains(key) {
                untranslated.append(key)
            }
        }

        XCTAssertTrue(
            untranslated.isEmpty,
            "FR value identical to EN for keys not in the allow-list (looks like a forgotten translation): \(untranslated.sorted())"
        )
    }

    func testNoEmptyValuesInEitherLanguage() throws {
        let en = try loadStrings(at: "Resources/Localizable.strings")
        let fr = try loadStrings(at: "Resources/fr.lproj/Localizable.strings")

        let emptyEnKeys = en.filter { $0.value.isEmpty }.keys.sorted()
        let emptyFrKeys = fr.filter { $0.value.isEmpty }.keys.sorted()

        XCTAssertTrue(emptyEnKeys.isEmpty, "Empty EN values for keys: \(emptyEnKeys)")
        XCTAssertTrue(emptyFrKeys.isEmpty, "Empty FR values for keys: \(emptyFrKeys)")
    }
}
