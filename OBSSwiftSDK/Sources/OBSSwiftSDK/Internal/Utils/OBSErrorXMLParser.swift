import Foundation

/// A parser for OBS XML error responses.
///
/// This class conforms to `XMLParserDelegate` to parse error documents returned by the
/// OBS service. It extracts key information such as the error code, message, request ID,
/// and host ID.
///
/// It is designed to parse an XML structure similar to the following example:
///
internal class OBSErrorXMLParser: NSObject, XMLParserDelegate {
    private var currentElement: String = ""
    private var code: String = ""
    private var message: String = ""
    private var requestId: String = ""
    private var hostId: String = ""

    /// Parses XML data and returns an `OBSErrorResponse` object if successful.
    /// - Parameter data: The XML `Data` to be parsed.
    /// - Returns: An optional `OBSErrorResponse` object. Returns `nil` if parsing fails or the `Code` element is missing.
    static func parse(from data: Data) -> OBSErrorResponse? {
        let parser = XMLParser(data: data)
        let delegate = OBSErrorXMLParser()
        parser.delegate = delegate
        
        if parser.parse(),!delegate.code.isEmpty {
            return OBSErrorResponse(
                code: delegate.code.trimmingCharacters(in:.whitespacesAndNewlines),
                message: delegate.message.trimmingCharacters(in:.whitespacesAndNewlines),
                requestId: delegate.requestId.trimmingCharacters(in:.whitespacesAndNewlines),
                hostId: delegate.hostId.trimmingCharacters(in:.whitespacesAndNewlines)
            )
        }
        return nil
    }

    // MARK: - XMLParserDelegate

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName
        // Clear the string buffer when a new element of interest is found.
        switch elementName {
        case "Code": code = ""
        case "Message": message = ""
        case "RequestId": requestId = ""
        case "HostId": hostId = ""
        default: break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        // Append characters to the appropriate property based on the current element.
        switch currentElement {
        case "Code": code += string
        case "Message": message += string
        case "RequestId": requestId += string
        case "HostId": hostId += string
        default: break
        }
    }
}