//
//  SafetyAgent.swift
//  MindLoop
//
//  Final safety gate: checks coach responses for crisis keywords,
//  PII patterns, medical boundary violations, substance abuse,
//  and abuse detection before delivery.
//  Source: CLAUDE.md - SafetyAgent contract
//

import Foundation
import os

// MARK: - SafetyAgent

/// Final gate for risk keywords, PII, and medical boundary violations.
///
/// The SafetyAgent is **non-overridable**: no other agent (including
/// LearningLoopAgent or personalization) may bypass a `.block` decision.
struct SafetyAgent: AgentProtocol, Sendable {

    private static let logger = Logger(
        subsystem: "com.lycan.MindLoop",
        category: "SafetyAgent"
    )

    // MARK: - AgentProtocol

    typealias Input = String
    typealias Output = SafetyGateResult

    var name: String { "SafetyAgent" }

    /// Satisfy `AgentProtocol.process(_:)` by delegating to the convenience method.
    func process(_ input: String) async throws -> SafetyGateResult {
        gate(input)
    }

    // MARK: - Crisis Keywords (embedded for v1)

    /// Crisis keyword categories keyed by risk type
    static let crisisKeywords: [String: [String]] = [
        "suicide": [
            "kill myself",
            "end it all",
            "ending it all",
            "not worth living",
            "suicide",
            "suicidal",
            "want to die",
            "better off dead",
        ],
        "self_harm": [
            "cut myself",
            "hurt myself",
            "self-harm",
            "self harm",
            "burn myself",
            "starve myself",
        ],
        "crisis": [
            "can't go on",
            "no way out",
            "no reason to live",
            "give up",
            "can't take it anymore",
        ],
    ]

    /// Substance abuse keywords that require context-aware matching
    static let substanceAbuseKeywords: [String] = [
        "can't stop drinking",
        "overdose",
        "need to get high",
        "withdrawal symptoms",
        "addicted to",
    ]

    /// Abuse keywords that trigger DV-specific crisis resources
    static let abuseKeywords: [String] = [
        "he hits me",
        "she hits me",
        "afraid to go home",
        "being abused",
        "hurting me",
        "domestic violence",
    ]

    /// Phrases that look like crisis keywords but are benign (false positives).
    /// Checked before crisis keyword matching to prevent incorrect blocks.
    static let falsePositivePhrases: [String] = [
        "killing it",
        "i'm dying laughing",
        "dying laughing",
        "dying of laughter",
        "to die for",
        "drop dead gorgeous",
        "dressed to kill",
        "kill the lights",
        "kill two birds",
        "killing time",
        "killed it",
        "suicide squad",
        "suicide doors",
        "don't give up",
        "never give up",
        "not ready to give up",
        "won't give up",
        "refuse to give up",
    ]

    /// Phrases that look like substance abuse but are benign
    static let substanceFalsePositives: [String] = [
        "had a drink",
        "have a drink",
        "grab a drink",
        "went for drinks",
        "drinks with",
        "a drink with",
        "social drinking",
        "stop drinking coffee",
        "stop drinking soda",
        "stop drinking caffeine",
    ]

    /// Phrases that look like abuse keywords but are benign
    static let abuseFalsePositives: [String] = [
        "hits the gym",
        "hits the road",
        "hits the books",
        "hits the mark",
        "hits the spot",
        "hits the ball",
        "hits the target",
        "hits the nail",
        "hits different",
        "hits home",
    ]

    // MARK: - Medical Boundary Patterns

    /// Phrases indicating the response attempts to diagnose or prescribe
    static let medicalBoundaryPhrases: [String] = [
        "you have depression",
        "you have anxiety",
        "you have ptsd",
        "you have bipolar",
        "you have adhd",
        "you have",
        "you might have",
        "you may have",
        "you probably have",
        "you could have",
        "diagnosed with",
        "diagnosis of",
        "you are suffering from",
        "you suffer from",
        "you should take",
        "i diagnose",
        "your diagnosis is",
        "prescribe",
        "you need medication",
        "medication",
        "take pills",
    ]

