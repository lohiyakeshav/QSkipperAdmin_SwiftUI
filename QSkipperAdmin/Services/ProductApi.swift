import Foundation
import UIKit
import Combine
import CommonCrypto

class ProductApi {
    static let shared = ProductApi()
    
    // Base URL
    private let baseUrl = URL(string: NetworkManager.baseURL)!
    
    // Image cache
    private let imageCache = NSCache<NSString, UIImage>()
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    
    private init() {
        // Create cache directory in the documents folder
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        cacheDirectory = documentsDirectory.appendingPathComponent("ImageCache")
        
        do {
            try fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true, attributes: nil)
        } catch {
            print("Error creating cache directory: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Image Cache Methods
    
    /// Error enum for product API operations
    enum ProductApiError: Error {
        case invalidURL
        case imageNotFound
        case networkError
        
        var localizedDescription: String {
            switch self {
            case .invalidURL: return "Invalid URL provided"
            case .imageNotFound: return "Image could not be found or loaded"
            case .networkError: return "Network error occurred"
            }
        }
    }
    
    /// Cache an image in both memory and disk
    private func cacheImage(_ image: UIImage, forKey key: String) {
        // Generate a safe cache key
        let safeKey = key.md5
        
        // Memory cache
        imageCache.setObject(image, forKey: safeKey as NSString)
        
        // Disk cache
        let imagePath = cacheDirectory.appendingPathComponent(safeKey).path
        if let data = image.jpegData(compressionQuality: 0.9) {
            do {
                try data.write(to: URL(fileURLWithPath: imagePath))
                DebugLogger.shared.log("Image saved to disk cache: \(safeKey)", category: .cache)
            } catch {
                DebugLogger.shared.log("Failed to write image to disk: \(error.localizedDescription)", category: .error)
            }
        }
    }
    
    /// Get image from cache (memory or disk)
    private func getCachedImage(forKey key: String) -> UIImage? {
        // Generate a safe cache key
        let safeKey = key.md5
        
        // Check memory cache first
        if let cachedImage = imageCache.object(forKey: safeKey as NSString) {
            DebugLogger.shared.log("Using cached image from memory for key: \(safeKey)", category: .cache)
            return cachedImage
        }
        
        // Check disk cache
        let imagePath = cacheDirectory.appendingPathComponent(safeKey).path
        if fileManager.fileExists(atPath: imagePath),
           let imageData = try? Data(contentsOf: URL(fileURLWithPath: imagePath)),
           let image = UIImage(data: imageData) {
            // Add to memory cache for faster access next time
            imageCache.setObject(image, forKey: safeKey as NSString)
            DebugLogger.shared.log("Using cached image from disk for key: \(safeKey)", category: .cache)
            return image
        }
        
        return nil
    }
    
    /// Clear all cached images
    func clearImageCache() {
        // Clear memory cache
        imageCache.removeAllObjects()
        
        // Clear disk cache
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
            for fileURL in fileURLs {
                try fileManager.removeItem(at: fileURL)
            }
            DebugLogger.shared.log("Image cache cleared", category: .cache)
        } catch {
            DebugLogger.shared.log("Failed to clear disk cache: \(error.localizedDescription)", category: .error)
        }
    }
    
    /// Fetch an image from a URL, using cache if available
    /// - Parameter url: URL for the image
    /// - Returns: UIImage if successful
    func fetchImage(from url: URL) async throws -> UIImage {
        // Create a URL string to use as cache key
        let urlString = url.absoluteString
        
        // Check if image exists in cache
        if let cachedImage = getCachedImage(forKey: urlString) {
            DebugLogger.shared.log("Using cached image for URL: \(urlString)", category: .cache)
            return cachedImage
        }
        
        DebugLogger.shared.log("Fetching image from network: \(urlString)", category: .network)
        
        do {
            // Configure request with longer timeout
            var request = URLRequest(url: url)
            request.timeoutInterval = 30.0
            request.cachePolicy = .reloadIgnoringLocalCacheData
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ProductApiError.networkError
            }
            
            // Check if we received an error response
            if httpResponse.statusCode != 200 {
                DebugLogger.shared.log("HTTP error: \(httpResponse.statusCode) for \(urlString)", category: .error)
                throw ProductApiError.imageNotFound
            }
            
            // Check if we received an image
            guard let image = UIImage(data: data) else {
                // Try to see if the data can be interpreted as text for debugging
                if let string = String(data: data, encoding: .utf8), string.count < 1000 {
                    DebugLogger.shared.log("Image data response as string: \(string)", category: .network)
                } else {
                    DebugLogger.shared.log("Received non-image data for \(urlString)", category: .error)
                }
                throw ProductApiError.imageNotFound
            }
            
            // Cache the downloaded image
            cacheImage(image, forKey: urlString)
            DebugLogger.shared.log("Image downloaded and cached for URL: \(urlString)", category: .cache)
            
            return image
        } catch {
            DebugLogger.shared.log("Error fetching image: \(error.localizedDescription)", category: .error)
            throw ProductApiError.networkError
        }
    }
    
