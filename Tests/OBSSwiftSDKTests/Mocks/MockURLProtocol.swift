import Foundation
import XCTest

/// 一个自定义的 URLProtocol，用于拦截网络请求并返回预设的模拟（mock）响应。
/// 这是进行可靠网络测试的关键，可以让我们在不访问真实网络的情况下测试所有网络逻辑。
final class MockURLProtocol: URLProtocol {
    
    // 静态属性，用于存储每个测试用例想要返回的响应。
    // requestHandler 是一个闭包，它接收一个 URLRequest，并返回一个预设的响应和数据。
    nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data?))?

    override class func canInit(with request: URLRequest) -> Bool {
        // 返回 true，表示我们想要处理所有类型的请求。
        return true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        // 直接返回请求，我们不需要修改它。
        return request
    }

    override func startLoading() {
        guard let handler = MockURLProtocol.requestHandler else {
            XCTFail("MockURLProtocol.requestHandler is not set.")
            return
        }

        do {
            // 调用测试用例设置的 handler 来获取模拟的响应和数据。
            let (response, data) = try handler(request)
            
            // 将模拟响应返回给 URLSession。
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            
            // 如果有模拟数据，也一并返回。
            if let data = data {
                client?.urlProtocol(self, didLoad: data)
            }
            
            // 通知 URLSession 请求已成功完成。
            client?.urlProtocolDidFinishLoading(self)
            
        } catch {
            // 如果 handler 抛出错误，则通知 URLSession 请求失败。
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {
        // 无需实现，因为我们的请求是瞬时完成的。
    }
}