    /// Phrases that look medical but are acceptable in a coaching context
    static let medicalFalsePositives: [String] = [
        "you have the strength",
        "you have the ability",
        "you have been through",
        "you have done",
        "you have made",
        "you have shown",
        "you have taken",
        "you have come",
        "you have every right",
        "you have a lot",
        "you have so much",
        "you have what it takes",
        "i feel depressed",
        "feeling depressed",
        "i'm depressed",
        "i am depressed",
        "feel anxious",
        "feeling anxious",
    ]

    // MARK: - PII Regex Patterns (Swift Regex)

    /// Email address pattern
    static let emailRegex = /\S+@\S+\.\S+/

    /// US phone number pattern (e.g., 555-123-4567, 555.123.4567, 555 123 4567)
    static let phoneRegex = /\d{3}[-.\s]?\d{3}[-.\s]?\d{4}/

    /// SSN pattern (e.g., 123-45-6789)
    static let ssnRegex = /\d{3}-\d{2}-\d{4}/

    /// Credit card pattern (13-19 consecutive digits, optionally separated by spaces or dashes)
    static let creditCardRegex = /\d{4}[-\s]?\d{4}[-\s]?\d{4}[-\s]?\d{1,7}/

    // MARK: - De-escalation Responses

    /// Templated de-escalation response shown when a crisis keyword is detected
    static let deescalationResponse: String = """
        I hear that you're going through a really tough time. While I'm here \
        to support your reflection, I'm not equipped for crisis situations.

        Please reach out to someone who can help right now:

        National Suicide Prevention Lifeline: 988
        Crisis Text Line: Text HOME to 741741
        International: findahelpline.com

        You don't have to go through this alone.
        """

    /// De-escalation response for abuse/domestic violence situations
    static let abuseDeescalationResponse: String = """
        I hear you, and I want you to know that what you're describing \
        is not okay. You deserve to be safe.

        Please reach out to someone who can help right now:

        National Domestic Violence Hotline: 1-800-799-7233
        Text START to 88788
        National Suicide Prevention Lifeline: 988
        Crisis Text Line: Text HOME to 741741
        International: findahelpline.com

        You don't have to go through this alone.
        """

    /// De-escalation response for substance abuse crisis
    static let substanceAbuseDeescalationResponse: String = """
        I hear that you're going through a really tough time. While I'm here \
        to support your reflection, I'm not equipped for crisis situations.

        Please reach out to someone who can help right now:

        SAMHSA National Helpline: 1-800-662-4357
        National Suicide Prevention Lifeline: 988
        Crisis Text Line: Text HOME to 741741
        International: findahelpline.com

        You don't have to go through this alone.
        """

    /// Medical boundary block message
    static let medicalBoundaryResponse: String =
        "I can't provide medical advice. Please consult a licensed professional."

    // MARK: - Gate Method

    /// Check a candidate response text for safety violations.
    ///
    /// - Parameter text: The candidate response text to evaluate.
    /// - Returns: `.allow` if the text passes all checks, or `.block(reason:)` with
    ///   a description of the violation.
    func gate(_ text: String) -> SafetyGateResult {
        let lowered = text.lowercased()

        // 1. Check for PII first (most concrete patterns)
        if let piiReason = checkPII(text) {
            Self.logger.info("Safety gate blocked: \(piiReason, privacy: .public)")
            return .block(reason: piiReason)
        }

        // 2. Check crisis keywords (after removing false positive phrases)
        if let crisisReason = checkCrisisKeywords(lowered) {
            Self.logger.info("Safety gate blocked: \(crisisReason, privacy: .public)")
            return .block(reason: crisisReason)
        }

        // 3. Check abuse keywords
        if let abuseReason = checkAbuseKeywords(lowered) {
            Self.logger.info("Safety gate blocked: \(abuseReason, privacy: .public)")
            return .block(reason: abuseReason)
        }

        // 4. Check substance abuse keywords (context-aware)
        if let substanceReason = checkSubstanceAbuse(lowered) {
            Self.logger.info("Safety gate blocked: \(substanceReason, privacy: .public)")
            return .block(reason: substanceReason)
        }

        // 5. Check medical boundary
        if let medicalReason = checkMedicalBoundary(lowered) {
            Self.logger.info("Safety gate blocked: \(medicalReason, privacy: .public)")
            return .block(reason: medicalReason)
        }

        return .allow
    }

