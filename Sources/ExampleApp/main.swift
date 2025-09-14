import Foundation
import OBSSwiftSDK

@main
struct ExampleApp {
    static func main() async {
        // --- Configuration ---
        guard let endpoint = ProcessInfo.processInfo.environment,
            let ak = ProcessInfo.processInfo.environment,
            let sk = ProcessInfo.processInfo.environment,
            let bucket = ProcessInfo.processInfo.environment else {
            fatalError("Missing environment variables: OBS_ENDPOINT, OBS_AK, OBS_SK, OBS_BUCKET")
        }

        let initialCredentials = OBSCredentials.permanent(ak: ak, sk: sk)
        let config = OBSConfiguration(
            endpoint: endpoint,
            credentials: initialCredentials,
            logLevel:.debug
        )
        let client = OBSClient(configuration: config)

        // --- Upload Example with Enhanced Parameters ---
        let objectKey = "swift-sdk-upload-\(UUID().uuidString).txt"
        let fileContent = "Hello from the Swift SDK at \(Date())"
        
        let uploadRequest = UploadObjectRequest(
            bucketName: bucket,
            objectKey: objectKey,
            data: fileContent.data(using:.utf8)!,
            contentType: "text/plain",
            acl:.publicRead,
            storageClass:.warm,
            metadata: ["user-id": "12345", "source": "mobile-app"]
        )

        print("🚀 Starting upload for object: \(objectKey)...")
        do {
            let response = try await client.uploadObject(request: uploadRequest)
            print("✅ Upload successful!")
            print("   ETag: \(response.eTag ?? "N/A")")
            print("   Version ID: \(response.versionId ?? "N/A")")
            print("   Storage Class: \(response.storageClass ?? "N/A")")
        } catch {
            print("❌ Upload failed: \(error.localizedDescription)")
        }
    }
}
