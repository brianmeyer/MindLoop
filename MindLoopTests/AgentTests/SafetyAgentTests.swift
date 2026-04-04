//
//  SafetyAgentTests.swift
//  MindLoopTests
//
//  Comprehensive tests for SafetyAgent: crisis keywords, PII detection,
//  medical boundary, false positives, and de-escalation response.
//

import Testing
import Foundation
@testable import MindLoop

@Suite("SafetyAgent Tests")
struct SafetyAgentTests {

    let agent = SafetyAgent()

    // MARK: - Crisis Keyword Detection

    @Suite("Crisis Keyword Detection")
    struct CrisisKeywords {
        let agent = SafetyAgent()

        @Test("Blocks suicide keyword: kill myself")
        func testKillMyself() {
            let result = agent.gate("I want to kill myself")
            #expect(result == .block(reason: "safety_block_suicide"))
        }

        @Test("Blocks suicide keyword: end it all")
        func testEndItAll() {
            let result = agent.gate("I'm thinking about ending it all")
            #expect(result == .block(reason: "safety_block_suicide"))
        }

        @Test("Blocks suicide keyword: not worth living")
        func testNotWorthLiving() {
            let result = agent.gate("Life is not worth living anymore")
            #expect(result == .block(reason: "safety_block_suicide"))
        }

        @Test("Blocks suicide keyword: suicide")
        func testSuicide() {
            let result = agent.gate("I've been thinking about suicide")
            #expect(result == .block(reason: "safety_block_suicide"))
        }

        @Test("Blocks suicide keyword: suicidal")
        func testSuicidal() {
            let result = agent.gate("I feel suicidal today")
            #expect(result == .block(reason: "safety_block_suicide"))
        }

        @Test("Blocks self-harm keyword: cut myself")
        func testCutMyself() {
            let result = agent.gate("I want to cut myself")
            #expect(result == .block(reason: "safety_block_self_harm"))
        }

        @Test("Blocks self-harm keyword: hurt myself")
        func testHurtMyself() {
            let result = agent.gate("I keep wanting to hurt myself")
            #expect(result == .block(reason: "safety_block_self_harm"))
        }

        @Test("Blocks self-harm keyword: self-harm (hyphenated)")
        func testSelfHarmHyphen() {
            let result = agent.gate("I have a history of self-harm")
            #expect(result == .block(reason: "safety_block_self_harm"))
        }

        @Test("Blocks self-harm keyword: self harm (no hyphen)")
        func testSelfHarmNoHyphen() {
            let result = agent.gate("Self harm is something I struggle with")
            #expect(result == .block(reason: "safety_block_self_harm"))
        }

        @Test("Blocks crisis keyword: can't go on")
        func testCantGoOn() {
            let result = agent.gate("I can't go on like this")
            #expect(result == .block(reason: "safety_block_crisis"))
        }

        @Test("Blocks crisis keyword: no way out")
        func testNoWayOut() {
            let result = agent.gate("There's no way out of this situation")
            #expect(result == .block(reason: "safety_block_crisis"))
        }

        @Test("Blocks crisis keyword: no reason to live")
        func testNoReasonToLive() {
            let result = agent.gate("I have no reason to live")
            #expect(result == .block(reason: "safety_block_crisis"))
        }

        @Test("Case-insensitive detection")
        func testCaseInsensitive() {
            let result = agent.gate("I want to KILL MYSELF")
            #expect(result == .block(reason: "safety_block_suicide"))
        }

        @Test("Mixed case detection")
        func testMixedCase() {
            let result = agent.gate("Suicide is on my mind")
            #expect(result == .block(reason: "safety_block_suicide"))
        }
    }

    // MARK: - False Positive Handling

    @Suite("False Positive Handling")
    struct FalsePositives {
        let agent = SafetyAgent()

        @Test("Allows: killing it at work")
        func testKillingItAtWork() {
            let result = agent.gate("You're really killing it at work lately!")
            #expect(result == .allow)
        }

        @Test("Allows: I'm dying laughing")
        func testDyingLaughing() {
            let result = agent.gate("I'm dying laughing at that story")
            #expect(result == .allow)
        }

        @Test("Allows: to die for")
        func testToDieFor() {
            let result = agent.gate("That dessert was to die for")
            #expect(result == .allow)
        }

