import XCTest

@testable import ContextCore

#if canImport(UniformTypeIdentifiers)
  import UniformTypeIdentifiers
#endif

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// #673, stories 544–545: the shared link, from what the other app hands over to the message the Cockpit gets.
final class ShareLinkTests: XCTestCase {
  private var dir: URL!
  private var store: InboxStore { InboxStore(directory: dir) }
  private let cockpit = "https://cockpit.test"
  private let page = "https://idvork.in/comedy?from=safari&x=a%20b#the-end"

  override func setUp() {
    dir = FileManager.default.temporaryDirectory.appendingPathComponent("share-link-\(UUID().uuidString)")
  }

  override func tearDown() { try? FileManager.default.removeItem(at: dir) }

  /// An attachment as the share sheet offers one: the forms its type conforms to in UTType's tree, and its item.
  /// `testTheShareSheetsProvidersHoldTheFormsTheseAssume` checks the tree against real item providers on the Mac.
  private struct Offered: ShareAttachment {
    var forms: Set<ShareLink.Form>
    var value: Any

    /// public.url, and public.file-url under it.
    static func url(_ value: Any) -> Offered { Offered(forms: [.url], value: value) }
    /// public.plain-text, under public.text.
    static func words(_ value: String) -> Offered { Offered(forms: [.plainText, .text], value: value) }
    /// public.html or public.rtf: text, but not plain.
    static func markedUp(_ value: Data) -> Offered { Offered(forms: [.text], value: value) }
    /// public.jpeg: none of the three.
    static let picture = Offered(forms: [], value: Data([0xFF, 0xD8]))

    func holds(_ form: ShareLink.Form) -> Bool { forms.contains(form) }
    func item(_ form: ShareLink.Form) async -> Any? { forms.contains(form) ? value : nil }
  }

  private var file: Offered { .url(URL(fileURLWithPath: "/tmp/page.pdf")) }
  private func mail() throws -> Offered { .url(try XCTUnwrap(URL(string: "mailto:igor@example.com"))) }

  // MARK: Story 545: however the other app hands it over

  func testALinkHandedOverAsAURLIsFoundWhole() async throws {
    let found = await ShareLink.find(in: [Offered.url(try XCTUnwrap(URL(string: page)))])
    XCTAssertEqual(found?.absoluteString, page)
  }

  func testAFileFirstDoesNotHideTheWebLinkBehindIt() async throws {
    let found = await ShareLink.find(in: [file, .url(try XCTUnwrap(URL(string: page)))])
    XCTAssertEqual(found?.absoluteString, page)
  }

  func testOnlyAFileIsNoLink() async {
    let found = await ShareLink.find(in: [file])
    XCTAssertNil(found)
  }

  func testALinkHandedOverAsWordsOrBytesIsStillALink() async {
    let words = await ShareLink.find(in: [Offered.url(page)])
    XCTAssertEqual(words?.absoluteString, page)
    let bytes = await ShareLink.find(in: [Offered.url(Data(page.utf8))])
    XCTAssertEqual(bytes?.absoluteString, page)
  }

  func testAPictureOrTextAloneHasNoLink() async {
    let found = await ShareLink.find(in: [Offered.words("just words")])
    XCTAssertNil(found)
    let picture = await ShareLink.find(in: [Offered.picture])
    XCTAssertNil(picture)
    let wordsAroundALink = await ShareLink.find(in: [Offered.words("look at \(page)")])
    XCTAssertNil(wordsAroundALink)
    XCTAssertNil(ShareLink.url(from: "two words"))
  }

  func testALinkAsPlainWordsBeatsAPictureOrATextAheadOfIt() async {
    let link = Offered.words(page)
    let behindPicture = await ShareLink.find(in: [.picture, link])
    XCTAssertEqual(behindPicture?.absoluteString, page)
    let behindTitle = await ShareLink.find(in: [.words("Page title"), link])
    XCTAssertEqual(behindTitle?.absoluteString, page)
  }

