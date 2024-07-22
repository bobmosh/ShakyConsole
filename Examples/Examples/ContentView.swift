//
//  ContentView.swift
//  Examples
//
//  Created by Ferdinand Göldner on 15.04.23.
//

import SwiftUI
import ShakyConsole

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundColor(.accentColor)
            Text("Hello, world!")
        }
        .padding()
        .onAppear {
            Shaky.add(logger: ConsoleLogger())
            Shaky.log(value: "Debug", level: .Debug, tag: .Network)
            Shaky.log(value: "Warning", level: .Warning, tag: .Custom("Tick"))
            Shaky.log(value: "Critical", level: .Critical, tag: .Performance)
            Shaky.log(value: "Critical", level: .Critical, tag: .Performance)
            Shaky.log(value: "Critical", level: .Critical, tag: .Performance)
            Shaky.log(value: "Critical", level: .Critical, tag: .Performance)
            
            Task.detached {
                try await Task.sleep(nanoseconds: 1_000_000_000 * 10)
                Shaky.log(value: "Timed")
            }
        }
        .shaky(with: Shaky.shakyLogger)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
