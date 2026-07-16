# UI / UX

## Visual Design & Theming

- **UI Design:** Build a clean and intuitive UI that follows modern design guidelines and platform conventions.
- **Responsive Layout:** Ensure the UI is responsive and adapts to different screen sizes (the app should work well on both mobile and web).
- **Easy Navigation:** If the app has multiple screens, provide clear and easy navigation controls (like a navigation bar, drawer, or tabs as appropriate).
- **Typography Emphasis:** Use a clear typographic hierarchy. Employ larger or bolder text for headlines and titles, and standard text size for body content. Emphasize important words or phrases to guide the reader’s attention.
- **Backgrounds:** Use subtle background textures or patterns (sparingly) to give a premium feel, but ensure they don’t interfere with readability.
- **Shadows and Depth:** Use layered shadows to create depth. For example, cards and modals can have subtle drop shadows to appear elevated above the background.
- **Icons:** Use icons to enhance understanding and usability, but keep them consistent and intuitive.
- **Interactive Feedback:** For interactive elements (buttons, sliders, list items, etc.), use feedbacks. They should be visual like color or shadow changes to indicate hover, focus, or pressed states (creating a gentle “glow” or highlighting effect), and may also include haptics when appropriate.

## Theming

- **Central Theme:** Define a centralized `ThemeData` that specifies the app’s colors, fonts, and visual styles to ensure consistency.
- **Light & Dark Modes:** Support both light and dark themes. Provide a `ThemeData` for light (`theme`) and another for dark (`darkTheme`) in your `MaterialApp`. Use `ThemeMode` (system, light, or dark) to toggle between them.
- **ColorScheme.fromSeed:** Use `ColorScheme.fromSeed` to generate a harmonious color scheme from a single seed color for both light and dark themes.

  ```dart
  final ThemeData lightTheme = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.deepPurple,
      brightness: Brightness.light,
    ),
    // ... other theme properties like textTheme, iconTheme, etc.
  );

  final ThemeData darkTheme = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.deepPurple,
      brightness: Brightness.dark,
    ),
  );
  ```

## Assets and Images

- **Relevant Imagery**: Use images that add meaning or context. They should be appropriately sized and optimized. If final assets are unavailable, use placeholders.
- **Declare Assets**: List all image (and other) assets in the pubspec.yaml under the flutter/assets section so they are included in the app bundle. For example:

  ```yaml
  flutter:
    assets:
      - assets/images/
  ```

- **Local Images**: Use `Image.asset(...)` to display images included in the app bundle.
- **Network Images**: Use `Image.network(...)` (or a `NetworkImage` provider) to load images from the web. Consider using caching via packages like `cached_network_image` for better performance on network images.
- **Error/Loading Placeholders**: When using `Image.network`, provide a `loadingBuilder` to show progress (e.g., a spinner) and an `errorBuilder` to handle load failures (e.g., show an error icon or placeholder).

  ```dart
  Image.network(
    'https://example.com/image.png',
    loadingBuilder: (context, child, progress) {
      if (progress == null) return child;
      return Center(child: CircularProgressIndicator());
    },
    errorBuilder: (context, error, stack) {
      return Icon(Icons.error); // Show error indicator
    },
  );
  ```

- **Custom Icons**: For icons not included in Material/Cupertino sets, use your own asset images. You can display them with ImageIcon(AssetImage('assets/icons/my_icon.png')) or by using the Flutter IconGenerator to create a custom IconData.

## UI Theming and Styling Code

- **Responsiveness in Code:** Use widgets like `LayoutBuilder` or queries via `MediaQuery.of(context)` to adjust layouts based on screen size or orientation. This ensures your UI layout is flexible and doesn’t overflow on smaller screens.
- **Themed Text Styles:** Retrieve text styles from the active theme using `Theme.of(context).textTheme`. This ensures all text respects the global font styles and sizes defined in your theme. For example, use `Theme.of(context).textTheme.bodyMedium` for regular body text.
- **TextField Configuration:** Always configure text input fields for the expected input. For instance, set `textCapitalization` (e.g., `TextCapitalization.sentences` for sentence case inputs) and `keyboardType` (e.g., `TextInputType.emailAddress` for an email field) on `TextField` or `TextFormField` to optimize the user’s keyboard and input experience.
- **Image Error Handling:** When displaying images from the network using `Image.network`, make sure to handle failures gracefully by providing an `errorBuilder` (and similarly a `loadingBuilder` if needed). This prevents blank spaces or crashes if an image fails to load.

## Material Theming Best Practices

### Embrace ThemeData and Material 3

