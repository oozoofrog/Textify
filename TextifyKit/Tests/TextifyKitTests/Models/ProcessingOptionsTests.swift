import Testing
@testable import TextifyKit

@Suite("ProcessingOptions Tests")
struct ProcessingOptionsTests {

    @Test("Default values are sensible")
    func testDefaultValues() {
        let options = ProcessingOptions()

        #expect(options.outputWidth == 80)
        #expect(options.aspectRatioCorrection == 0.5)
        #expect(options.invertBrightness == false)
        #expect(options.contrastBoost == 1.0)
    }

    @Test("Custom initialization")
    func testCustomInitialization() {
        let options = ProcessingOptions(
            outputWidth: 120,
            aspectRatioCorrection: 0.6,
            invertBrightness: true,
            contrastBoost: 1.5
        )

        #expect(options.outputWidth == 120)
        #expect(options.aspectRatioCorrection == 0.6)
        #expect(options.invertBrightness == true)
        #expect(options.contrastBoost == 1.5)
    }

    @Test("Contrast boost clamped to valid range")
    func testContrastBoostClamping() {
        let tooLow = ProcessingOptions(contrastBoost: -1.0)
        let tooHigh = ProcessingOptions(contrastBoost: 5.0)
        let valid = ProcessingOptions(contrastBoost: 1.5)

        #expect(tooLow.contrastBoost == 0.0)
        #expect(tooHigh.contrastBoost == 2.0)
        #expect(valid.contrastBoost == 1.5)
    }

    @Test("Output width has minimum value")
    func testOutputWidthMinimum() {
        let tooSmall = ProcessingOptions(outputWidth: 0)
        let negative = ProcessingOptions(outputWidth: -10)

        #expect(tooSmall.outputWidth == 10)
        #expect(negative.outputWidth == 10)
    }

    @Test("Output width has maximum value")
    func testOutputWidthMaximum() {
        let tooLarge = ProcessingOptions(outputWidth: 1000)

        #expect(tooLarge.outputWidth == 500)
    }

    @Test("Aspect ratio correction clamped")
    func testAspectRatioClamping() {
        let tooLow = ProcessingOptions(aspectRatioCorrection: 0.0)
        let tooHigh = ProcessingOptions(aspectRatioCorrection: 2.0)

        #expect(tooLow.aspectRatioCorrection == 0.1)
        #expect(tooHigh.aspectRatioCorrection == 1.0)
    }

    @Test("Sendable conformance")
    func testSendable() async {
        let options = ProcessingOptions()

        let task = Task {
            options.outputWidth
        }
        let result = await task.value
        #expect(result == 80)
    }

    @Test("Equatable conformance")
    func testEquatable() {
        let options1 = ProcessingOptions()
        let options2 = ProcessingOptions()
        let options3 = ProcessingOptions(invertBrightness: true)

        #expect(options1 == options2)
        #expect(options1 != options3)
    }
}