  /// The spec's "a web link beats anything else shared with it", for a link that comes only as marked-up text. The
  /// reader stands in for UIKit's text system, which the card brings.
  func testALinkAsMarkedUpTextBeatsWhateverIsAheadOfIt() async throws {
    let html = Offered.markedUp(Data(page.utf8))
    let words: (Offered) async -> String? = { [page] _ in page }
    for first in [Offered.picture, .words("Page title"), try mail()] {
      let found = await ShareLink.find(in: [first, html], markedUp: words)
      XCTAssertEqual(found?.absoluteString, page)
    }
  }

  func testMarkedUpTextThatIsMoreThanALinkIsNoLink() async {
    let found = await ShareLink.find(in: [Offered.markedUp(Data("x".utf8))]) { [page] _ in "look at \(page)" }
    XCTAssertNil(found)
  }

  func testAnAddressThatIsNotAWebLinkDoesNotHideOne() async throws {
    let beforeURL = await ShareLink.find(in: [try mail(), .url(try XCTUnwrap(URL(string: page)))])
    XCTAssertEqual(beforeURL?.absoluteString, page)
    let beforeWords = await ShareLink.find(in: [try mail(), .words(page)])
    XCTAssertEqual(beforeWords?.absoluteString, page)
  }

  func testAnAddressThatIsNotAWebLinkIsTheLinkWhenNoWebLinkCameWithIt() async throws {
    let found = await ShareLink.find(in: [file, try mail(), .words("Page title")])
    XCTAssertEqual(found?.absoluteString, "mailto:igor@example.com")
    let words = await ShareLink.find(in: [Offered.words("mailto:igor@example.com")])
    XCTAssertNil(words)
  }

  #if canImport(UniformTypeIdentifiers)
    /// The share sheet's own item providers: each type holds the forms `Offered` gives it, an item loads in the forms
    /// apps register a link as, and `find` reads them through `NSItemProvider` as it does in the app.
    func testTheShareSheetsProvidersHoldTheFormsTheseAssume() async throws {
      func provider(_ item: NSSecureCoding, _ type: UTType) -> NSItemProvider {
        NSItemProvider(item: item, typeIdentifier: type.identifier)
      }
      let link = try XCTUnwrap(URL(string: page))
      let cases: [(NSItemProvider, Set<ShareLink.Form>, String)] = [
        (provider(link as NSURL, .url), [.url], "url"),
        (provider(URL(fileURLWithPath: "/tmp/page.pdf") as NSURL, .fileURL), [.url], "file url"),
        (provider("words" as NSString, .plainText), [.plainText, .text], "plain text"),
        (provider(Data("x".utf8) as NSData, .html), [.text], "html"),
        (provider(Data("x".utf8) as NSData, .rtf), [.text], "rtf"),
        (provider(Data([0xFF, 0xD8]) as NSData, .jpeg), [], "jpeg"),
      ]
      for (provider, forms, name) in cases {
        for form in [ShareLink.Form.url, .plainText, .text] {
          XCTAssertEqual(provider.holds(form), forms.contains(form), "\(name) holds \(form)")
        }
      }
      for item in [link as NSURL, page as NSString, Data(page.utf8) as NSData] as [NSSecureCoding] {
        let loaded = await provider(item, .url).item(.url)
        XCTAssertEqual(loaded.flatMap(ShareLink.url(from:))?.absoluteString, page, "\(type(of: item))")
      }
      let found = await ShareLink.find(in: [
        provider(Data([0xFF, 0xD8]) as NSData, .jpeg), provider(URL(fileURLWithPath: "/tmp/a.pdf") as NSURL, .fileURL),
        provider(page as NSString, .plainText),
      ])
      XCTAssertEqual(found?.absoluteString, page)
    }
  #endif

  func testTextThatIsOnlyALinkIsALinkAndTextAroundOneStaysText() {
    XCTAssertEqual(ShareLink.fromText("  \(page)\n")?.absoluteString, page)
    XCTAssertEqual(ShareLink.fromText("HTTPS://idvork.in/a")?.absoluteString, "HTTPS://idvork.in/a")
    XCTAssertNil(ShareLink.fromText("look at \(page)"))
    XCTAssertNil(ShareLink.fromText("mailto:igor@example.com"))
    XCTAssertEqual(
      ChatSend.text(for: InboxItem(kind: .text, sharedAt: 0, text: "look at \(page) today", note: "why")),
      "look at \(page) today\n\nwhy")
  }

