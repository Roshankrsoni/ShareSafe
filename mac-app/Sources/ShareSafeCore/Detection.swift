import Foundation
import NaturalLanguage

public struct SensitiveDetector: Sendable {
    public var includeNames: Bool
    public init(includeNames: Bool = true) { self.includeNames = includeNames }

    public func detect(_ text: String, pageIndex: Int = 0) -> [Finding] {
        let source = text as NSString
        var findings: [Finding] = []
        let patterns: [(SensitiveKind, String)] = [
            (.profile, #"(?i)(?:https?://)?(?:www\.)?(?:linkedin\.com/in|github\.com|instagram\.com)/[A-Z0-9._%/-]+"#),
            (.pan, #"(?i)(?<![A-Z0-9])[A-Z]{3}[ABCFGHLJPT][A-Z][0-9]{4}[A-Z](?![A-Z0-9])"#),
            (.aadhaar, #"(?<![\p{L}\d+])(?<!\d[\p{Zs}\t-])[2-9]\d{3}[\p{Zs}\t-]?\d{4}[\p{Zs}\t-]?\d{4}(?![\p{Zs}\t-]?\d)"#),
            (.upi, #"(?i)[A-Z0-9._-]+@(?:okaxis|okhdfcbank|oksbi|okicici|ybl|ibl|axl|paytm|upi|apl)(?![A-Z0-9.])"#),
            (.email, #"(?i)[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}"#),
            (.identity, #"\b(?!000|666|9\d\d)\d{3}-(?!00)\d{2}-(?!0000)\d{4}\b"#),
            (.paymentCard, #"(?<!\d)(?:\d[ -]?){12,18}\d(?!\d)"#),
            (.phone, #"(?<![\w])(?:\+91[\p{Zs}\t.-]?)?[6-9]\d{4}[\p{Zs}\t.-]?\d{5}(?!\d)"#),
            (.phone, #"(?<![\w])\+[1-9]\d{0,2}(?:[\p{Zs}\t().-]*\d){7,12}(?!\d)"#),
            (.phone, #"(?<![\w])(?:\+\d{1,3}[ .-]?)?(?:\(\d{2,4}\)|\d{2,4})[ .-]\d{3,4}[ .-]\d{3,4}(?!\d)"#)
        ]
        for (kind, pattern) in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            for match in regex.matches(in: text, range: NSRange(location: 0, length: source.length)) {
                let value = source.substring(with: match.range)
                if kind == .paymentCard && !Self.isValidCard(value) { continue }
                if findings.contains(where: { NSIntersectionRange($0.range, match.range).length > 0 }) { continue }
                findings.append(Finding(kind: kind, value: value, pageIndex: pageIndex, range: match.range))
            }
        }
        // Label-based rules intentionally return review suggestions, not identity validation.
        let labeled: [(SensitiveKind, String)] = [
            (.bankAccount, #"(?im)(?:account(?:[ \t]*(?:number|no\.?))?|a/c|IBAN)[ \t]*[:：#-][ \t]*([A-Z0-9][A-Z0-9 \t-]{5,32})"#),
            (.passport, #"(?im)(?:passport|national[ \t]+id|voter[ \t]+id)(?:[ \t]*(?:number|no\.?))?[ \t]*[:：#-][ \t]*([A-Z0-9][A-Z0-9-]{5,17})"#),
            (.dateOfBirth, #"(?im)(?:DOB|date[ \t]+of[ \t]+birth|birth[ \t]+date|जन्म[ \t]*तिथि)[ \t]*[:：-]?[ \t]*(\d{1,4}[/.-]\d{1,2}[/.-]\d{1,4})"#),
            (.address, #"(?im)(?:address|पता)[ \t]*[:：][ \t]*([^\r\n]{5,160})"#)
        ] + (includeNames ? [(.person, #"(?im)^[ \t]*(?:full[ \t]+name|name|नाम|prepared for|holder|applicant)(?:[ \t]*name)?(?:[ \t]*[:：][ \t]*(?:\r?\n[ \t]*)?|[ \t]*\r?\n[ \t]*)([\p{L}][\p{L}\p{M} .'-]{2,70})"#)] : [])
        for (kind, pattern) in labeled {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            for match in regex.matches(in: text, range: NSRange(location: 0, length: source.length)) {
                let range = match.range(at: 1)
                if kind == .person && !Self.plausibleName(source.substring(with: range)) { continue }
                // Keep label-based fields even if they overlap a generic phone candidate.
                findings.removeAll { NSIntersectionRange($0.range, range).length > 0 }
                findings.append(Finding(kind: kind, value: source.substring(with: range), pageIndex: pageIndex, range: range))
            }
        }
        if includeNames && !text.isEmpty {
            // Person classification is advisory: require a plausible multiword name AND
            // contact context. Isolated OCR tokens and technology terms are not names.
            let tagger = NLTagger(tagSchemes: [.nameType])
            tagger.string = text
            tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType, options: [.omitWhitespace, .omitPunctuation, .joinNames]) { tag, range in
                let nsRange = NSRange(range, in: text)
                if tag == .personalName, Self.plausibleName(String(text[range])), nsRange.location < 350,
                   findings.contains(where: { [.email, .phone, .profile].contains($0.kind) && abs($0.range.location - nsRange.location) < 350 }),
                   !findings.contains(where: { NSIntersectionRange($0.range, nsRange).length > 0 }) {
                    findings.append(Finding(kind: .person, value: String(text[range]), pageIndex: pageIndex, range: nsRange))
                }
                return true
            }
            // Resume/contact-card headings often use small caps, which NER misses.
            if let first = text.range(of: #"(?m)^\s*([\p{L}][\p{L}\p{M} .'-]{3,65})[ \t]*$"#, options: .regularExpression) {
                let trimmed = String(text[first]).trimmingCharacters(in: .whitespacesAndNewlines)
                if Self.plausibleName(trimmed), let nameRange = text.range(of: trimmed, range: first) {
                    let range = NSRange(nameRange, in: text)
                    if range.location < 120, findings.contains(where: { [.email, .phone, .profile].contains($0.kind) && $0.range.location > NSMaxRange(range) && $0.range.location - NSMaxRange(range) < 250 }),
                       !findings.contains(where: { NSIntersectionRange($0.range, range).length > 0 }) {
                        findings.append(Finding(kind: .person, value: trimmed, pageIndex: pageIndex, range: range))
                    }
                }
            }
        }
        return findings.sorted { $0.range.location < $1.range.location }
    }

    private static func plausibleName(_ value: String) -> Bool {
        let words = value.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        guard (2...5).contains(words.count), words.allSatisfy({ $0.count >= 2 }),
              !value.contains("\n"), !value.contains(":") else { return false }
        let nonNames: Set<String> = ["technical", "skills", "experience", "engineer", "developer", "frontend", "backend", "technologies", "programming", "cloud", "infrastructure", "source", "control", "education", "project", "brief", "studio", "resume", "curriculum", "vitae", "webviews", "webview", "react", "node", "javascript", "typescript", "vercel", "jest", "redux", "pwa", "ui", "software", "senior", "publicis", "sapient", "india", "contact", "details", "northstar"]
        return !words.contains { nonNames.contains($0.lowercased().trimmingCharacters(in: .punctuationCharacters)) }
    }

    public static func isValidCard(_ value: String) -> Bool {
        let digits = value.compactMap(\.wholeNumberValue)
        guard (13...19).contains(digits.count), Set(digits).count > 1 else { return false }
        let sum = digits.reversed().enumerated().reduce(0) { total, pair in
            var n = pair.element
            if pair.offset % 2 == 1 { n *= 2; if n > 9 { n -= 9 } }
            return total + n
        }
        return sum % 10 == 0
    }

    public static func exactMatches(_ term: String, in text: String) -> [NSRange] {
        guard !term.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let regex = try? NSRegularExpression(pattern: NSRegularExpression.escapedPattern(for: term), options: [.caseInsensitive]) else { return [] }
        return regex.matches(in: text, range: NSRange(location: 0, length: (text as NSString).length)).map(\.range)
    }
}

public enum TextRedactor {
    public static func redact(_ text: String, findings: [Finding], aliases: Bool) -> String {
        let source = text as NSString
        let selected = findings.filter { $0.decision == .redact }.sorted { $0.range.location < $1.range.location }
        var replacements: [(NSRange, String)] = []
        var mapping: [String: String] = [:]
        var counts: [SensitiveKind: Int] = [:]
        for finding in selected {
            guard finding.range.location >= 0, finding.range.length > 0, NSMaxRange(finding.range) <= source.length else { continue }
            var range = finding.range
            if let last = replacements.last, NSIntersectionRange(last.0, range).length > 0 {
                replacements.removeLast()
                range = NSUnionRange(last.0, range)
                replacements.append((range, "[REDACTED]"))
                continue
            }
            let key = finding.kind.rawValue + ":" + finding.value.lowercased()
            if mapping[key] == nil {
                counts[finding.kind, default: 0] += 1
                mapping[key] = "[\(finding.kind.rawValue.uppercased())_\(counts[finding.kind, default: 0])]"
            }
            replacements.append((range, aliases ? mapping[key]! : "[REDACTED]"))
        }
        let result = NSMutableString(string: text)
        for (range, value) in replacements.reversed() { result.replaceCharacters(in: range, with: value) }
        return result as String
    }
}
