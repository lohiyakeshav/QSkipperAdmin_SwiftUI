import Foundation
import Combine

// MARK: - Order API Errors
enum OrderApiError: Error {
    case invalidURL
    case networkError
    case orderNotFound
    case serverError
    
    var localizedDescription: String {
        switch self {
        case .invalidURL: return "Invalid URL provided"
        case .networkError: return "Network error occurred"
        case .orderNotFound: return "Order not found"
        case .serverError: return "Server error occurred"
        }
    }
}

// MARK: - Order Response Models
struct APIOrderResponse: Codable {
    let length: Int
    let allOrders: [APIOrder]
    
    enum CodingKeys: String, CodingKey {
        case length
        case allOrders = "all_orders"
    }
}

// MARK: - Order Item Model
struct APIOrder: Codable, Identifiable {
    let id: String
    let restaurantId: String
    let userId: String
    let items: [APIOrderProduct]
    let totalAmount: String
    var status: String
    let cookTime: Int
    let takeAway: Bool
    let scheduleDate: String?
    let orderTime: String
    
    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case restaurantId = "resturant"
        case userId = "userID"
        case items
        case totalAmount
        case status
        case cookTime
        case takeAway
        case scheduleDate
        case orderTime = "Time"
    }
    
    // Computed properties for UI
    var formattedDate: String {
        // For scheduled orders
        if let scheduleDateStr = scheduleDate {
            let formatter = ISO8601DateFormatter()
            if let date = formatter.date(from: scheduleDateStr) {
                let displayFormatter = DateFormatter()
                displayFormatter.dateStyle = .medium
                displayFormatter.timeStyle = .short
                return "Scheduled for " + displayFormatter.string(from: date)
            }
        }
        
        // For regular orders, use the order time
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: orderTime) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .short
            return displayFormatter.string(from: date)
        }
        
        // Default for unknown dates
        return status.lowercased().contains("schedule") ? "Scheduled order" : "Recent order"
    }
    
    // Get formatted order time
    var formattedOrderTime: String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: orderTime) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .short
            return displayFormatter.string(from: date)
        }
        return "Today"
    }
    
    var statusColor: Color {
        switch status.lowercased() {
        case "placed", "pending": return .orange
        case "schedule", "scheduled": return .green
        case "preparing": return .purple
        case "ready": return .green
        case "completed": return .gray
        case "cancelled": return .red
        default: return .primary
        }
    }
    
    var isScheduled: Bool {
        return scheduleDate != nil || status.lowercased().contains("schedule")
    }
    
    var totalAmountFormatted: String {
        if let amount = Double(totalAmount) {
            return String(format: "₹%.2f", amount)
        }
        return totalAmount
    }
}

// MARK: - Order Product Model
struct APIOrderProduct: Codable, Identifiable {
    let id: String
    let name: String
    let quantity: Int
    let price: Int
    
    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case name
        case quantity
        case price
    }
}

// MARK: - OrderApi Class
class OrderApi {
    static let shared = OrderApi()
    
    // Base URL
    private let baseUrl = URL(string: NetworkManager.baseURL)!
    
    private init() {}
    
    // MARK: - Fetch Orders
    
    /// Fetch all orders for the restaurant
    /// - Returns: A list of orders
    func getAllOrders() async throws -> [APIOrder] {
        // Use the restaurant ID for fetching orders
        let restaurantId = DataController.shared.restaurant.id
        let orderUrl = baseUrl.appendingPathComponent("get-order/\(restaurantId)")
        
        var request = URLRequest(url: orderUrl)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        
        // Add auth token if available
        if let token = AuthService.shared.getToken() {
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        DebugLogger.shared.log("Fetching orders for restaurant: \(restaurantId)", category: .network)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let string = String(data: data, encoding: .utf8) {
                DebugLogger.shared.log("Orders response data: \(string.prefix(500))", category: .network)
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw OrderApiError.networkError
            }
            
            guard httpResponse.statusCode == 200 else {
                switch httpResponse.statusCode {
                case 404: throw OrderApiError.orderNotFound
                default: throw OrderApiError.serverError
                }
            }
            
            let decoder = JSONDecoder()
            let orderResponse = try decoder.decode(APIOrderResponse.self, from: data)
            
            DebugLogger.shared.log("Successfully loaded \(orderResponse.allOrders.count) orders", category: .network)
            return orderResponse.allOrders
        } catch {
            DebugLogger.shared.log("Failed to load orders: \(error.localizedDescription)", category: .error)
            throw error
        }
    }
    
    // MARK: - Complete Order
    
    /// Mark an order as completed
    /// - Parameter orderId: The ID of the order to complete
    /// - Returns: A boolean indicating success
    func completeOrder(orderId: String) async throws -> Bool {
        let orderUrl = baseUrl.appendingPathComponent("order-complete/\(orderId)")
        
        var request = URLRequest(url: orderUrl)
        request.httpMethod = "PUT"
        
        // Add auth token if available
        if let token = AuthService.shared.getToken() {
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        DebugLogger.shared.log("Completing order: \(orderId)", category: .network)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let string = String(data: data, encoding: .utf8) {
                DebugLogger.shared.log("Complete order response: \(string)", category: .network)
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw OrderApiError.networkError
            }
            
            guard httpResponse.statusCode == 202 || httpResponse.statusCode == 200 else {
                switch httpResponse.statusCode {
                case 404: throw OrderApiError.orderNotFound
                default: throw OrderApiError.serverError
                }
            }
            
            return true
        } catch {
            DebugLogger.shared.log("Failed to complete order: \(error.localizedDescription)", category: .error)
            throw error
        }
    }
}

// Add Color extension to avoid compiler error
import SwiftUI
extension Color {
    static var orange: Color { Color(.orange) }
    static var blue: Color { Color(.blue) }
    static var purple: Color { Color(.purple) }
    static var green: Color { Color(.green) }
    static var gray: Color { Color(.gray) }
    static var red: Color { Color(.red) }
    static var primary: Color { Color(.label) }
} 