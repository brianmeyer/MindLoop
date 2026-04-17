//
//  SafetyAgentTests.swift
//  MindLoopTests
//
//  Comprehensive tests for SafetyAgent: crisis keywords, PII detection,
//  medical boundary, substance abuse, abuse detection, false positives,
//  and de-escalation response.
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

        @Test("Blocks suicide keyword: want to die")
        func testWantToDie() {
            let result = agent.gate("I just want to die")
            #expect(result == .block(reason: "safety_block_suicide"))
        }

        @Test("Blocks suicide keyword: better off dead")
        func testBetterOffDead() {
            let result = agent.gate("Everyone would be better off dead without me")
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

        @Test("Blocks self-harm keyword: burn myself")
        func testBurnMyself() {
            let result = agent.gate("I want to burn myself")
            #expect(result == .block(reason: "safety_block_self_harm"))
        }

        @Test("Blocks self-harm keyword: starve myself")
        func testStarveMyself() {
            let result = agent.gate("I'm going to starve myself")
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

        @Test("Blocks crisis keyword: give up")
        func testGiveUp() {
            let result = agent.gate("I just want to give up on everything")
            #expect(result == .block(reason: "safety_block_crisis"))
        }

        @Test("Blocks crisis keyword: can't take it anymore")
        func testCantTakeItAnymore() {
            let result = agent.gate("I can't take it anymore")
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

        @Test("Blocks: you should take medication")
        func testYouShouldTake() {
            let result = agent.gate("You should take antidepressants")
            #expect(result == .block(reason: "medical_boundary"))
        }

        @Test("Blocks: I diagnose")
        func testIDiagnose() {
            let result = agent.gate("I diagnose you with generalized anxiety")
            #expect(result == .block(reason: "medical_boundary"))
        }

        @Test("Blocks: your diagnosis is")
        func testYourDiagnosisIs() {
            let result = agent.gate("Your diagnosis is clinical depression")
            #expect(result == .block(reason: "medical_boundary"))
        }

        @Test("Blocks: you need medication")
        func testYouNeedMedication() {
            let result = agent.gate("You need medication to manage this")
            #expect(result == .block(reason: "medical_boundary"))
        }

        @Test("Allows: I feel depressed (user expression, not diagnosis)")
        func testIFeelDepressed() {
            let result = agent.gate("I feel depressed today and don't know why")
            #expect(result == .allow)
        }

        @Test("Allows: feeling depressed")
        func testFeelingDepressed() {
            let result = agent.gate("I've been feeling depressed lately")
            #expect(result == .allow)
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

    // MARK: - Substance Abuse Detection

    @Suite("Substance Abuse Detection")
    struct SubstanceAbuse {
        let agent = SafetyAgent()

        @Test("Blocks: can't stop drinking")
        func testCantStopDrinking() {
            let result = agent.gate("I can't stop drinking every night")
            #expect(result == .block(reason: "safety_block_substance_abuse"))
        }

        @Test("Blocks: overdose")
        func testOverdose() {
            let result = agent.gate("I think I might overdose")
            #expect(result == .block(reason: "safety_block_substance_abuse"))
        }

        @Test("Blocks: need to get high")
        func testNeedToGetHigh() {
            let result = agent.gate("I just need to get high to feel better")
            #expect(result == .block(reason: "safety_block_substance_abuse"))
        }

        @Test("Blocks: withdrawal symptoms")
        func testWithdrawalSymptoms() {
            let result = agent.gate("I'm having withdrawal symptoms")
            #expect(result == .block(reason: "safety_block_substance_abuse"))
        }

        @Test("Blocks: addicted to")
        func testAddictedTo() {
            let result = agent.gate("I'm addicted to painkillers")
            #expect(result == .block(reason: "safety_block_substance_abuse"))
        }

        @Test("Allows: I had a drink with friends (false positive)")
        func testHadADrinkWithFriends() {
            let result = agent.gate("I had a drink with friends last night")
            #expect(result == .allow)
        }

        @Test("Allows: went for drinks with coworkers")
        func testWentForDrinks() {
            let result = agent.gate("We went for drinks with coworkers after work")
            #expect(result == .allow)
        }

        @Test("Allows: social drinking mention")
        func testSocialDrinking() {
            let result = agent.gate("I enjoy social drinking occasionally")
            #expect(result == .allow)
        }
    }

    // MARK: - Abuse Detection

    @Suite("Abuse Detection")
    struct AbuseDetection {
        let agent = SafetyAgent()

        @Test("Blocks: he hits me")
        func testHeHitsMe() {
            let result = agent.gate("He hits me when he's angry")
            #expect(result == .block(reason: "safety_block_abuse"))
        }

        @Test("Blocks: she hits me")
        func testSheHitsMe() {
            let result = agent.gate("She hits me all the time")
            #expect(result == .block(reason: "safety_block_abuse"))
        }

        @Test("Blocks: afraid to go home")
        func testAfraidToGoHome() {
            let result = agent.gate("I'm afraid to go home tonight")
            #expect(result == .block(reason: "safety_block_abuse"))
        }

        @Test("Blocks: being abused")
        func testBeingAbused() {
            let result = agent.gate("I think I'm being abused")
            #expect(result == .block(reason: "safety_block_abuse"))
        }

        @Test("Blocks: hurting me")
        func testHurtingMe() {
            let result = agent.gate("My partner keeps hurting me")
            #expect(result == .block(reason: "safety_block_abuse"))
        }

        @Test("Blocks: domestic violence")
        func testDomesticViolence() {
            let result = agent.gate("I'm in a domestic violence situation")
            #expect(result == .block(reason: "safety_block_abuse"))
        }

        @Test("Allows: my brother hits the gym (false positive)")
        func testHitsTheGym() {
            let result = agent.gate("My brother hits the gym every morning")
            #expect(result == .allow)
        }

        @Test("Allows: she hits the books")
        func testHitsTheBooks() {
            let result = agent.gate("She really hits the books before exams")
            #expect(result == .allow)
        }

        @Test("Allows: hits different")
        func testHitsDifferent() {
            let result = agent.gate("Coffee in the morning just hits different")
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

    // MARK: - Abuse De-escalation Response

    @Suite("Abuse De-escalation Response")
    struct AbuseDeescalationResponseTests {

        @Test("Contains DV hotline number 1-800-799-7233")
        func testContainsDVHotline() {
            #expect(SafetyAgent.abuseDeescalationResponse.contains("1-800-799-7233"))
        }

        @Test("Contains text START to 88788")
        func testContainsTextSTART() {
            #expect(SafetyAgent.abuseDeescalationResponse.contains("START"))
            #expect(SafetyAgent.abuseDeescalationResponse.contains("88788"))
        }

        @Test("Contains 988 lifeline")
        func testContains988() {
            #expect(SafetyAgent.abuseDeescalationResponse.contains("988"))
        }

        @Test("Contains findahelpline.com")
        func testContainsFindAHelpline() {
            #expect(SafetyAgent.abuseDeescalationResponse.contains("findahelpline.com"))
        }

        @Test("Contains empathetic safety message")
        func testContainsSafetyMessage() {
            #expect(SafetyAgent.abuseDeescalationResponse.contains("deserve to be safe"))
        }

        @Test("Contains reassurance")
        func testReassurance() {
            #expect(SafetyAgent.abuseDeescalationResponse.contains("You don't have to go through this alone"))
        }
    }

    // MARK: - Substance Abuse De-escalation Response

    @Suite("Substance Abuse De-escalation Response")
    struct SubstanceAbuseDeescalationResponseTests {

        @Test("Contains SAMHSA helpline")
        func testContainsSAMHSA() {
            #expect(SafetyAgent.substanceAbuseDeescalationResponse.contains("SAMHSA"))
            #expect(SafetyAgent.substanceAbuseDeescalationResponse.contains("1-800-662-4357"))
        }

        @Test("Contains 988 lifeline")
        func testContains988() {
            #expect(SafetyAgent.substanceAbuseDeescalationResponse.contains("988"))
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

    // MARK: - JSON Keyword Loading (REC-309)

    /// Verify that SafetyAgent loads its risk keyword lists from
    /// `Resources/Prompts/safety_keywords.json` rather than a hardcoded
    /// Swift array. These assertions ensure the bundle resource is present
    /// and decoded into the expected schema.
    @Suite("JSON Keyword Loading")
    struct JSONKeywordLoading {

        @Test("Loads suicide keywords from JSON bundle")
        func testSuicideKeywordsFromJSON() throws {
            let loaded = try Self.loadBundleKeywords()
            let suicideJSON = try #require(loaded["suicide"])
            #expect(!suicideJSON.isEmpty)
            #expect(SafetyAgent.crisisKeywords["suicide"] == suicideJSON)
            // Spot-check a known keyword
            #expect(suicideJSON.contains("kill myself"))
        }

        @Test("Loads self_harm keywords from JSON bundle")
        func testSelfHarmKeywordsFromJSON() throws {
            let loaded = try Self.loadBundleKeywords()
            let selfHarmJSON = try #require(loaded["self_harm"])
            #expect(!selfHarmJSON.isEmpty)
            #expect(SafetyAgent.crisisKeywords["self_harm"] == selfHarmJSON)
            #expect(selfHarmJSON.contains("cut myself"))
        }

        @Test("Loads crisis keywords from JSON bundle")
        func testCrisisKeywordsFromJSON() throws {
            let loaded = try Self.loadBundleKeywords()
            let crisisJSON = try #require(loaded["crisis"])
            #expect(!crisisJSON.isEmpty)
            #expect(SafetyAgent.crisisKeywords["crisis"] == crisisJSON)
            #expect(crisisJSON.contains("no way out"))
        }

        @Test("Loads medical keywords from JSON bundle")
        func testMedicalKeywordsFromJSON() throws {
            let loaded = try Self.loadBundleKeywords()
            let medicalJSON = try #require(loaded["medical"])
            #expect(!medicalJSON.isEmpty)
            #expect(SafetyAgent.crisisKeywords["medical"] == medicalJSON)
        }

        @Test("Loads substance_abuse keywords from JSON bundle")
        func testSubstanceAbuseKeywordsFromJSON() throws {
            let loaded = try Self.loadBundleKeywords()
            let substanceJSON = try #require(loaded["substance_abuse"])
            #expect(!substanceJSON.isEmpty)
            #expect(SafetyAgent.substanceAbuseKeywords == substanceJSON)
            #expect(substanceJSON.contains("overdose"))
        }

        @Test("Loads abuse keywords from JSON bundle")
        func testAbuseKeywordsFromJSON() throws {
            let loaded = try Self.loadBundleKeywords()
            let abuseJSON = try #require(loaded["abuse"])
            #expect(!abuseJSON.isEmpty)
            #expect(SafetyAgent.abuseKeywords == abuseJSON)
            #expect(abuseJSON.contains("domestic violence"))
        }

        @Test("Detects a keyword that exists only in the JSON file")
        func testDetectionUsesJSONContent() throws {
            // Pick one keyword from each category as loaded from disk and
            // assert SafetyAgent blocks text containing it. This guards
            // against regressions where Swift statics drift from the JSON.
            let loaded = try Self.loadBundleKeywords()
            let agent = SafetyAgent()

            if let keyword = loaded["suicide"]?.first {
                let result = agent.gate("Sentence containing \(keyword) for testing")
                #expect(result == .block(reason: "safety_block_suicide"))
            }
            if let keyword = loaded["self_harm"]?.first {
                let result = agent.gate("A note that includes \(keyword) here")
                #expect(result == .block(reason: "safety_block_self_harm"))
            }
            if let keyword = loaded["crisis"]?.first {
                let result = agent.gate("Today feels like \(keyword) honestly")
                #expect(result == .block(reason: "safety_block_crisis"))
            }
            if let keyword = loaded["substance_abuse"]?.first {
                let result = agent.gate("I worry about \(keyword) lately")
                #expect(result == .block(reason: "safety_block_substance_abuse"))
            }
            if let keyword = loaded["abuse"]?.first {
                let result = agent.gate("Context: \(keyword) is happening")
                #expect(result == .block(reason: "safety_block_abuse"))
            }
        }

        /// Load the JSON file the same way SafetyAgent does (via `Bundle.main`
        /// inside the test host). Mirrors `SafetyAgent.KeywordStore.loadKeywords`.
        static func loadBundleKeywords() throws -> [String: [String]] {
            // The test bundle embeds the app target's resources. Prefer
            // `Bundle.main` (app bundle at runtime) and fall back to the test
            // bundle when running with a test host.
            let candidates: [Bundle] = [.main] + Bundle.allBundles
            for bundle in candidates {
                if let url = bundle.url(
                    forResource: "safety_keywords",
                    withExtension: "json"
                ) {
                    let data = try Data(contentsOf: url)
                    return try JSONDecoder().decode([String: [String]].self, from: data)
                }
            }
            Issue.record("safety_keywords.json not found in any loaded bundle")
            return [:]
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

        @Test("Abuse de-escalation response does not trigger PII")
        func testAbuseResponseNoPII() {
            // The abuse de-escalation response contains phone numbers that
            // should be treated as safe crisis hotline numbers, not PII
            let result = agent.gate(SafetyAgent.abuseDeescalationResponse)
            // The response contains "deserve to be safe" not crisis keywords,
            // so it should pass through (or at least not block on PII)
            #expect(result != .block(reason: "pii_phone"))
        }
    }
}
