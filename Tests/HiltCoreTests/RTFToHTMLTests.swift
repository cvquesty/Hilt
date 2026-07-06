import XCTest
@testable import HiltCore

final class RTFToHTMLTests: XCTestCase {
    func testPlainTextEscapes() {
        let out = RTFToHTML.convert("Faith & works <hope>")
        XCTAssertEqual(out, "Faith &amp; works &lt;hope&gt;")
    }

    func testHTMLPassthrough() {
        let html = "In the beginning <i>God</i> created"
        XCTAssertEqual(RTFToHTML.convert(html), html)
    }

    func testBasicRTFBoldItalic() {
        let rtf = #"{\rtf1\ansi This is \b bold\b0 and \i italic\i0 text\par}"#
        let out = RTFToHTML.convert(rtf)
        XCTAssertTrue(out.contains("<b>bold</b>") || out.contains("<b>bold"), out)
        XCTAssertTrue(out.contains("<i>italic</i>") || out.contains("italic"), out)
        XCTAssertFalse(out.lowercased().hasPrefix("{\\rtf"), out)
    }

    func testEmpty() {
        XCTAssertEqual(RTFToHTML.convert(""), "")
        XCTAssertEqual(RTFToHTML.convert("   "), "")
    }
}
