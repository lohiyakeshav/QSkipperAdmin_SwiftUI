import SwiftUI
import Combine
import PhotosUI
// Import the UIKitImagePicker
import UIKit

struct RestaurantManagementView: View {
    // Environment
    @EnvironmentObject private var dataController: DataController
    @EnvironmentObject private var authService: AuthService
    @StateObject private var restaurantService = RestaurantService()
    
    // State
    @State private var restaurantName: String = ""
    @State private var estimatedTime: String = "30"
    @State private var selectedCuisine: String = "North Indian"
    @State private var restaurantImage: UIImage? = nil
    @State private var isImagePickerShown = false
    @State private var isRegistered: Bool = true // Default to true, will be updated in onAppear
    
    // Product state
    @State private var productName: String = ""
    @State private var productPrice: String = ""
    @State private var productCategory: String = ""
    @State private var productDescription: String = ""
    @State private var preparationTime: String = "0"
    @State private var productImage: UIImage? = nil
    @State private var isProductImagePickerShown = false
    
    // UI state
    @State private var isSubmitting = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var currentImageSelection: ImageSelectionType = .restaurant
    @State private var selectedTab: SidebarTab = .profile
    
    // Cuisine types for selection
    let cuisineTypes = ["North Indian", "South Indian", "Chinese", "Fast Food", "Drinks & Snacks", "Italian", "Mexican", "Continental"]
    
    enum ImageSelectionType {
        case restaurant
        case product
    }
    