        @Test("Allows: killing time")
        func testKillingTime() {
            let result = agent.gate("I was just killing time before the meeting")
            #expect(result == .allow)
        }

        @Test("Allows: killed it")
        func testKilledIt() {
            let result = agent.gate("You killed it in your presentation!")
            #expect(result == .allow)
        }

        @Test("Allows: drop dead gorgeous")
        func testDropDeadGorgeous() {
            let result = agent.gate("She looked drop dead gorgeous")
            #expect(result == .allow)
        }

        @Test("Allows safe coaching text")
        func testSafeCoachingText() {
            let result = agent.gate(
                "I hear that you're feeling stressed about the presentation. "
                + "Let's take a moment to reframe this thought. What evidence "
                + "supports a more balanced view?"
            )
            #expect(result == .allow)
        }

        @Test("Allows normal journal reflection")
        func testNormalReflection() {
            let result = agent.gate(
                "It sounds like today was challenging. You mentioned feeling "
                + "overwhelmed at work. What's one tiny step you could take "
                + "to make tomorrow a bit easier?"
            )
            #expect(result == .allow)
        }
    }

    // MARK: - PII Detection

    @Suite("PII Detection")
    struct PIIDetection {
        let agent = SafetyAgent()

        @Test("Blocks email addresses")
        func testEmail() {
            let result = agent.gate("You can reach me at user@example.com for more info")
            #expect(result == .block(reason: "pii_email"))
        }

        @Test("Blocks email with subdomain")
        func testEmailSubdomain() {
            let result = agent.gate("Contact john.doe@mail.company.co.uk")
            #expect(result == .block(reason: "pii_email"))
        }

        @Test("Blocks phone numbers with dashes")
        func testPhoneDashes() {
            let result = agent.gate("Call me at 555-123-4567")
            #expect(result == .block(reason: "pii_phone"))
        }

        @Test("Blocks phone numbers with dots")
        func testPhoneDots() {
            let result = agent.gate("My number is 555.123.4567")
            #expect(result == .block(reason: "pii_phone"))
        }

        @Test("Blocks phone numbers with spaces")
        func testPhoneSpaces() {
            let result = agent.gate("Reach me at 555 123 4567")
            #expect(result == .block(reason: "pii_phone"))
        }

        @Test("Blocks phone numbers without separators")
        func testPhoneNoSeparators() {
            let result = agent.gate("My number is 5551234567")
            #expect(result == .block(reason: "pii_phone"))
        }

        @Test("Blocks SSN pattern")
        func testSSN() {
            let result = agent.gate("My SSN is 123-45-6789")
            #expect(result == .block(reason: "pii_ssn"))
        }

        @Test("Blocks credit card numbers with dashes")
        func testCreditCardDashes() {
            let result = agent.gate("My card is 4111-1111-1111-1111")
            #expect(result == .block(reason: "pii_credit_card"))
        }

        @Test("Blocks credit card numbers with spaces")
        func testCreditCardSpaces() {
            let result = agent.gate("Card number 4111 1111 1111 1111")
            #expect(result == .block(reason: "pii_credit_card"))
        }

        @Test("Blocks credit card numbers without separators")
        func testCreditCardNoSeparators() {
            let result = agent.gate("My card number is 4111111111111111")
            #expect(result == .block(reason: "pii_credit_card"))
        }

        @Test("Allows crisis hotline number 741741")
        func testCrisisTextLine() {
            // The de-escalation response itself contains crisis numbers;
            // those must not be blocked as PII.
            let result = agent.gate("Text HOME to 741741 for help")
            #expect(result == .allow)
        }
    }

    // MARK: - Medical Boundary

    @Suite("Medical Boundary Detection")
    struct MedicalBoundary {
        let agent = SafetyAgent()

        @Test("Blocks: you have depression")
        func testYouHave() {
            let result = agent.gate("It sounds like you have depression")
            #expect(result == .block(reason: "medical_boundary"))
        }

        @Test("Blocks: you might have anxiety disorder")
        func testYouMightHave() {
            let result = agent.gate("You might have an anxiety disorder")
            #expect(result == .block(reason: "medical_boundary"))
        }

        @Test("Blocks: diagnosed with PTSD")
        func testDiagnosedWith() {
            let result = agent.gate("You should get diagnosed with a professional about PTSD")
            #expect(result == .block(reason: "medical_boundary"))
        }