  // MARK: Story 544: the message, down every path of the card

  private func sent(_ item: InboxItem) async throws -> (URL?, [String: Any], [(String, [String: Any])]) {
    try store.add(item)
    let asked = AskedRequests()
    let sender = InboxSender(store: store, cockpit: cockpit) { request in
      await asked.add(request)
      return ChatTests.answer(request, 200, #"{"ok": true, "thread": "t"}"#)
    }
    var lines: [(String, [String: Any])] = []
    _ = await sender.sendWaiting { type, fields in lines.append((type, fields)) }
    let first = await asked.all.first
    let request = try XCTUnwrap(first)
    let body = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(request.httpBody)) as? [String: Any])
    return (request.url, body, lines)
  }

  func testEveryPathOfTheCardCarriesTheWholeLinkFirst() async throws {
    let paths: [(note: String?, thread: String?, text: String, path: String)] = [
      (nil, nil, page, "/chat"),
      ("worth a read", nil, "\(page)\n\nworth a read", "/chat"),
      (nil, "igor2-88g.900", page, "/chat/igor2-88g.900"),
      ("worth a read", "igor2-88g.900", "\(page)\n\nworth a read", "/chat/igor2-88g.900"),
    ]
    for (index, path) in paths.enumerated() {
      let (url, body, lines) = try await sent(
        InboxItem(id: "share-\(index)", kind: .link, sharedAt: 1, url: page, note: path.note, thread: path.thread))
      XCTAssertEqual(url?.path, path.path)
      XCTAssertEqual(body["text"] as? String, path.text)
      XCTAssertEqual(lines.first { $0.0 == "chat" }?.1["link_in_message"] as? Bool, true)
      XCTAssertEqual(store.item("share-\(index)")?.status, .sent)
    }
  }

  func testATitleOfferedBesideALinkIsOnTheCardNotInTheMessage() async throws {
    let (_, body, _) = try await sent(
      InboxItem(id: "titled", kind: .link, sharedAt: 1, url: page, text: "Comedy", note: "worth a read"))
    XCTAssertEqual(body["text"] as? String, "\(page)\n\nworth a read")
    XCTAssertEqual(body["title"] as? String, "worth a read")
  }

  func testAVeryLongMessageNeverTouchesTheLink() async throws {
    let long = String(repeating: "word ", count: 200).trimmingCharacters(in: .whitespaces)
    let (_, body, _) = try await sent(InboxItem(id: "long", kind: .link, sharedAt: 1, url: page, note: long))
    XCTAssertEqual(body["text"] as? String, "\(page)\n\n\(long)")
    XCTAssertLessThanOrEqual((body["title"] as? String)?.count ?? .max, ChatSend.maxTitle)
  }

  func testTheTypesOfferedAreKeptForTheLogAndTheLogHoldsNoLink() async throws {
    var item = InboxItem(id: "typed", kind: .link, sharedAt: 1, url: page)
    item.shareTypes = "public.url, public.plain-text"
    try store.add(item)
    XCTAssertEqual(store.item("typed")?.shareTypes, "public.url, public.plain-text")
    XCTAssertFalse(ChatSend.carriesLink(InboxItem(kind: .link, sharedAt: 1)))
    let (_, _, lines) = try await sent(InboxItem(id: "quiet", kind: .link, sharedAt: 1, url: page, note: "private"))
    let line = try XCTUnwrap(lines.first { $0.1["item"] as? String == "quiet" }?.1)
    XCTAssertEqual(line["link_in_message"] as? Bool, true)
    XCTAssertFalse("\(line)".contains("idvork.in"))
    XCTAssertFalse("\(line)".contains("private"))
  }
}

private actor AskedRequests {
  private(set) var all: [URLRequest] = []
  func add(_ request: URLRequest) { all.append(request) }
}
