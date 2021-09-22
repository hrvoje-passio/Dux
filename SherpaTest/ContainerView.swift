//
//  ContainerView.swift
//  SherpaTest
//
//  Created by Jake Heiser on 9/21/21.
//

import SwiftUI

struct SkipButton: View {
    @EnvironmentObject var sherpa: SherpaGuide
    
    var body: some View {
        Button(action: quit) {
            Text("Skip")
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 5).fill(Color.white).shadow(radius: 1))
        }
        .padding(.trailing, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
    }
    
    func quit() {
        withAnimation {
            sherpa.stop()
        }
    }
}

struct SherpaContainerView<Content: View>: View {
    @StateObject private var guide = SherpaGuide()
    
    let content: Content
    let accessory: AnyView
    
    @State private var popoverSize: CGSize = .zero
    
    init<Accessory: View>(accessory: Accessory, @ViewBuilder content: () -> Content) {
        self.accessory = AnyView(accessory)
        self.content = content()
    }
    
    init(@ViewBuilder content: () -> Content) {
        self.init(accessory: EmptyView(), content: content)
    }
    
    var body: some View {
        content
            .environmentObject(guide)
            .overlayPreferenceValue(SherpaPreferenceKey.self, { all in
                SherpaOverlay(guide: guide, accessory: accessory, allRecordedItems: all, popoverSize: popoverSize, sherpaPublisher: guide.publisher)
            })
            .onPreferenceChange(CalloutPreferenceKey.self, perform: { popoverSize = $0 })
    }
}

struct SherpaOverlay: View {
    let guide: SherpaGuide
    let accessory: AnyView
    let allRecordedItems: SherpaPreferenceKey.Value
    let popoverSize: CGSize

    @ObservedObject var sherpaPublisher: SherpaPublisher
    
    var body: some View {
        ZStack {
            if guide.publisher.state == .transition {
                Color(white: 0.8, opacity: 0.4)
                    .edgesIgnoringSafeArea(.all)
                if let current = guide.current, let details = allRecordedItems[current] {
                    details.callout.createView(onTap: {}).opacity(0)
                }
            } else if guide.publisher.state == .active {
                if let current = guide.current,  let details = allRecordedItems[current] {
                    ActiveSherpaOverlay(details: details, guide: guide, popoverSize: popoverSize)
                }
            }
            if guide.publisher.state != .hidden {
                accessory.environmentObject(guide)
            }
        }
    }
}

struct ActiveSherpaOverlay: View {
    let details: SherpaDetails
    let guide: SherpaGuide
    let popoverSize: CGSize
    
    var body: some View {
        GeometryReader { proxy in
            CutoutOverlay(cutoutFrame: proxy[details.anchor], screenSize: proxy.size)
                .onTapGesture {
                    guide.advance()
                }

            touchModeView(for: proxy[details.anchor], mode: details.touchMode)

            details.callout.createView(onTap: guide.advance)
                .offset(
                    x: proxy[details.anchor].midX - popoverSize.width / 2,
                    y: details.callout.edge == .top ? proxy[details.anchor].minY - popoverSize.height : proxy[details.anchor].maxY
                )
        }.edgesIgnoringSafeArea(.all)
    }
    
    @ViewBuilder
    func touchModeView(for cutout: CGRect, mode: CutoutTouchMode) -> some View {
        switch mode {
        case .passthrough: EmptyView()
        case .advance:
            Color.black.opacity(0.05)
                .frame(width: cutout.width, height: cutout.height)
                .offset(x: cutout.minX, y: cutout.minY)
                .onTapGesture {
                    guide.advance()
                }
        case .custom(let action):
            Color.black.opacity(0.05)
                .frame(width: cutout.width, height: cutout.height)
                .offset(x: cutout.minX, y: cutout.minY)
                .onTapGesture {
                    action()
                }
        }
    }
}

struct CutoutOverlay: View {
    let cutoutFrame: CGRect
    let screenSize: CGSize
    
    var overlayFrames: [OverlayFrame] {
        return [
            .init(rect: .init(x: 0, y: 0, width: cutoutFrame.minX, height: screenSize.height)),
            .init(rect: .init(x: cutoutFrame.maxX, y: 0, width: screenSize.width - cutoutFrame.maxX, height: screenSize.height)),
            .init(rect: .init(x: cutoutFrame.minX, y: 0, width: cutoutFrame.width, height: cutoutFrame.minY)),
            .init(rect: .init(x: cutoutFrame.minX, y: cutoutFrame.maxY, width: cutoutFrame.width, height: screenSize.height - cutoutFrame.maxY))
        ]
    }
    
    var body: some View {
        ForEach(overlayFrames) { frame in
            Color(white: 0.8, opacity: 0.4)
                .frame(width: frame.rect.width, height: frame.rect.height)
                .offset(x: frame.rect.minX, y: frame.rect.minY)
        }
    }
}

struct OverlayFrame: Identifiable {
    let rect: CGRect
    
    var id: String {
        rect.debugDescription
    }
}

struct SherpaDetails {
    let anchor: Anchor<CGRect>
    let callout: Callout
    let touchMode: CutoutTouchMode
}

struct SherpaPreferenceKey: PreferenceKey {
    typealias Value = [String: SherpaDetails]
    
    static var defaultValue: Value = [:]
    
    static func reduce(value acc: inout Value, nextValue: () -> Value) {
        let newValue = nextValue()
        for (key, value) in newValue {
            acc[key] = value
        }
    }
}
