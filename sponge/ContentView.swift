//
//  ContentView.swift
//  sponge
//
//  Created by Jeff on 9/25/25.
//

import SwiftUI

struct ContentView: View {
    private let instructions = [
        "Install the Mock keyboard in your Settings app.",
        "Head to General → Keyboard → Keyboards → Add New Keyboard…",
        "Find “Mock Keyboard” under Third-Party Keyboards and tap Add.",
        "Back on the Keyboards list, tap Mock Keyboard and allow Full Access so the mock key can edit text.",
        "Switch to the Mock keyboard the next time the system keyboard is up, then press “Mock” to remix your last word."
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Mock Keyboard")
                            .font(.largeTitle)
                            .bold()

                        Text("Flip the last thing you typed into ransom-case meme text with a single tap.")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Get Set Up")
                            .font(.headline)

                        ForEach(Array(instructions.enumerated()), id: \.offset) { index, message in
                            HStack(alignment: .top, spacing: 12) {
                                Text("\(index + 1)")
                                    .font(.callout)
                                    .fontWeight(.semibold)
                                    .frame(width: 24)
                                    .padding(.top, 2)

                                Text(message)
                                    .font(.body)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("How It Works")
                            .font(.headline)

                        Label("Tap the “Mock” key to randomize the casing of the word right before the cursor.", systemImage: "wand.and.stars")
                        Label("The keyboard leaves punctuation in place and puts back any trailing spaces you already typed.", systemImage: "text.insert")
                        Label("Use the “Next” button anytime you want to jump back to another keyboard.", systemImage: "arrow.left.arrow.right")
                    }

                    Spacer(minLength: 0)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("Welcome")
        }
    }
}

#Preview {
    ContentView()
}