- **Use ColorScheme.fromSeed:** Utilize `ColorScheme.fromSeed` to generate a complete color scheme from a single seed color. This ensures a cohesive set of colors for light and dark themes.
- **Provide Light & Dark Themes:** Always supply both a `theme` (light theme) and a `darkTheme` in your `MaterialApp`. This enables the app to automatically switch based on system settings (or user preference) without additional code.
- **Centralize Component Styling:** Define theme properties for individual components (like `ElevatedButtonTheme`, `CardTheme`, `AppBarTheme`, etc.) in your `ThemeData`. This centralizes style definitions and keeps your widget code cleaner.
- **Theme Mode Toggle:** Use `ThemeMode` to dynamically control theme switching (light, dark, system). For example, you might use a `ChangeNotifier` to update `ThemeMode` when the user toggles a theme switch.

  ```dart
  MaterialApp(
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple, brightness: Brightness.light),
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontSize: 57, fontWeight: FontWeight.bold),
        bodyMedium: TextStyle(fontSize: 14, height: 1.4),
      ),
    ),
    darkTheme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple, brightness: Brightness.dark),
    ),
    themeMode: ThemeMode.system, // or .light, .dark based on user setting
    home: const MyHomePage(),
  );
  ```

### Implement Design Tokens with ThemeExtension

For design aspects that aren’t covered by Flutter’s built-in theming system, use a custom `ThemeExtension` to add your own theme properties (design tokens).

- **Define an Extension**: Create a class extending `ThemeExtension` to hold your custom theme values (colors, sizes, etc.).
- **Implement copyWith/lerp**: Provide a `copyWith` method and a `lerp` (linear interpolation) method for your extension to support theme animations and modifications.
- **Register the Extension**: Add an instance of your extension to the `extensions` list of your app’s `ThemeData`.
- **Use the Extension**: Retrieve your custom values in widgets by calling `Theme.of(context).extension<YourExtension>()`.

  ```dart
  // 1. Define the extension class
  @immutable
  class MyColors extends ThemeExtension<MyColors> {
    const MyColors({required this.success, required this.danger});

    final Color success;
    final Color danger;

    @override
    MyColors copyWith({Color? success, Color? danger}) {
      return MyColors(
        success: success ?? this.success,
        danger: danger ?? this.danger,
      );
    }

    @override
    MyColors lerp(ThemeExtension<MyColors>? other, double t) {
      if (other is! MyColors) return this;
      return MyColors(
        success: Color.lerp(success, other.success, t)!,
        danger: Color.lerp(danger, other.danger, t)!,
      );
    }
  }

  // 2. Register the extension in the theme
  final theme = ThemeData(
    extensions: <ThemeExtension<dynamic>>[
      const MyColors(success: Colors.green, danger: Colors.red),
    ],
  );

  // 3. Access the custom colors in a widget
  Color successColor = Theme.of(context).extension<MyColors>()!.success;
  ```

### Styling with MaterialStateProperty

- **MaterialStateProperty.resolveWith**: Use `MaterialStateProperty.resolveWith` to define dynamic values for different widget states. This provides a function that takes a set of `MaterialStates` (e.g., hovered, pressed, focused) and returns a value depending on whether a specific state is active.
- **MaterialStateProperty.all**: Use `MaterialStateProperty.all` when you want to provide a single value for all states (no state-specific variation). This is a shortcut for uniform styling.

  ```dart
  // Example: Button style that is red normally and green when pressed
  final ButtonStyle myButtonStyle = ButtonStyle(
    backgroundColor: MaterialStateProperty.resolveWith<Color>(
      (Set<MaterialState> states) {
        if (states.contains(MaterialState.pressed)) {
          return Colors.green; // Background color when pressed
        }
        return Colors.red;       // Background color for default (idle) state
      },
    ),
  );
  ```

## Layout Best Practices

### Building Flexible and Overflow-Safe Layouts

#### For Rows and Columns

- **Spacing:** Always prefer the `spacing` parameter over using `SizedBox`.
- **Expanded:** Use an `Expanded` widget inside a `Row` or `Column` to make a child widget fill the remaining available space along the main axis.
- **Flexible:** Use a `Flexible` widget when you want a child in a `Row` or `Column` to shrink or grow to fit the space (according to its `flex` factor), without necessarily taking all remaining space. Avoid using `Flexible` and `Expanded` together for the same parent.
- **Wrap:** Use a `Wrap` widget for horizontally or vertically repeating content that might overflow. It will automatically wrap child widgets to the next line (or column) when there isn’t enough space in one line.

#### For General Content

- **SingleChildScrollView:** Use this widget for a scrollable area when you have content that might extend beyond the screen, but is of a limited size (e.g., a settings form).
- **ListView / GridView:** For long lists or grids with a large (or infinite) number of children, use the constructor with a builder (`ListView.builder`, `GridView.builder`) to create widgets on demand as the user scrolls, instead of building them all at once.
- **FittedBox:** Use a `FittedBox` to scale down (or up) a child widget when the child’s size is larger than its parent. This can be useful for making text or images fit within a dynamic layout.
- **LayoutBuilder:** Use `LayoutBuilder` to get the constraints of its parent and build widgets dynamically based on the available space. This helps create responsive layouts that adapt to different screen sizes.

### Layering Widgets with Stack

