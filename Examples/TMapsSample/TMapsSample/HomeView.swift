import SwiftUI
import TMaps

struct HomeView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("TMaps SDK")
                .font(.largeTitle.bold())
                .padding(.top, 48)
            Text("Two ways to put tmaps.tn on screen.")
                .font(.body)
                .foregroundStyle(.secondary)
                .padding(.top, 8)

            VStack(spacing: 16) {
                EntryCard(icon: "map.fill",
                          title: "Interactive map",
                          bodyText: "Pan, zoom, markers, polylines and your own location.",
                          entry: .map)
                EntryCard(icon: "cart.fill",
                          title: "Store page",
                          bodyText: "A still map used as a photo — showStatic() with every gesture off.",
                          entry: .store)
            }
            .padding(.top, 32)

            Spacer()
            Text("SDK \(TMaps.version)")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.bottom, 24)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.sand.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }
}

private struct EntryCard: View {
    let icon: String
    let title: String
    let bodyText: String
    let entry: Entry

    var body: some View {
        NavigationLink(value: entry) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(Color.onOliveContainer)
                    .frame(width: 48, height: 48)
                    .background(Color.oliveContainer, in: Circle())
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.headline).foregroundStyle(.primary)
                    Text(bodyText).font(.subheadline).foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").foregroundStyle(.tertiary)
            }
            .padding(20)
            .background(Color.sandContainer, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View { NavigationStack { HomeView() } }
}
