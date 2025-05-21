//
//  AboutView.swift
//  QSkipper
//
//  Created by Keshav Lohiya on 02/04/25.
//

import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("About QSkipper")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Spacer()
            }
            .padding()
            .background(Color(.systemBackground))
            
            // Divider
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 1)
            
            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // App info section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("QSkipper Admin")
                            .font(.title)
                            .fontWeight(.semibold)
                        
                        Text("Version 1.0")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("QSkipper is a comprehensive restaurant management platform designed to streamline operations for restaurant owners and staff. The admin panel provides easy management of menu items, orders, and restaurant information.")
                            .font(.body)
                            .foregroundColor(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                    
                    // Features section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Key Features")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        FeatureRow(icon: "building.2.fill", title: "Restaurant Management", description: "Update profile, hours, and contact information")
                        FeatureRow(icon: "cube.fill", title: "Product Management", description: "Add, edit, and remove menu items with prices and categories")
                        FeatureRow(icon: "bag.fill", title: "Order Management", description: "Process customer orders in real-time with status updates")
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                    
                    // Contact section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Contact Support")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        HStack {
                            Image(systemName: "envelope.fill")
                                .foregroundColor(.green)
                            Text("support@qskipper.com")
                                .font(.body)
                        }
                        
                        HStack {
                            Image(systemName: "phone.fill")
                                .foregroundColor(.green)
                            Text("(123) 456-7890")
                                .font(.body)
                        }
                        
                        Link(destination: URL(string: "https://qskipper.com")!) {
                            HStack {
                                Text("Visit our website")
                                Image(systemName: "arrow.right")
                            }
                            .foregroundColor(.green)
                            .font(.body)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                    
                    // Legal section
                    VStack(alignment: .leading, spacing: 10) {
                        Text("© 2023 QSkipper. All rights reserved.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 20) {
                            Link("Privacy Policy", destination: URL(string: "https://qskipper.com/privacy")!)
                                .font(.caption)
                                .foregroundColor(.blue)
                            
                            Link("Terms of Service", destination: URL(string: "https://qskipper.com/terms")!)
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                    .padding()
                }
                .padding()
            }
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 15) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.green)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct AboutView_Previews: PreviewProvider {
    static var previews: some View {
        AboutView()
    }
} 