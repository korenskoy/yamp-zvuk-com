import ZvukMusic

extension Track {
    var simplified: SimpleTrack {
        SimpleTrack(
            id: id, title: title, duration: duration,
            explicit: explicit, artists: artists, release: release
        )
    }
}