    enum SidebarTab {
        case profile
        case addProduct
        case products
        case statistics
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                restaurantProfileSection
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(isRegistered ? "Restaurant Profile" : "Register Restaurant")
        .sheet(isPresented: $isImagePickerShown) {
            UIKitImagePicker(selectedImage: $restaurantImage)
        }
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("Message"),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
        .onAppear {
            loadRestaurantData()
            checkRegistrationStatus()
            
            // Force attempt to load restaurant image - try both user ID and restaurant ID
            if let userId = authService.getUserId() {
                RestaurantService.shared.fetchRestaurantImage(restaurantId: userId) { image in
                    if let image = image {
                        DispatchQueue.main.async {
                            self.restaurantImage = image
                            DebugLogger.shared.log("Successfully loaded restaurant image from user ID", category: .network, tag: "RESTAURANT_MANAGEMENT")
                        }
                    }
                }
            }
            
            // Also try with restaurant ID if different
            if let restaurantId = UserDefaults.standard.string(forKey: "restaurant_id"), 
               restaurantId != authService.getUserId() {
                RestaurantService.shared.fetchRestaurantImage(restaurantId: restaurantId) { image in
                    if let image = image {
                        DispatchQueue.main.async {
                            self.restaurantImage = image
                            DebugLogger.shared.log("Successfully loaded restaurant image from restaurant ID", category: .network, tag: "RESTAURANT_MANAGEMENT")
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Restaurant Profile Section
    private var restaurantProfileSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 15) {
                // Restaurant name
                VStack(alignment: .leading) {
                    Text("Restaurant Name")
                        .font(.headline)
                    TextField("Enter restaurant name", text: $restaurantName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                // Estimated time
                VStack(alignment: .leading) {
                    Text("Estimated Time (minutes)")
                        .font(.headline)
                    TextField("30", text: $estimatedTime)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.numberPad)
                }
                
                // Cuisine selection
                VStack(alignment: .leading) {
                    Text("Cuisine")
                        .font(.headline)
                    
                    Picker("Select cuisine", selection: $selectedCuisine) {
                        ForEach(cuisineTypes, id: \.self) { cuisine in
                            Text(cuisine).tag(cuisine)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(Color(.systemBackground))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )
                }
                
                // Banner photo
                VStack(alignment: .leading) {
                    Text("Banner Photo")
                        .font(.headline)
                    
                    ZStack {
                        if let image = restaurantImage {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 200)
                        } else {
                            Rectangle()
                                .fill(Color(.systemGray5))
                                .frame(height: 200)
                                .overlay(
                                    Text("No Image Selected")
                                        .foregroundColor(.gray)
                                )
                        }
                    }
                    .cornerRadius(8)
                    
                    Button(action: {
                        currentImageSelection = .restaurant
                        isImagePickerShown = true
                    }) {
                        HStack {
                            Image(systemName: "arrow.up.square")
                            Text("Upload Photo")
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 8)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(8)
            .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 1)
            
            // Submit button
            if !shouldHideSaveButton() {
                Button(action: submitRestaurantProfile) {
                    HStack {
                        if isSubmitting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        }
                        Text(isRegistered ? "Save Changes" : "Register Restaurant")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(isSubmitting)
            }
        }
    }
    
    // MARK: - Methods
    private func shouldHideSaveButton() -> Bool {
        // Always hide the button when fields are filled and registered
        if isRegistered && !restaurantName.isEmpty && !estimatedTime.isEmpty && !selectedCuisine.isEmpty && restaurantImage != nil {
            return true
        }
        
        // Also hide if there's an active submission
        if isSubmitting {
            return true
        }
        
        return false
    }
    
    private func loadRestaurantData() {
        // Load existing restaurant data if available
        if !dataController.restaurant.name.isEmpty {
            restaurantName = dataController.restaurant.name
        }
        
        // Try to load restaurant image if we have a restaurantId
        if let restaurantId = authService.getUserId(), restaurantImage == nil {
            RestaurantService.shared.fetchRestaurantImage(restaurantId: restaurantId) { image in
                if let image = image {
                    DispatchQueue.main.async {
                        self.restaurantImage = image
                        DebugLogger.shared.log("Successfully loaded restaurant image", category: .network, tag: "RESTAURANT_MANAGEMENT")
                    }
                }
            }
        }
        
        // Load restaurant data from UserDefaults
        if let restaurantDataEncoded = UserDefaults.standard.data(forKey: "restaurant_data"),
           let restaurantData = try? JSONSerialization.jsonObject(with: restaurantDataEncoded, options: []) as? [String: Any] {
            
            if let name = restaurantData["name"] as? String, !name.isEmpty {
                restaurantName = name
            }
            
            if let time = restaurantData["estimatedTime"] as? Int {
                estimatedTime = String(time)
            }
            
            if let cuisine = restaurantData["cuisine"] as? String, !cuisine.isEmpty {
                selectedCuisine = cuisine
            }
        }
    }
    
    private func checkRegistrationStatus() {
        // Check if restaurant is registered
        isRegistered = UserDefaults.standard.bool(forKey: "is_restaurant_registered")
    }
    
    private func submitRestaurantProfile() {
        guard validateRestaurantFields() else { return }
        
        isSubmitting = true
        
        // Get the user ID
        guard let userId = authService.getUserId() else {
            showAlert(message: "User ID not found")
            isSubmitting = false
            return
        }
        
        if isRegistered {
            // Update existing restaurant
            updateRestaurantProfile()
        } else {
            // Register new restaurant
            registerNewRestaurant(userId: userId)
        }
    }
    
    private func validateRestaurantFields() -> Bool {
        // Basic validation
        if restaurantName.isEmpty {
            showAlert(message: "Please enter restaurant name")
            return false
        }
        
        if estimatedTime.isEmpty {
            showAlert(message: "Please enter estimated time")
            return false
        }
        
        if restaurantImage == nil {
            showAlert(message: "Please select a banner image")
            return false
        }
        
        return true
    }
    
    private func createRestaurantFormData() -> [String: Any] {
        var formData: [String: Any] = [
            "restaurant_Name": restaurantName,
            "userId": authService.getUserId() ?? "",
            "cuisines": selectedCuisine,
            "estimatedTime": Int(estimatedTime) ?? 30
        ]
        
        // Convert image to Base64
        if let restaurantImage = restaurantImage {
            // Process image to ensure it's not too large
            let maxSize: CGFloat = 600  // Reduced from 1200
            var processedImage = restaurantImage
            
            if max(restaurantImage.size.width, restaurantImage.size.height) > maxSize {
                let scale = maxSize / max(restaurantImage.size.width, restaurantImage.size.height)
                let newWidth = restaurantImage.size.width * scale
                let newHeight = restaurantImage.size.height * scale
                let newSize = CGSize(width: newWidth, height: newHeight)
                
                UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
                restaurantImage.draw(in: CGRect(origin: .zero, size: newSize))
                if let resizedImage = UIGraphicsGetImageFromCurrentImageContext() {
                    processedImage = resizedImage
                }
                UIGraphicsEndImageContext()
            }
            
            // Try to get JPEG data with very low compression quality (0.01 = 1%)
            if let imageData = processedImage.jpegData(compressionQuality: 0.01) {
                let base64String = imageData.base64EncodedString()
                formData["bannerPhoto64Image"] = base64String
                print("Image data size in form data: \(imageData.count) bytes")
            } else {
                print("Error: Failed to convert image to JPEG data")
            }
        }
        
        return formData
    }
    
    private func registerNewRestaurant(userId: String) {
        // Try the multipart approach first (better for large images)
        restaurantService.registerRestaurantWithMultipart(
            userId: userId,
            restaurantName: restaurantName,
            cuisine: selectedCuisine,
            estimatedTime: Int(estimatedTime) ?? 30,
            bannerImage: restaurantImage
        ) { result in
            self.isSubmitting = false
            
            switch result {
            case .success(let restaurantId):
                self.handleSuccessfulRegistration(userId: userId, restaurantId: restaurantId)
            case .failure(let error):
                // If the multipart endpoint is not available, fall back to the regular method
                print("Multipart registration failed: \(error.localizedDescription). Trying standard method...")
                
                // Fall back to regular registration
                self.registerWithStandardMethod(userId: userId)
            }
        }
    }
    
    private func registerWithStandardMethod(userId: String) {
        // Use RestaurantService to register the restaurant with the old method
        restaurantService.registerRestaurant(
            userId: userId,
            restaurantName: restaurantName,
            cuisine: selectedCuisine,
            estimatedTime: Int(estimatedTime) ?? 30,
            bannerImage: restaurantImage
        ) { result in
            self.isSubmitting = false
            
            switch result {
            case .success(let restaurantId):
                self.handleSuccessfulRegistration(userId: userId, restaurantId: restaurantId)
            case .failure(let error):
                self.showAlert(message: error.localizedDescription)
            }
        }
    }
    
    private func handleSuccessfulRegistration(userId: String, restaurantId: String) {
        // Update UserDefaults with the new restaurant ID
        UserDefaults.standard.set(restaurantId, forKey: "restaurant_id")
        UserDefaults.standard.set(true, forKey: "is_restaurant_registered")
        
        // Update the restaurant data in UserDefaults
        let restaurantData: [String: Any] = [
            "id": restaurantId,
            "name": self.restaurantName,
            "estimatedTime": Int(self.estimatedTime) ?? 30,
            "cuisine": self.selectedCuisine,
            "isRegistered": true
        ]
        
        if let encodedData = try? JSONSerialization.data(withJSONObject: restaurantData) {
            UserDefaults.standard.set(encodedData, forKey: "restaurant_data")
        }
        
        // Update the auth service with restaurant info
        let updatedUser = UserRestaurantProfile(
            id: userId,
            restaurantId: restaurantId,
            restaurantName: self.restaurantName,
            estimatedTime: Int(self.estimatedTime) ?? 30,
            cuisine: self.selectedCuisine,
            restaurantImage: self.restaurantImage
        )
        self.authService.currentUser = updatedUser
        
        // Update the data controller
        self.dataController.restaurant.id = restaurantId
        self.dataController.restaurant.name = self.restaurantName
        
        // Update the isRegistered state
        self.isRegistered = true
        
        self.showAlert(message: "Restaurant registered successfully")
    }
    
    private func updateRestaurantProfile() {
        // Prepare the form data
        let multipartFormData = createRestaurantFormData()
        
        // Send the API request
        submitRestaurantData(multipartFormData: multipartFormData)
    }
    
    private func submitRestaurantData(multipartFormData: [String: Any]) {
        // This is a simplified example. In a real app, use NetworkManager for this request
        guard let url = URL(string: NetworkManager.baseURL + "/register-restaurant") else {
            showAlert(message: "Invalid URL")
            isSubmitting = false
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: multipartFormData)
        } catch {
            showAlert(message: "Failed to prepare data: \(error.localizedDescription)")
            isSubmitting = false
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isSubmitting = false
                
                if let error = error {
                    self.showAlert(message: "Error: \(error.localizedDescription)")
                    return
                }
                
                guard let data = data else {
                    self.showAlert(message: "No data received")
                    return
                }
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        if let restaurantId = json["_id"] as? String {
                            // Update UserDefaults with the new restaurant ID
                            UserDefaults.standard.set(restaurantId, forKey: "restaurant_id")
                            UserDefaults.standard.set(true, forKey: "is_restaurant_registered")
                            
                            // Update the restaurant data in UserDefaults
                            let restaurantData: [String: Any] = [
                                "id": restaurantId,
                                "name": self.restaurantName,
                                "estimatedTime": Int(self.estimatedTime) ?? 30,
                                "cuisine": self.selectedCuisine,
                                "isRegistered": true
                            ]
                            
                            if let encodedData = try? JSONSerialization.data(withJSONObject: restaurantData) {
                                UserDefaults.standard.set(encodedData, forKey: "restaurant_data")
                            }
                            
                            // Update the auth service with restaurant info
                            if let userId = self.authService.getUserId() {
                                let updatedUser = UserRestaurantProfile(
                                    id: userId,
                                    restaurantId: restaurantId,
                                    restaurantName: self.restaurantName,
                                    estimatedTime: Int(self.estimatedTime) ?? 30,
                                    cuisine: self.selectedCuisine,
                                    restaurantImage: self.restaurantImage
                                )
                                self.authService.currentUser = updatedUser
                            }
                            
                            // Update the data controller
                            self.dataController.restaurant.id = restaurantId
                            self.dataController.restaurant.name = self.restaurantName
                            
                            // Update the isRegistered state
                            self.isRegistered = true
                            
                            self.showAlert(message: "Restaurant registered successfully")
                        } else if let success = json["success"] as? Bool, success {
                            self.showAlert(message: "Restaurant profile updated successfully")
                        } else if let message = json["message"] as? String {
                            self.showAlert(message: message)
                        } else {
                            self.showAlert(message: "Unknown server response")
                        }
                    }
                } catch {
                    self.showAlert(message: "Failed to parse response: \(error.localizedDescription)")
                }
            }
        }.resume()
    }
    
    private func showAlert(message: String) {
        alertMessage = message
        showAlert = true
    }
}

// MARK: - Styling
struct CardGroupBoxStyle: GroupBoxStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.content
            .background(Color(.systemBackground))
            .cornerRadius(8)
            .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 1)
    }
} 