    // MARK: - Private Checks

    /// Check for PII patterns (email, phone, SSN, credit card)
    private func checkPII(_ text: String) -> String? {
        if text.firstMatch(of: Self.emailRegex) != nil {
            return "pii_email"
        }

        // Check credit cards before phone numbers -- a 16-digit card number
        // contains substrings that match the 10-digit phone pattern
        if text.firstMatch(of: Self.creditCardRegex) != nil {
            return "pii_credit_card"
        }

        // For phone numbers, exclude known safe numbers (crisis lines)
        let safeNumbers = ["741741", "988", "8007997233", "8006624357", "88788"]
        var searchText = text
        while let match = searchText.firstMatch(of: Self.phoneRegex) {
            let matched = String(searchText[match.range])
            let digitsOnly = matched.filter(\.isNumber)
            let isSafe = safeNumbers.contains(where: { digitsOnly.contains($0) })
            if !isSafe {
                return "pii_phone"
            }
            // Move past this match
            if let afterIndex = searchText.index(
                match.range.upperBound,
                offsetBy: 0,
                limitedBy: searchText.endIndex
            ) {
                searchText = String(searchText[afterIndex...])
            } else {
                break
            }
        }

        if text.firstMatch(of: Self.ssnRegex) != nil {
            return "pii_ssn"
        }

        return nil
    }

    /// Check for crisis keywords, accounting for false positives
    private func checkCrisisKeywords(_ lowered: String) -> String? {
        // Build a "sanitized" version where false-positive phrases are masked out
        var sanitized = lowered
        for phrase in Self.falsePositivePhrases {
            sanitized = sanitized.replacingOccurrences(
                of: phrase,
                with: String(repeating: " ", count: phrase.count)
            )
        }

        for (category, keywords) in Self.crisisKeywords {
            for keyword in keywords {
                if sanitized.contains(keyword) {
                    return "safety_block_\(category)"
                }
            }
        }

        return nil
    }

    /// Check for abuse keywords, accounting for false positives (e.g., "hits the gym")
    private func checkAbuseKeywords(_ lowered: String) -> String? {
        var sanitized = lowered
        for phrase in Self.abuseFalsePositives {
            sanitized = sanitized.replacingOccurrences(
                of: phrase,
                with: String(repeating: " ", count: phrase.count)
            )
        }

        for keyword in Self.abuseKeywords {
            if sanitized.contains(keyword) {
                return "safety_block_abuse"
            }
        }

        return nil
    }

    /// Check for substance abuse keywords with context-aware matching.
    ///
    /// Casual mentions like "had a drink with friends" are allowed,
    /// while active crisis language like "can't stop drinking every night" is blocked.
    private func checkSubstanceAbuse(_ lowered: String) -> String? {
        // Mask out false-positive substance phrases before checking
        var sanitized = lowered
        for phrase in Self.substanceFalsePositives {
            sanitized = sanitized.replacingOccurrences(
                of: phrase,
                with: String(repeating: " ", count: phrase.count)
            )
        }

        for keyword in Self.substanceAbuseKeywords {
            if sanitized.contains(keyword) {
                return "safety_block_substance_abuse"
            }
        }

        return nil
    }

    /// Check for medical boundary violations
    private func checkMedicalBoundary(_ lowered: String) -> String? {
        // Mask out false-positive medical phrases before checking
        var sanitized = lowered
        for phrase in Self.medicalFalsePositives {
            sanitized = sanitized.replacingOccurrences(
                of: phrase,
                with: String(repeating: " ", count: phrase.count)
            )
        }

        for phrase in Self.medicalBoundaryPhrases {
            if sanitized.contains(phrase) {
                return "medical_boundary"
            }
        }

        return nil
    }
}