    /// Fetch an image from a URL string, using cache if available
    /// - Parameter urlString: URL string for the image
    /// - Returns: UIImage if successful
    func fetchImage(from urlString: String) async throws -> UIImage {
        guard let url = URL(string: urlString) else {
            throw ProductApiError.invalidURL
        }
        
        return try await fetchImage(from: url)
    }
    
    // MARK: - Product Methods
    
    /// Get all products using direct URL approach - DEPRECATED
    /// Use getAllProducts() instead
    /// - Returns: Array of products
    func getAllProduct() async throws -> [Product] {
        return try await getAllProducts()
    }
    
    /// Get all products for a restaurant
    /// - Parameter restaurantId: The restaurant ID
    /// - Returns: Array of products
    func getAllProducts(restaurantId: String = "") async throws -> [Product] {
        // Use the restaurantId parameter if provided, otherwise use DataController's restaurant ID
        let targetRestaurantId = !restaurantId.isEmpty ? restaurantId : DataController.shared.restaurant.id
        
        // Use the restaurant ID (not user ID) for the API endpoint
        let productUrl = baseUrl.appendingPathComponent("get_all_product/\(targetRestaurantId)")
        var request = URLRequest(url: productUrl)
        
        // Add auth token if available
        if let token = AuthService.shared.getToken() {
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            DebugLogger.shared.log("Added auth token to request", category: .network, tag: "PRODUCT_API")
        }
        
        DebugLogger.shared.logRequest(request)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let string = String(data: data, encoding: .utf8) {
            DebugLogger.shared.log("Response data: \(string)", category: .network, tag: "PRODUCT_API")
            debugPrint(string)
            debugPrint("get all product")
        }
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            DebugLogger.shared.log("Invalid response: \(response)", category: .network, tag: "PRODUCT_API_ERROR")
            throw NSError(domain: "ProductApi", code: 0, userInfo: [NSLocalizedDescriptionKey: "Products not found"])
        }
        
        let decoder = JSONDecoder()
        
        do {
            let productResponse = try decoder.decode(ProductResponse.self, from: data)
            DebugLogger.shared.log("Successfully decoded \(productResponse.products?.count ?? 0) products", category: .network, tag: "PRODUCT_API")
            return productResponse.products ?? []
        } catch {
            DebugLogger.shared.log("Failed to decode product response: \(error.localizedDescription)", category: .error, tag: "PRODUCT_LOADING")
            
            // Try to decode just the array directly
            do {
                let products = try decoder.decode([Product].self, from: data)
                DebugLogger.shared.log("Successfully decoded \(products.count) products directly from array", category: .network, tag: "PRODUCT_API")
                return products
            } catch {
                DebugLogger.shared.log("Failed final attempt to decode products: \(error.localizedDescription)", category: .error, tag: "PRODUCT_LOADING")
                throw error
            }
        }
    }
    
    /// Create a new product
    /// - Parameters:
    ///   - product: The product to create
    ///   - image: Optional product image
    /// - Returns: Created product
    func createProduct(product: Product, image: UIImage? = nil) async throws -> Product {
        guard let url = URL(string: "\(NetworkManager.baseURL)/products") else {
            throw NSError(domain: "ProductApi", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // If we have an image, convert to base64
        var productWithImage = product
        if let image = image, let imageData = image.jpegData(compressionQuality: 0.7) {
            productWithImage.productPhoto = image
        }
        
        // Encode product to JSON
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(productWithImage)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 201 else {
            throw NSError(domain: "ProductApi", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to create product"])
        }
        
        let productResponse = try JSONDecoder().decode(ProductResponse.self, from: data)
        guard let createdProduct = productResponse.product else {
            throw NSError(domain: "ProductApi", code: 0, userInfo: [NSLocalizedDescriptionKey: "No product in response"])
        }
        
        return createdProduct
    }
    
    /// Delete a product
    /// - Parameter productId: The product ID to delete
    /// - Returns: Success boolean
    func deleteProduct(productId: String) async throws -> Bool {
        guard let url = URL(string: "\(NetworkManager.baseURL)/products/\(productId)") else {
            throw NSError(domain: "ProductApi", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NSError(domain: "ProductApi", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to delete product"])
        }
        
        let deleteResponse = try JSONDecoder().decode(DeleteProductResponse.self, from: data)
        return deleteResponse.success
    }
}

// Extension for MD5 hashing (for cache keys)
extension String {
    var md5: String {
        let data = Data(self.utf8)
        let hash = data.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) -> [UInt8] in
            var hash = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
            CC_MD5(bytes.baseAddress, CC_LONG(data.count), &hash)
            return hash
        }
        return hash.map { String(format: "%02x", $0) }.joined()
    }
} 