MacByeDPI

MacByeDPI is a simple macOS GUI wrapper for SpoofDPI.

The app allows you to start, stop, and check SpoofDPI from a native macOS SwiftUI interface.

Features

* Start and stop SpoofDPI from a macOS app
* DNS mode selection: Auto, System, HTTPS, UDP
* Proxy check button
* Built with SwiftUI
* Uses SpoofDPI as the backend engine

Requirements

* macOS
* Xcode
* Homebrew
* SpoofDPI

Installation for development

Install SpoofDPI:

brew install spoofdpi

Clone the repository:

git clone https://github.com/yourusername/MacByeDPI.git
cd MacByeDPI

Open the project in Xcode and run it.

How it works

MacByeDPI starts SpoofDPI with a local proxy on:

127.0.0.1:8080

The app can automatically configure the system network proxy using SpoofDPI.

Current status

This project is an early MVP.

Working features:

* Start SpoofDPI
* Stop SpoofDPI
* Select DNS mode
* Check proxy availability

Planned features:

* Better UI
* Menu bar mode
* Auto start
* App icon
* DMG release
* Bundled SpoofDPI binary

License

MIT
typachill
