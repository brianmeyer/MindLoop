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

    /// The semantic text style this typography maps to for Dynamic Type scaling
    var textStyle: Font.TextStyle {
        switch self {
        case .caption:     return .caption      // ~12pt base
        case .small:       return .subheadline   // ~14pt base
        case .body:        return .body          // ~16pt base
        case .emphasized:  return .headline      // ~18pt base
        case .subheading:  return .title3        // ~20pt base
        case .heading:     return .title2        // ~24pt base
        case .largeTitle:  return .largeTitle    // ~36pt base
        }
    }

    /// The default weight for this typography style
    var weight: Font.Weight {
        switch self {
        case .caption, .small, .body:
            return .regular
        case .emphasized:
            return .medium
        case .subheading, .heading:
            return .semibold
        case .largeTitle:
            return .bold
        }
    }

    /// Get the Font for this typography style.
    /// Uses semantic text styles so fonts scale automatically with Dynamic Type.
    var font: Font {
        Font.system(textStyle, weight: weight)
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
