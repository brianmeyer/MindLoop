//
//  Spacing.swift
//  MindLoop
//
//  Spacing system extracted from Figma Make React code
//  Source: temp-figma-code/src/index.css (--spacing: .25rem = 4px)
//

import SwiftUI

/// Spacing constants for MindLoop app
/// Base unit: 4px (matches React --spacing: .25rem)
/// All values are multiples of 4px for consistency
enum Spacing {
    /// 4px - Extra small spacing (mt-1, gap-1)
    static let xs: CGFloat = 4

    /// 8px - Small spacing (gap-2, space-y-2)
    static let s: CGFloat = 8

    /// 12px - Medium spacing (space-y-3)
    static let m: CGFloat = 12

    /// 16px - Base spacing (p-4, most common)
    static let base: CGFloat = 16

    /// 20px - Large spacing (p-5, common in screens)
    static let l: CGFloat = 20

    /// 24px - Extra large spacing (space-y-6, large gaps)
    static let xl: CGFloat = 24

    /// 32px - 2XL spacing (space-y-8, major sections)
    static let xxl: CGFloat = 32

    /// 40px - 3XL spacing (rarely used, special cases)
    static let xxxl: CGFloat = 40

    /// 48px - 4XL spacing (major dividers)
    static let xxxxl: CGFloat = 48
}

/// Corner radius constants for MindLoop app
/// Extracted from React component usage
enum CornerRadius {
    /// 8px - Small radius
    static let s: CGFloat = 8
    static let small: CGFloat = 8

    /// 12px - Default radius (standard buttons, inputs)
    static let m: CGFloat = 12
    static let medium: CGFloat = 12

    /// 16px - Large radius (waveform container)
    static let l: CGFloat = 16
    static let large: CGFloat = 16

    /// 20px - Extra large radius (large buttons, cards)
    static let xl: CGFloat = 20
    static let extraLarge: CGFloat = 20

    /// 999px - Pill shape (fully rounded ends)
    static let pill: CGFloat = 999

    /// Use `.clipShape(Circle())` for fully circular elements
}

/// Common dimensions for MindLoop app
/// Extracted from React component patterns
enum Dimensions {
    /// 40px - Circular icon button size (w-10 h-10)
    static let iconButton: CGFloat = 40

    /// 56px - Minimum height for primary buttons (min-h-[56px])
    static let primaryButtonHeight: CGFloat = 56

    /// 120px - Minimum height for text areas
    static let textAreaHeight: CGFloat = 120

    /// 390px - Maximum width for mobile screens (max-w-[390px])
    static let mobileMaxWidth: CGFloat = 390

    /// 96px - Waveform height (h-24 = 24 * 4px)
    static let waveformHeight: CGFloat = 96
}
