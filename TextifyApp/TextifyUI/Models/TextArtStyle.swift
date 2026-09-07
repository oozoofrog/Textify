import Foundation
import TextifyKit

/// Curated starting points; individual options remain editable afterward.
public enum TextArtStyle: String, CaseIterable, Identifiable, Sendable {
    case classic, crisp, blocks, compact

    public var id: Self { self }

    public var title: String {
        switch self {
        case .classic: "클래식"
        case .crisp: "선명하게"
        case .blocks: "블록"
        case .compact: "간결하게"
        }
    }

    public var subtitle: String {
        switch self {
        case .classic: "균형 잡힌 기본"
        case .crisp: "디테일을 또렷하게"
        case .blocks: "면으로 채운 그림"
        case .compact: "짧게 나누는 그림"
        }
    }

    public var characterPreview: String {
        switch self {
        case .classic: "@#:"
        case .crisp: "$W#"
        case .blocks: "█▒░"
        case .compact: "@. "
        }
    }

    var palette: PalettePreset {
        switch self {
        case .classic: .standard
        case .crisp: .dense
        case .blocks: .blocks
        case .compact: .minimal
        }
    }

    var options: ProcessingOptions {
        switch self {
        case .classic: ProcessingOptions()
        case .crisp: ProcessingOptions(outputWidth: 100, contrastBoost: 1.5)
        case .blocks: ProcessingOptions(outputWidth: 80, contrastBoost: 1.2)
        case .compact: ProcessingOptions(outputWidth: 40, contrastBoost: 1.1)
        }
    }
}
