# Manual checks

Run `scripts/review-editor.sh` for nine native editor screenshots covering light and dark
appearance, narrow and short windows, backdrop presets, and color inspection. Open the
generated `build/editor-review/<timestamp>/index.html` to review them. Pass an output
directory as the first argument to keep a named review.

The script uses a Developer ID from the keychain when available. `SIGN_IDENTITY` and
`TEAM_ID` override signing. With existing Screen Recording access it captures the editor
and popover through ScreenCaptureKit. Otherwise it renders AppKit views without prompting
for permission. Each image identifies its capture method. AppKit rendering verifies layout
but cannot reproduce every system blur or shadow.

The screenshot test checks containment and control overlap. `EditorToolbarTests` also checks
balanced padding across resize thresholds and preset grid spacing. Screenshots need visual
review and are not pixel comparisons against an approved baseline.

OS behaviors a test would only mock, run before shipping a build.

1. Panel sits above a full-screen app (`fullScreenAuxiliary`).
2. Key events reach the non-activating panel: A, N, Cmd+Z, Cmd+Shift+Z, Enter, Cmd+C, Cmd+S, Esc.
3. Closing the editor returns focus to the previous app with no activation flicker.
4. A shot touching the menu bar opens at its exact screen position (the panel does not get
   pushed down by `constrainFrameRect`).
5. Hotkeys pressed while the editor is open or a capture is in flight do nothing.
6. A fresh Screen Recording grant shows `.grantedNeedsRelaunch` and the Relaunch button.
7. Area selection is dimmed on every display, clamped to the display where the drag starts,
   cursor is a crosshair, size label tracks the drag.
7a. The overlay shows the frozen screen: hover a link in a browser, press the hotkey, and the
    hover styling stays visible under the dim and lands in the shot. Same for a tooltip and an
    open menu. Moving the mouse during the drag changes nothing underneath.
7c. The overlay appears in one frame. The frozen screen must not zoom, fade or shift into
    place, which is what `animationBehavior = .none` prevents.
7d. Hovering a window in the overlay highlights it, and a click with no drag captures it.
    Starting a drag ignores the highlight.
7b. Guidelines follow the pointer before the drag. Shift during the drag squares the band,
    Space slides it, releasing Space resizes again from where it landed.
8. Esc, a tiny drag, and switching apps mid-drag all leave no overlay behind.
9. Window capture includes sheets and popovers and the system shadow.
9c. `⌘⇧E` captures the whole display the pointer is on, with no overlay and no flash.
9a. Holding Cmd while drawing an arrow flips it, live in the preview and in the commit.
9b. `B` then a drag hides an area. The saved PNG shows coarse cells there, not the original
    content, and zooming into the file cannot recover it.
9d. A full screen capture opens an editor that fits the screen, and dragging its edge resizes
    the shot with it. Annotations land where the pointer is at any size.
9e. Dragging the preview card drops a PNG into Finder and into a chat app. A click still opens
    the editor.
9f. Clicking the save HUD reveals the file in Finder.
9g. Changing the save folder, the after capture behaviour and the pointer toggle all take effect
    on the next capture with no relaunch.
10. Copy pastes at logical size in Preview (AppKit reader) and Slack (Chromium reader).
11. Saved file lands in `~/Pictures/Snimach`, never overwrites, and shows the HUD.
12. After a capture the plain shot pastes before the preview card finishes sliding in.
13. Preview card sits in the bottom-right corner of the shot's screen, above a full-screen app,
    and fades after about 5 s. Hovering keeps it, the cursor is a pointing hand, and the click
    opens the editor without moving focus to Snimach.
14. A hotkey while the card is up removes the card and the new shot does not contain it.

15. The editor keeps its frame when K toggles a backdrop. The stage transitions inside it,
    and Reduce Motion skips the transition. Resize to the minimum width and check that
    output actions remain visible and the active drawing tool stays beside the overflow menu.
16. Open backdrop presets, navigate with Tab or arrow keys, and select with Space. A selection
    enables the backdrop and closes the popover. Outside click and Escape dismiss it.
17. I overlays the color readout without resizing the image or window. The readout moves
    between the top and bottom when the pointer approaches, then stays still after selection. Hover
    previews a color. Click to freeze it, move across other pixels, and verify Copy still copies
    the selection. Clicking another pixel replaces it. ⌘C copies the hex without closing the
    editor, including when a button has focus. Tab navigates controls. Escape returns to drawing
    before discarding. Reentering inspection starts a fresh preview.
18. With a toolbar button focused, drawing shortcuts, undo, redo, copy and save still work.
    Controls and tooltips stay legible in light and dark appearance.
