import Foundation
import Combine
import UIKit

class RestaurantService: ObservableObject {
    // Published properties
    @Published var restaurant: Restaurant?
    @Published var isLoading: Bool = false
    @Published var error: String? = nil
    
    // API endpoints
    private struct Endpoints {
        static let baseURL = NetworkManager.baseURL
        static let restaurants = "\(baseURL)/restaurants"
        static let user = "\(baseURL)/restaurants/user"
    }
    
    // Private properties
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Public Methods
    
    /// Fetch restaurant by user ID
    /// - Parameter userId: The user ID
    func fetchRestaurantByUserId(userId: String) {
        isLoading = true
        error = nil
        
        let url = URL(string: "\(Endpoints.user)/\(userId)")!
        
        URLSession.shared.dataTaskPublisher(for: url)
            .map(\.data)
            .decode(type: RestaurantResponse.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                switch completion {
                case .failure(let err):
                    self?.error = "Failed to load restaurant: \(err.localizedDescription)"
                    print("Error fetching restaurant: \(err)")
                case .finished:
                    break
                }
            } receiveValue: { [weak self] response in
                self?.restaurant = response.restaurant
            }
            .store(in: &cancellables)
    }
    
    /// Create a new restaurant
    /// - Parameters:
    ///   - restaurant: The restaurant to create
    ///   - completion: Completion handler with result
    func createRestaurant(restaurant: Restaurant, completion: @escaping (Result<Restaurant, Error>) -> Void) {
        isLoading = true
        error = nil
        
        guard let url = URL(string: Endpoints.restaurants) else {
            error = "Invalid URL"
            completion(.failure(NSError(domain: "RestaurantService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        
        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Convert restaurant to JSON data
        do {
            let encoder = JSONEncoder()
            request.httpBody = try encoder.encode(restaurant)
        } catch {
            self.error = "Failed to encode restaurant: \(error.localizedDescription)"
            completion(.failure(error))
            return
        }
        
        // Send request
        URLSession.shared.dataTaskPublisher(for: request)
            .map(\.data)
            .decode(type: RestaurantResponse.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                switch completion {
                case .failure(let err):
                    self?.error = "Failed to create restaurant: \(err.localizedDescription)"
                    print("Error creating restaurant: \(err)")
                case .finished:
                    break
                }
            } receiveValue: { [weak self] response in
                if let createdRestaurant = response.restaurant {
                    self?.restaurant = createdRestaurant
                    completion(.success(createdRestaurant))
                } else {
                    let error = NSError(domain: "RestaurantService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create restaurant"])
                    self?.error = error.localizedDescription
                    completion(.failure(error))
                }
            }
            .store(in: &cancellables)
    }
    
    /// Update restaurant
    /// - Parameters:
    ///   - restaurant: The restaurant to update
    ///   - completion: Completion handler with result
    func updateRestaurant(restaurant: Restaurant, completion: @escaping (Result<Restaurant, Error>) -> Void) {
        isLoading = true
        error = nil
        
        guard let url = URL(string: "\(Endpoints.restaurants)/\(restaurant.id)") else {
            error = "Invalid URL"
            completion(.failure(NSError(domain: "RestaurantService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        
        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Convert restaurant to JSON data
        do {
            let encoder = JSONEncoder()
            request.httpBody = try encoder.encode(restaurant)
        } catch {
            self.error = "Failed to encode restaurant: \(error.localizedDescription)"
            completion(.failure(error))
            return
        }
        
        // Send request
        URLSession.shared.dataTaskPublisher(for: request)
            .map(\.data)
            .decode(type: RestaurantResponse.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                if case .failure(let err) = completion {
                    self?.error = "Failed to update restaurant: \(err.localizedDescription)"
                    print("Error updating restaurant: \(err)")
                }
            } receiveValue: { [weak self] response in
                if let updatedRestaurant = response.restaurant {
                    self?.restaurant = updatedRestaurant
                    completion(.success(updatedRestaurant))
                } else {
                    let error = NSError(domain: "RestaurantService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to update restaurant"])
                    self?.error = error.localizedDescription
                    completion(.failure(error))
                }
            }
            .store(in: &cancellables)
    }
    
    /// Upload restaurant banner image
    /// - Parameters:
    ///   - restaurantId: The restaurant ID
    ///   - image: The image to upload
    ///   - completion: Completion handler with result
    func uploadRestaurantImage(restaurantId: String, image: UIImage, completion: @escaping (Result<String, Error>) -> Void) {
        isLoading = true
        error = nil
        
        guard let url = URL(string: "\(Endpoints.restaurants)/\(restaurantId)/banner") else {
            error = "Invalid URL"
            completion(.failure(NSError(domain: "RestaurantService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        
        // Convert image to base64
        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            error = "Failed to convert image to data"
            completion(.failure(NSError(domain: "RestaurantService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to data"])))
            return
        }
        
        let base64String = imageData.base64EncodedString()
        
        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Create body
        let body: [String: Any] = ["bannerPhoto64Image": base64String]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            self.error = "Failed to encode image data: \(error.localizedDescription)"
            completion(.failure(error))
            return
        }
        
        // Send request
        URLSession.shared.dataTaskPublisher(for: request)
            .map(\.data)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                if case .failure(let err) = completion {
                    self?.error = "Failed to upload image: \(err.localizedDescription)"
                    print("Error uploading image: \(err)")
                }
            } receiveValue: { data in
                // Try to extract image URL from response
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let imageUrl = json["bannerUrl"] as? String {
                    completion(.success(imageUrl))
                } else {
                    // If no specific URL, just return success
                    completion(.success("Image uploaded successfully"))
                }
            }
            .store(in: &cancellables)
    }
}

// Response for restaurant data
struct RestaurantResponse: Codable {
    var restaurant: Restaurant?
    
    enum CodingKeys: String, CodingKey {
        case restaurant
    }
} 