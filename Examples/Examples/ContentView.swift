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
            Shaky.log(value: "None", level: .None)
            Shaky.log(value: "Debug", level: .Debug)
            Shaky.log(value: "Warning", level: .Warning)
            Shaky.log(value: "Critical", level: .Critical, tag: .Network)
        }
        .shaky(with: Shaky.shakyLogger)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
