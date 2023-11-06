//
//  LinkSpotifyBtn.swift
//  Mixboard
//
//  Created by Raghavasimhan Sankaranarayanan on 11/7/22.
//

import SwiftUI
import WebKit
import FirebaseAuth

struct LinkSpotifyBtn: View {
    var spotifyOAuth: SpotifyOAuth
    
    @State private var showWebView = false
    
    @State private var loadCount: Int = 0
    
    var body: some View {
        Button {
            showWebView.toggle()
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .foregroundColor(.accentColor)
                    .shadow(radius: 2, x: 2, y: 2)
                
                HStack {
                    Text("Link").foregroundColor(.green)
                    Image("SpotifyLogo").resizable().renderingMode(.original).scaledToFit().frame(height: 24)
                }
            }
        }.sheet(isPresented: $showWebView) {
            WebView(url: spotifyOAuth.getAuthUrl()) { urlString in
                if let urlString = urlString {
                    if let code = spotifyOAuth.parseResponseCode(urlString: urlString) {
                        spotifyOAuth.exchangeAccessToken(forCode: code) { accessToken in
                            if let _ = accessToken {
                                SpotifyManager.shared.isLinked = true
                            }
                        }
                    }
                }
                showWebView = false
            }
            .ignoresSafeArea()
        }
    }
}

/// Represents the UIVIEW that wraps WKWebView.
/// Adapted from: `https://medium.com/geekculture/how-to-use-webview-in-swiftui-and-also-detect-the-url-21d4fab2a9c1`
struct WebView: UIViewRepresentable {
    
    var url: URL?
    
    var didFinishAuthenticating: (String?) -> ()
        
    func makeUIView(context: Context) -> WKWebView {
        let wkWebView = WKWebView()
        wkWebView.navigationDelegate = context.coordinator
        if let url = url {
            let request = URLRequest(url: url)
            wkWebView.load(request)
        }
        return wkWebView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
    }
    
    func makeCoordinator() -> WebViewCoordinator {
        WebViewCoordinator(self)
    }
    
    class WebViewCoordinator: NSObject, WKNavigationDelegate {
        var parent: WebView
        
        init(_ parent: WebView) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            
            if let url = navigationAction.request.url?.absoluteString {
                if url.starts(with: Config.SPOTIFY_REDIRECT_URL) {
                    parent.didFinishAuthenticating(url)
                }
            }
            decisionHandler(.allow)
        }
        
    }
}

//struct LinkSpotifyBtn_Previews: PreviewProvider {
//    static var previews: some View {
//        LinkSpotifyBtn()
//    }
//}
