//
//  LegalView.swift
//  Good Espresso
//
//  Legal disclaimers, terms of use, and privacy policy
//

import SwiftUI

struct LegalView: View {
    @Binding var isPresented: Bool
    @State private var hasScrolledToBottom = false
    @State private var hasAccepted = UserDefaults.standard.bool(forKey: "hasAcceptedLegal")

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Header
                        VStack(spacing: 12) {
                            Image(systemName: "doc.text.fill")
                                .font(.system(size: 50))
                                .foregroundStyle(.orange)

                            Text("Legal Information")
                                .font(.title2)
                                .fontWeight(.bold)

                            Text("Please read and accept the following terms")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.bottom)

                        // Disclaimer
                        LegalSection(title: "Disclaimer", icon: "exclamationmark.triangle") {
                            Text("""
                            IMPORTANT: Good Espresso is an independent, open-source application and is NOT affiliated with, endorsed by, or officially connected to Decent Espresso in any way.

                            This application is provided "AS IS" without warranty of any kind, express or implied. The developers make no representations or warranties regarding:

                            - The accuracy, reliability, or completeness of the app
                            - The compatibility with your specific Decent espresso machine
                            - The safety of operating your machine through this app
                            - Any damages that may result from using this app

                            USE AT YOUR OWN RISK. By using this application, you acknowledge that:

                            1. You are solely responsible for any actions taken with your espresso machine
                            2. Hot liquids and pressurized systems can cause burns and injuries
                            3. Improper use may damage your equipment
                            4. The developers are not liable for any damages, injuries, or losses
                            """)
                        }

                        // Safety Warnings
                        LegalSection(title: "Safety Warnings", icon: "flame") {
                            Text("""
                            CAUTION - ESPRESSO MACHINES OPERATE AT HIGH TEMPERATURES AND PRESSURES

                            - Water and steam can reach temperatures above 90\u{00B0}C (194\u{00B0}F)
                            - Always ensure the portafilter is properly locked before brewing
                            - Never leave the machine unattended during operation
                            - Keep children and pets away from the machine during use
                            - Allow components to cool before cleaning or maintenance
                            - Do not operate if the machine appears damaged
                            - Follow all manufacturer safety guidelines

                            THIS APP DOES NOT REPLACE THE OFFICIAL DECENT ESPRESSO APPLICATION. For critical operations or if you experience any issues, please use the official app from Decent Espresso.
                            """)
                        }

                        // Terms of Use
                        LegalSection(title: "Terms of Use", icon: "doc.plaintext") {
                            Text("""
                            By downloading, installing, or using Good Espresso, you agree to be bound by these terms:

                            1. LICENSE: This software is licensed under the MIT License. You may use, modify, and distribute it in accordance with that license.

                            2. NO WARRANTY: The software is provided without any warranty. We do not guarantee it will meet your requirements or operate uninterrupted.

                            3. LIMITATION OF LIABILITY: In no event shall the developers be liable for any indirect, incidental, special, consequential, or punitive damages.

                            4. THIRD-PARTY SERVICES: This app communicates with Decent espresso machines using their Bluetooth protocol. We are not responsible for any changes to that protocol.

                            5. UPDATES: We may update these terms at any time. Continued use of the app constitutes acceptance of any changes.

                            6. INDEMNIFICATION: You agree to indemnify and hold harmless the developers from any claims arising from your use of the app.
                            """)
                        }

                        // Privacy Policy
                        LegalSection(title: "Privacy Policy", icon: "hand.raised") {
                            Text("""
                            Good Espresso respects your privacy:

                            DATA COLLECTION:
                            - We do NOT collect any personal information
                            - We do NOT transmit any data to external servers
                            - All brewing data is stored locally on your device only
                            - No analytics or tracking is implemented

                            BLUETOOTH DATA:
                            - The app communicates directly with your Decent machine via Bluetooth
                            - No brewing data or machine information is sent to us or third parties
                            - Connection data remains between your device and your machine

                            LOCAL STORAGE:
                            - Shot history and preferences are stored locally using standard iOS storage
                            - You can delete all local data at any time through the Settings menu
                            - Uninstalling the app removes all stored data

                            PERMISSIONS:
                            - Bluetooth: Required to communicate with your Decent machine
                            - No other permissions are requested or used
                            """)
                        }

                        // Intellectual Property
                        LegalSection(title: "Intellectual Property", icon: "trademark") {
                            Text("""
                            TRADEMARKS:
                            "Decent Espresso", "DE1", "DE1+", and "DE1PRO" are trademarks of Decent Espresso. This application is not affiliated with or endorsed by Decent Espresso.

                            OPEN SOURCE:
                            Good Espresso is open-source software. The source code is available under the MIT License. Contributions are welcome.

                            THIRD-PARTY CONTENT:
                            Some brewing profiles may be inspired by or adapted from community contributions. All profile authors are credited where applicable.
                            """)
                        }

                        // Contact
                        LegalSection(title: "Contact", icon: "envelope") {
                            Text("""
                            For questions, concerns, or to report issues:

                            GitHub: https://github.com/goodespresso/app

                            This is a community-driven project. We welcome feedback and contributions from the espresso community.
                            """)
                        }

                        // Bottom marker for scroll detection
                        Color.clear
                            .frame(height: 1)
                            .id("bottom")
                            .onAppear {
                                hasScrolledToBottom = true
                            }

                        // Accept button area
                        VStack(spacing: 16) {
                            if !hasAccepted {
                                Text("Please scroll to read all terms before accepting")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .opacity(hasScrolledToBottom ? 0 : 1)
                            }

                            Button {
                                UserDefaults.standard.set(true, forKey: "hasAcceptedLegal")
                                hasAccepted = true
                                isPresented = false
                            } label: {
                                Text(hasAccepted ? "Close" : "I Accept These Terms")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.orange)
                            .disabled(!hasAccepted && !hasScrolledToBottom)
                        }
                        .padding(.vertical)
                    }
                    .padding()
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Legal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if hasAccepted {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") {
                            isPresented = false
                        }
                    }
                }
            }
            .interactiveDismissDisabled(!hasAccepted)
        }
    }
}

// MARK: - Legal Section
struct LegalSection: View {
    let title: String
    let icon: String
    let content: () -> Text

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(.orange)

                Text(title)
                    .font(.headline)
            }

            content()
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    LegalView(isPresented: .constant(true))
}
