import SwiftUI

/// A page of the root TabView, leading to trailing.
enum MatchPage: Hashable {
    case controls, live
}

/// The root TabView of a current Match: two horizontally paging pages: the controls page leading, live scoring trailing and selected on
/// entry. A mid-rally tap cannot reach End match: paging needs a drag, the controls page takes no
/// area from either half, and it never lies in wait, because the page snaps back to live whenever
/// the display dims or goes inactive.
struct MatchPagesView: View {
    let record: MatchRecord
    @State private var page = MatchPage.live
    /// Bumped by each page change made in view, to flash the page indicator.
    @State private var indicatorFlash = 0
    @State private var isIndicatorShown = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    var body: some View {
        TabView(selection: $page) {
            ControlsPageView(record: record, page: $page)
                .tag(MatchPage.controls)
            LiveScoringView(record: record, isPrimaryActionEnabled: page == .live)
                .tag(MatchPage.live)
        }
        // The system indicator overlays without moving the halves, but it stays at rest, so it is
        // replaced by one that fades in as the page lands and out again.
        .tabViewStyle(.page(indexDisplayMode: .never))
        .overlay(alignment: .bottom) {
            PageIndicator(page: page)
                .opacity(isIndicatorShown ? 1 : 0)
        }
        .onChange(of: page) {
            // Not for the snap-back as the display dims: nothing animates in Always On.
            guard scenePhase == .active, !isLuminanceReduced else { return }
            indicatorFlash += 1
        }
        .task(id: indicatorFlash) {
            guard indicatorFlash > 0 else { return }
            withAnimation(.easeIn(duration: 0.15)) { isIndicatorShown = true }
            try? await Task.sleep(for: .seconds(1))
            withAnimation(.easeOut(duration: 0.4)) { isIndicatorShown = false }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { returnToLive() }
        }
        .onChange(of: isLuminanceReduced) { _, isDimmed in
            if isDimmed { returnToLive() }
        }
    }

    /// Without animation, since the display is dimming or going inactive: nothing animates in
    /// Always On.
    private func returnToLive() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            isIndicatorShown = false
            page = .live
        }
    }
}

/// Two dots, the selected page's lit. An overlay only: it takes no part in layout and no taps, so
/// nothing moves under a blind tap.
private struct PageIndicator: View {
    let page: MatchPage

    var body: some View {
        HStack(spacing: 5) {
            ForEach([MatchPage.controls, .live], id: \.self) { dot in
                Circle()
                    .fill(.white.opacity(dot == page ? 1 : 0.35))
                    .frame(width: 6, height: 6)
            }
        }
        .padding(.bottom, 6)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// The controls page: one large centred End match button and nothing else, in neutral chrome. It
/// never carries the Double Tap shortcut, so Double Tap does nothing here. Once the Match is
/// Decided, End match no longer applies and the button is disabled.
private struct ControlsPageView: View {
    let record: MatchRecord
    @Binding var page: MatchPage
    @State private var isConfirmingEnd = false
    @Environment(\.workout) private var workout

    var body: some View {
        Button {
            if record.endNeedsConfirmation {
                isConfirmingEnd = true
            } else {
                record.abandon(workout: workout)
            }
        } label: {
            Text("End match")
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 88)
        }
        .tint(.white)
        .disabled(!record.canEnd)
        .padding(.horizontal)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .confirmationDialog("End match?", isPresented: $isConfirmingEnd, titleVisibility: .visible) {
            Button("Save") { record.endAndSave() }
            // The only red in the app: the system's destructive role.
            Button("Discard", role: .destructive) { record.abandon(workout: workout) }
            Button("Cancel", role: .cancel) {}
        }
        // However the dialog closes, Cancel included, it returns to the live page rather than here,
        // so a dimmed screen is always the live page.
        .onChange(of: isConfirmingEnd) { _, isConfirming in
            if !isConfirming { page = .live }
        }
        // The dialog goes with the page, so a dimmed screen never holds Save or Discard.
        .onChange(of: page) { _, page in
            if page != .controls { isConfirmingEnd = false }
        }
    }
}
