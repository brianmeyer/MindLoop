//
//  Typography.swift
//  MindLoop
//
//  Typography system extracted from Figma Make React code
//  Source: temp-figma-code/src/index.css
//

import SwiftUI

/// Typography scale for MindLoop app
/// Matches design tokens from React codebase with Dynamic Type support
enum Typography {
    case caption      // 12pt (--text-xs)
    case small        // 14pt (--text-sm)
    case body         // 16pt (--text-base)
    case emphasized   // 18pt (--text-lg)
    case subheading   // 20pt (--text-xl)
    case heading      // 24pt (--text-2xl)
    case largeTitle   // 36pt (--text-4xl)

    /// Get the Font for this typography style
    var font: Font {
        switch self {
        case .caption:
            return .system(size: 12, weight: .regular)
        case .small:
            return .system(size: 14, weight: .regular)
        case .body:
            return .system(size: 16, weight: .regular)
        case .emphasized:
            return .system(size: 18, weight: .medium)
        case .subheading:
            return .system(size: 20, weight: .semibold)
        case .heading:
            return .system(size: 24, weight: .semibold)
        case .largeTitle:
            return .system(size: 36, weight: .bold)
        }
    }

    /// Line height for this typography style
    /// React uses line-height: 1.5 for most text, 1.625 for relaxed
    var lineSpacing: CGFloat {
        switch self {
        case .caption, .small:
            return 4  // Tighter for small text
        case .body, .emphasized:
            return 6  // Standard (1.5 line height)
        case .subheading, .heading:
            return 4  // Tighter for headings
        case .largeTitle:
            return 2  // Minimal for large titles
        }
    }
}

/// View modifier for applying typography styles
struct TypographyModifier: ViewModifier {
    let style: Typography

    func body(content: Content) -> some View {
        content
            .font(style.font)
            .lineSpacing(style.lineSpacing)
    }
}

extension View {
    /// Apply a typography style to this view
    /// - Parameter style: The typography style to apply
    /// - Returns: Modified view with typography applied
    ///
    /// Example usage:
    /// ```swift
    /// Text("Hello World")
    ///     .typography(.heading)
    /// ```
    func typography(_ style: Typography) -> some View {
        self.modifier(TypographyModifier(style: style))
    }
}

// MARK: - Font Weight Extensions

extension Font.Weight {
    /// React font weights mapped to SwiftUI
    static let normal = Font.Weight.regular     // 400
    static let medium = Font.Weight.medium      // 500
    static let semibold = Font.Weight.semibold  // 600
}
