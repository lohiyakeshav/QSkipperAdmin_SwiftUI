import SwiftUI
import Combine
import PhotosUI
// Import the UIKitImagePicker
import UIKit

struct RestaurantManagementView: View {
    // Environment
    @EnvironmentObject private var dataController: DataController
    @EnvironmentObject private var authService: AuthService
    
    // State
    @State private var restaurantName: String = ""
    @State private var estimatedTime: String = "30"
    @State private var selectedCuisine: String = "North Indian"
    @State private var restaurantImage: UIImage? = nil
    @State private var isImagePickerShown = false
    
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
        .navigationTitle("Restaurant Profile")
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
            Button(action: submitRestaurantProfile) {
                HStack {
                    if isSubmitting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    }
                    Text("Save Changes")
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
    
    // MARK: - Methods
    private func loadRestaurantData() {
        if !dataController.restaurant.name.isEmpty {
            restaurantName = dataController.restaurant.name
        }
        
        // Load other restaurant data if available
        // Note: In a complete implementation, you would load all restaurant data here
    }
    
    private func submitRestaurantProfile() {
        guard validateRestaurantFields() else { return }
        
        isSubmitting = true
        
        // Prepare the form data
        let multipartFormData = createRestaurantFormData()
        
        // Send the API request
        submitRestaurantData(multipartFormData: multipartFormData)
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
            "userId": dataController.currentUser.id,
            "cuisines": selectedCuisine,
            "estimatedTime": Int(estimatedTime) ?? 30
        ]
        
        // Convert image to Base64
        if let restaurantImage = restaurantImage, 
           let imageData = restaurantImage.jpegData(compressionQuality: 0.7) {
            let base64String = imageData.base64EncodedString()
            formData["bannerPhoto64Image"] = base64String
        }
        
        return formData
    }
    
    private func submitRestaurantData(multipartFormData: [String: Any]) {
        // This is a simplified example. In a real app, use NetworkManager for this request
        guard let url = URL(string: NetworkManager.baseURL + "/resturant-register") else {
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
                        if let success = json["success"] as? Bool, success {
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