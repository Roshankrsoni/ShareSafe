import Foundation
import CoreGraphics

public enum SensitiveKind: String, CaseIterable, Codable, Identifiable, Sendable {
    case profile, email, phone, paymentCard, identity, aadhaar, pan, bankAccount, passport, dateOfBirth, address, upi, person, face, custom
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .profile: return "Personal profile"
        case .email: return "Email address"
        case .phone: return "Phone number"
        case .paymentCard: return "Payment card"
        case .identity: return "US Social Security number"
        case .aadhaar: return "Possible Aadhaar"
        case .pan: return "PAN candidate"
        case .bankAccount: return "Bank account"
        case .passport: return "Passport / ID"
        case .dateOfBirth: return "Date of birth"
        case .address: return "Address"
        case .upi: return "UPI / payment handle"
        case .person: return "Person name"
        case .face: return "Face region"
        case .custom: return "Custom text"
        }
    }
    public var symbol: String {
        switch self {
        case .profile: return "link"
        case .email: return "envelope"
        case .phone: return "phone"
        case .paymentCard: return "creditcard"
        case .identity, .aadhaar, .pan, .passport: return "person.text.rectangle"
        case .bankAccount, .upi: return "building.columns"
        case .dateOfBirth: return "calendar"
        case .address: return "mappin.and.ellipse"
        case .person: return "person"
        case .face: return "face.smiling"
        case .custom: return "text.magnifyingglass"
        }
    }
}

public enum ReviewDecision: String, Sendable { case pending, redact, keep }
public enum DocumentKind: String, Sendable { case pdf, image, text }
public enum ManualMaskShape: String, CaseIterable, Identifiable, Sendable {
    case rectangle = "Rectangle", round = "Round"
    public var id: String { rawValue }
}
public enum SharingPolicy: String, CaseIterable, Identifiable, Sendable {
    case external = "External sharing", ai = "AI context"
    public var id: String { rawValue }
    public var detail: String {
        self == .external ? "Remove selected details from the shared copy." : "Use consistent aliases in plain text. PDFs and images use your selected mask style."
    }
}

public struct Finding: Identifiable, Sendable {
    public let id: UUID
    public var kind: SensitiveKind
    public var value: String
    public var pageIndex: Int
    public var range: NSRange
    /// Normalized coordinates, bottom-left origin, matching the rendered image.
    public var rectangles: [CGRect]
    public var decision: ReviewDecision
    public var maskShape: ManualMaskShape
    public init(id: UUID = UUID(), kind: SensitiveKind, value: String, pageIndex: Int = 0, range: NSRange, rectangles: [CGRect] = [], decision: ReviewDecision = .pending, maskShape: ManualMaskShape = .rectangle) {
        self.id = id; self.kind = kind; self.value = value; self.pageIndex = pageIndex
        self.range = range; self.rectangles = rectangles; self.decision = decision; self.maskShape = maskShape
    }
}

public struct ManualMask: Identifiable, Sendable {
    public var id = UUID()
    public var pageIndex: Int
    public var rect: CGRect
    public var shape: ManualMaskShape
    public init(pageIndex: Int, rect: CGRect, shape: ManualMaskShape = .rectangle) { self.pageIndex = pageIndex; self.rect = rect; self.shape = shape }
}

public struct TextRegion: Sendable {
    public var text: String
    public var range: NSRange
    public var rect: CGRect
    public init(text: String, range: NSRange, rect: CGRect) { self.text = text; self.range = range; self.rect = rect }
}

public struct DocumentPage: Identifiable, Sendable {
    public var id: Int { index }
    public var index: Int
    public var imageData: Data?
    public var pixelWidth: Int
    public var pixelHeight: Int
    public var pointWidth: Double
    public var pointHeight: Double
    public var text: String
    public var regions: [TextRegion]
    public var reviewed = false
    public init(index: Int, imageData: Data? = nil, pixelWidth: Int = 0, pixelHeight: Int = 0, pointWidth: Double = 612, pointHeight: Double = 792, text: String, regions: [TextRegion] = []) {
        self.index = index; self.imageData = imageData; self.pixelWidth = pixelWidth; self.pixelHeight = pixelHeight
        self.pointWidth = pointWidth; self.pointHeight = pointHeight; self.text = text; self.regions = regions
    }
}

public enum MaskEffect: String, CaseIterable, Identifiable, Sendable {
    case solid = "Solid", blur = "Blur"
    public var id: String { rawValue }
}

public struct MaskAppearance: Sendable, Equatable {
    public var effect: MaskEffect = .solid
    public var red: Double = 0
    public var green: Double = 0
    public var blue: Double = 0
    public var blurRadius: Double = 20
    public init() {}
    public var color: CGColor { CGColor(red: red, green: green, blue: blue, alpha: 1) }
    public var isValid: Bool { [red, green, blue].allSatisfy { $0.isFinite && (0...1).contains($0) } && blurRadius.isFinite && (10...60).contains(blurRadius) }
}

public struct ReviewDocument: Identifiable, Sendable {
    public var id = UUID()
    public var name: String
    public var sourceURL: URL?
    public var kind: DocumentKind
    public var pages: [DocumentPage]
    public var findings: [Finding]
    public var masks: [ManualMask] = []
    public var policy: SharingPolicy = .external
    public var maskAppearance = MaskAppearance()
    public var isSample = false
    public var wasPrepared = false
    public var pendingCount: Int { findings.filter { $0.decision == .pending }.count }
    public var redactionCount: Int { findings.filter { $0.decision == .redact }.count + masks.count }
    public var canExport: Bool { !pages.isEmpty && pendingCount == 0 && pages.allSatisfy(\.reviewed) }
    public mutating func completeReview(page index: Int, keepingUnselected: Bool) {
        guard pages.indices.contains(index) else { return }
        if keepingUnselected {
            for i in findings.indices where findings[i].pageIndex == index && findings[i].decision == .pending { findings[i].decision = .keep }
        }
        pages[index].reviewed = !findings.contains { $0.pageIndex == index && $0.decision == .pending }
    }
    public var pixelCount: Int { pages.reduce(0) { $0 + $1.pixelWidth * $1.pixelHeight } }
    public init(name: String, sourceURL: URL? = nil, kind: DocumentKind, pages: [DocumentPage], findings: [Finding]) {
        self.name = name; self.sourceURL = sourceURL; self.kind = kind; self.pages = pages; self.findings = findings
    }
}

public enum ShareSafeError: LocalizedError {
    case invalid(String), cancelled, preparationRequired, passwordRequired
    public var errorDescription: String? {
        switch self { case .invalid(let message): return message; case .cancelled: return "The operation was cancelled."
        case .preparationRequired: return "Create a flattened review copy to include visible forms and annotations."
        case .passwordRequired: return "Enter the PDF password to open this document." }
    }
}

public struct ExportResult: Sendable {
    public var data: Data
    public var fileExtension: String
    public var sha256: String
    public var checks: [String]
}