- **Positioned:** Within a `Stack`, use `Positioned` to place a child widget at a specific position (using top/left/right/bottom offsets) relative to the stack’s bounds.
- **Align:** Alternatively, use an `Align` widget (or set the `alignment` property on the Stack child) to position a widget at a particular alignment (e.g., center, topRight) within the Stack without using explicit coordinates.

### Advanced Layout with Overlays

- **OverlayPortal:** (Using an overlay management package) The `OverlayPortal` widget can be used to show UI elements on top of everything else via the app’s overlay. This is useful for things like custom tooltips, dropdown menus, or pop-up dialogs that need to escape the normal widget hierarchy.

  ```dart
  class MyDropdown extends StatefulWidget {
    const MyDropdown({Key? key}) : super(key: key);

    @override
    State<MyDropdown> createState() => _MyDropdownState();
  }

  class _MyDropdownState extends State<MyDropdown> {
    final _overlayController = OverlayPortalController();

    @override
    Widget build(BuildContext context) {
      return OverlayPortal(
        controller: _overlayController,
        overlayChildBuilder: (context) {
          return const Positioned(
            top: 50,
            left: 10,
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(8.0),
                child: Text('I am an overlay!'),
              ),
            ),
          );
        },
        child: ElevatedButton(
          onPressed: _overlayController.toggle,
          child: const Text('Toggle Overlay'),
        ),
      );
    }
  }
  ```

In this example, pressing the button toggles an overlay entry (a card with text) at a specified position on the screen.

## Color Scheme Best Practices

### Contrast Ratios

- **Follow WCAG Guidelines:** Ensure text and UI elements meet accessibility contrast standards (WCAG 2.1). For example, aim for at least a 4.5:1 contrast ratio between body text and its background (3:1 for large text). This improves readability for all users, including those with visual impairments.

### Palette Selection

- **Primary vs Secondary vs Accent:** Establish a clear hierarchy for colors in your app. Typically, choose a primary color (dominant brand or theme color), a secondary color (used for accents or secondary actions), and an accent color (used sparingly to highlight important elements).
- **60-30-10 Rule:** A common design guideline is to use 60% one color (often a neutral or primary color for most of the UI), 30% a secondary color, and 10% an accent color. This creates a balanced and visually appealing palette distribution.

### Complementary Colors

- **Use Complementary Colors Sparingly:** Complementary colors (opposites on the color wheel) can make elements stand out, but they also clash if overused. Use them for accents or highlights, not for large areas of text or background.
- **Avoid Eye Strain:** Be cautious using complementary colors for foreground/background combinations, as they can cause visual fatigue. Opt for more subtle contrast for backgrounds behind long text.

### Example Palette

- **Primary:** `#0D47A1` – a dark blue (could serve as the primary brand color).
- **Secondary:** `#1976D2` – a medium blue for secondary elements.
- **Accent:** `#FFC107` – an amber accent color for highlights or call-to-action elements.
- **Neutral/Text:** `#212121` – a near-black color for primary text on light backgrounds.
- **Background:** `#FEFEFE` – an almost-white color for backgrounds.

## Font Best Practices

### Font Selection

- **Limit Families:** Keep font choices aligned with the families already defined by the project theme.
- **Legibility First:** Choose fonts optimized for screen readability. Sans-serif fonts are generally preferred for UI text due to their clarity on digital displays.
- **Use System Fonts:** Consider using the platform’s default fonts for a native look and potentially better performance (since they are already on the device).
- **Custom Web Fonts:** If custom fonts are needed, use the Google Fonts via the `google_fonts` package to easily include a wide range of open-source typefaces.

### Hierarchy and Scale

- **Establish a Typographic Scale:** Define a set of font sizes for different roles (e.g., large titles, section headings, body text, captions). Apply these consistently to maintain a clear hierarchy.
- **Weight for Emphasis:** Use font weight (bold, medium, light) to create emphasis or differentiate text importance, instead of relying only on size.
- **Color & Opacity:** Use text color (and opacity) strategically to de-emphasize less important text (for example, using a grey color for placeholder or secondary text). When changing a color's opacity, you should always use `.withValues(alpha)` instead of `.withOpacity()`.

### Readability

- **Line Height:** Use appropriate line height (leading) for text blocks—typically around 1.4–1.6 times the font size for body text—to ensure good readability.
- **Line Length:** Keep line lengths to about 45–75 characters per line for body text. Lines that are too long or too short can be hard to read.
- **Avoid All Caps:** Don’t use ALL CAPS for long paragraphs or sentences. It’s fine for short labels or acronyms, but all-caps text is harder to read in large blocks.

### Example Typographic Scale

```dart
// Example TextTheme setup in ThemeData
textTheme: const TextTheme(
  displayLarge: TextStyle(fontSize: 57.0, fontWeight: FontWeight.bold),
  titleLarge:  TextStyle(fontSize: 22.0, fontWeight: FontWeight.bold),
  bodyLarge:   TextStyle(fontSize: 16.0, height: 1.5),
  bodyMedium:  TextStyle(fontSize: 14.0, height: 1.4),
  labelSmall:  TextStyle(fontSize: 11.0, color: Colors.grey),
),
```
