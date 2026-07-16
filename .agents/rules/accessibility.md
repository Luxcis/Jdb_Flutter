# Accessibility (A11Y)

Ensure the app is usable by as many people as possible by following these accessibility guidelines:

- **Color Contrast:** Use high-contrast color combinations for text and backgrounds. Aim for at least a 4.5:1 contrast ratio for normal text (3:1 for large text) to meet accessibility standards.
- **Dynamic Text Scaling:** Verify that the UI remains readable and functional when users increase the system font size or use accessibility text-scaling features. (Test on devices/emulators with large font settings.)
- **Semantic Labels:** Use Flutter’s `Semantics` widget (and `semanticsLabel` on widgets like Image or Icon) to provide descriptive labels for UI elements, so screen readers can announce them properly.
- **Screen Reader Testing:** Regularly test the app with screen readers (TalkBack on Android, VoiceOver on iOS) to ensure that all interactive elements are reachable and that their labels and hints make sense.