        @Test("Blocks: medication suggestion")
        func testMedication() {
            let result = agent.gate("You should consider medication for this")
            #expect(result == .block(reason: "medical_boundary"))
        }

        @Test("Allows: you have the strength")
        func testYouHaveStrength() {
            let result = agent.gate("You have the strength to get through this")
            #expect(result == .allow)
        }

        @Test("Allows: you have been through a lot")
        func testYouHaveBeenThrough() {
            let result = agent.gate("You have been through a lot and shown real resilience")
            #expect(result == .allow)
        }

        @Test("Allows: you have shown courage")
        func testYouHaveShown() {
            let result = agent.gate("You have shown so much courage this week")
            #expect(result == .allow)
        }

        @Test("Allows: you have every right to feel this way")
        func testYouHaveEveryRight() {
            let result = agent.gate("You have every right to feel frustrated about this")
            #expect(result == .allow)
        }

        @Test("Allows: you have what it takes")
        func testYouHaveWhatItTakes() {
            let result = agent.gate("You have what it takes to handle this challenge")
            #expect(result == .allow)
        }
    }

    // MARK: - De-escalation Response

    @Suite("De-escalation Response")
    struct DeescalationResponse {

        @Test("Contains 988 lifeline number")
        func testContains988() {
            #expect(SafetyAgent.deescalationResponse.contains("988"))
        }

        @Test("Contains Crisis Text Line 741741")
        func testContains741741() {
            #expect(SafetyAgent.deescalationResponse.contains("741741"))
        }

        @Test("Contains findahelpline.com")
        func testContainsFindAHelpline() {
            #expect(SafetyAgent.deescalationResponse.contains("findahelpline.com"))
        }

        @Test("Contains empathetic opening")
        func testEmpatheticTone() {
            #expect(SafetyAgent.deescalationResponse.contains("tough time"))
        }

        @Test("Contains reassurance")
        func testReassurance() {
            #expect(SafetyAgent.deescalationResponse.contains("You don't have to go through this alone"))
        }
    }

    // MARK: - SafetyGateResult

    @Suite("SafetyGateResult")
    struct GateResultTests {

        @Test("allow is not blocked")
        func testAllowNotBlocked() {
            let result = SafetyGateResult.allow
            #expect(!result.isBlocked)
        }

        @Test("block is blocked")
        func testBlockIsBlocked() {
            let result = SafetyGateResult.block(reason: "test")
            #expect(result.isBlocked)
        }

        @Test("allow equals allow")
        func testAllowEquality() {
            #expect(SafetyGateResult.allow == SafetyGateResult.allow)
        }

        @Test("block equals block with same reason")
        func testBlockEquality() {
            #expect(
                SafetyGateResult.block(reason: "x") == SafetyGateResult.block(reason: "x")
            )
        }

        @Test("block does not equal block with different reason")
        func testBlockInequality() {
            #expect(
                SafetyGateResult.block(reason: "x") != SafetyGateResult.block(reason: "y")
            )
        }
    }

    // MARK: - Edge Cases

    @Suite("Edge Cases")
    struct EdgeCases {
        let agent = SafetyAgent()

        @Test("Empty string is allowed")
        func testEmptyString() {
            let result = agent.gate("")
            #expect(result == .allow)
        }

        @Test("Whitespace-only string is allowed")
        func testWhitespace() {
            let result = agent.gate("   \n\t  ")
            #expect(result == .allow)
        }

        @Test("Very long safe text is allowed")
        func testLongSafeText() {
            let longText = String(repeating: "This is a safe reflection. ", count: 100)
            let result = agent.gate(longText)
            #expect(result == .allow)
        }

        @Test("Medical boundary response is not empty")
        func testMedicalBoundaryResponseNotEmpty() {
            #expect(!SafetyAgent.medicalBoundaryResponse.isEmpty)
            #expect(SafetyAgent.medicalBoundaryResponse.contains("medical advice"))
        }

        @Test("PII takes priority over crisis keywords")
        func testPIIPriority() {
            // Text contains both PII and a crisis keyword
            let result = agent.gate("I want to kill myself, email me at help@test.com")
            #expect(result == .block(reason: "pii_email"))
        }

        @Test("Crisis keyword embedded in longer word is still caught")
        func testSubstringMatch() {
            let result = agent.gate("Feeling suicidal thoughts today")
            #expect(result == .block(reason: "safety_block_suicide"))
        }
    }
}
