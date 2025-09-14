import Foundation

internal class OBSErrorXMLParser: NSObject, XMLParserDelegate {
    private var currentElement: String = ""
    private var code: String = ""
    private var message: String = ""
    private var requestId: String = ""
    private var hostId: String = ""

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
        // Clear previous element's value
        switch elementName {
        case "Code": code = ""
        case "Message": message = ""
        case "RequestId": requestId = ""
        case "HostId": hostId = ""
        default: break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        switch currentElement {
        case "Code": code += string
        case "Message": message += string
        case "RequestId": requestId += string
        case "HostId": hostId += string
        default: break
        }
    }
}