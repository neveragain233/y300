# Changelog

## Local modifications (Y300)

2026-11-17, `lib/popup.dart` only, against
`63450c0ac0e8e1b2c0f3ed4ad7926dc94e083185`. The Y300 client wraps
`PopupAnchor` + `PopupMenu` as its application menu. Four additive changes
keep that wrapper's existing contract; unset, each leaves upstream behaviour
unchanged:

- `PopupMenuItem` takes an optional `key`, set on the row that shows the item,
  and an optional `leading` widget drawn where `glyph` goes and tinted with the
  row's foreground color. A host can key menu actions for tests and use app
  icons the glyph set does not cover.
- `PopupMenu` takes an optional `onWillSelect`, called as a row is picked and
  before the popup closes, so a host can tell a pick from a dismissal without
  waiting for the item's action.
- `PopupAnchor` and `AnchoredPopupRoute` take `blursContent`; off, labels and
  icons stay sharp through the open and return morphs. Y300 menus first turned
  it off; the second batch restores the upstream blur (see below).
- `PopupAnchor` and `AnchoredPopupRoute` take `runsPickedAfterReturn`; off, a
  picked item runs as soon as the popup is popped, as a Material menu's
  `onSelected` does, instead of after the return morph. Y300 menus turn it off
  so actions answer without waiting for the animation to settle.

2026-11-17, `lib/popup.dart` only, against
`63450c0ac0e8e1b2c0f3ed4ad7926dc94e083185`, a second additive change on top of
the four above:

- `PopupAnchor` and `AnchoredPopupRoute` take `theme`, the prism theme the
  popup's own surface paints with. The platter, its glass, its shadows and its
  source color are built in `buildTransitions`, above the host's content, so a
  host whose prism theme is mounted below the navigator — as Y300 mounts it per
  widget rather than at the root — had that shell fall back to the library's
  default light theme while the content beside it used the host's. In a dark
  theme the opening platter therefore showed as a white disc before the card
  arrived. Unset, the popup reads the surrounding theme as before; Y300 passes
  its app theme's color scheme, which also removes the flash on the first
  frames of the open morph.

2026-11-17, `lib/popup.dart` only, against
`63450c0ac0e8e1b2c0f3ed4ad7926dc94e083185`, a third additive change on top of
the five above:

- `PopupAnchor` and `AnchoredPopupRoute` take `reduceMotion`. On, the popup has
  no transition duration in either direction and takes no source snapshot, so
  it appears and disappears where it stands, without the morph or the content
  blur, while the control stays visible throughout. Unset, the popup animates
  as before. Y300 passes the platform's reduced-motion setting, which its
  interface refresh plan requires for menus.

2026-11-17, `lib/navigation_dock.dart` only, against 0.1.2. The Y300 client
replaces its self-drawn selection capsule with `FloatingNavigationBar`, so the
bar takes the client's own widgets and submission rules without forking it:

- `NavigationDockDestination` takes optional `key`, `icon` and `selectedIcon`
  widgets in place of the `glyph`; the glyph path still draws as before, and a
  destination needs one of the two.
- `NavigationDock` and `FloatingNavigationBar` take `commitOnDrag`,
  `projectVelocity`, `dragFromSelection` and `reduceMotion`. The defaults keep
  the library's behaviour; Y300 turns velocity projection off, starts drags
  from the selection, and follows the platform's reduced-motion setting. A bar
  that never commits a drag also never slides the lens or clicks on a drag, so
  taps stay its only input.
- A press that is overtaken by a changed selection, member list or mode is
  cancelled instead of committing the previous arrangement, and a pointer
  route that outlives the bar cannot reach its disposed springs.
- Destination slots stretch to the bar's height so each one keeps the client's
  48 dp target; `FloatingNavigationBar.minimumWidthFor` reports the narrowest
  bar that keeps every destination that wide.
- The copy of the destinations drawn over a lifted lens paints its label as a
  rich text paragraph: that copy is decorative and must not stand beside the
  destination's own label as a second text widget.

## 0.1.2

`OpenContainer` takes a `transition`, push by default or zoom.

## 0.1.1

Install from pub.dev in the README.

## 0.1.0

First release. No native code: read system colors in the app and pass them in as seeds.
