import Foundation
import SwiftUI
import Combine

class ProductService: ObservableObject {
    static let shared = ProductService()
    
    // Published properties
    @Published var products: [Product] = []
    @Published var isLoading: Bool = false
    @Published var error: String? = nil
    
    // API client
    private let productApi = ProductApi.shared
    
    // MARK: - Product Methods
    
    /// Fetch products for a restaurant
    /// - Parameter restaurantId: The restaurant ID
    func fetchRestaurantProducts(restaurantId: String = "") {
        isLoading = true
        error = nil
        
        Task {
            do {
                DebugLogger.shared.log("Starting to load products", category: .network)
                
                // Use the provided restaurantId if not empty, otherwise use DataController's restaurant
                let targetRestaurantId = !restaurantId.isEmpty ? restaurantId : DataController.shared.restaurant.id
                
                // If we have a restaurantId from DataController, log it
                if !DataController.shared.restaurant.id.isEmpty {
                    DebugLogger.shared.log("Using restaurant ID from DataController: \(DataController.shared.restaurant.id)", category: .network)
                }
                
                // Pass the restaurant ID to the API call
                let fetchedProducts = try await productApi.getAllProducts(restaurantId: targetRestaurantId)
                
                DispatchQueue.main.async { [weak self] in
                    self?.products = fetchedProducts
                    self?.isLoading = false
                }
            } catch {
                DispatchQueue.main.async { [weak self] in
                    self?.error = error.localizedDescription
                    self?.isLoading = false
                }
            }
        }
    }
    
    /// Add a new product
    /// - Parameters:
    ///   - product: The product to add
    ///   - completion: Completion handler
    func addProduct(product: Product, completion: @escaping (Result<Product, Error>) -> Void) {
        isLoading = true
        error = nil
        
        Task {
            do {
                let newProduct = try await productApi.createProduct(product: product, image: product.productPhoto)
                
                DispatchQueue.main.async { [weak self] in
                    self?.isLoading = false
                    
                    // Add to local products
                    self?.products.append(newProduct)
                    
                    completion(.success(newProduct))
                }
            } catch {
                DispatchQueue.main.async { [weak self] in
                    self?.isLoading = false
                    self?.error = error.localizedDescription
                    completion(.failure(error))
                }
            }
        }
    }
    
    /// Update an existing product
    /// - Parameters:
    ///   - product: The product to update
    ///   - completion: Completion handler
    func updateProduct(product: Product, completion: @escaping (Result<Product, Error>) -> Void) {
        isLoading = true
        error = nil
        
        // In a real implementation, call an API to update
        // For now, simulate by updating local array
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self else { return }
            
            // Find and update product in array
            if let index = self.products.firstIndex(where: { $0.id == product.id }) {
                self.products[index] = product
                self.isLoading = false
                completion(.success(product))
            } else {
                self.isLoading = false
                let error = NSError(domain: "ProductService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Product not found"])
                self.error = error.localizedDescription
                completion(.failure(error))
            }
        }
    }
    
    /// Delete a product
    /// - Parameters:
    ///   - productId: The product ID to delete
    ///   - completion: Completion handler
    func deleteProduct(productId: String, completion: @escaping (Bool) -> Void) {
        isLoading = true
        error = nil
        
        Task {
            do {
                let success = try await productApi.deleteProduct(productId: productId)
                
                DispatchQueue.main.async { [weak self] in
                    self?.isLoading = false
                    
                    if success {
                        // Remove from local products
                        self?.products.removeAll { $0.id == productId }
                    }
                    
                    completion(success)
                }
            } catch {
                DispatchQueue.main.async { [weak self] in
                    self?.isLoading = false
                    self?.error = error.localizedDescription
                    completion(false)
                }
            }
        }
    }
    
    /// Toggle product availability
    /// - Parameters:
    ///   - productId: The product ID
    ///   - isAvailable: New availability state
    ///   - completion: Completion handler
    func toggleProductAvailability(productId: String, isAvailable: Bool, completion: @escaping (Result<Bool, Error>) -> Void) {
        isLoading = true
        error = nil
        
        // In a real implementation, call an API to update
        // For now, just update locally
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            
            // Find and update product in array
            if let index = self.products.firstIndex(where: { $0.id == productId }) {
                var updatedProduct = self.products[index]
                updatedProduct.isAvailable = isAvailable
                self.products[index] = updatedProduct
                
                self.isLoading = false
                completion(.success(true))
            } else {
                self.isLoading = false
                let error = NSError(domain: "ProductService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Product not found"])
                self.error = error.localizedDescription
                completion(.failure(error))
            }
        }
    }
} 