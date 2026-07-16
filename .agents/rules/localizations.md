# Localizations

## Core Rule

**NEVER** hardcode static strings in the UI code. All user-facing text must be retrieved from the localization files.

❌ **Incorrect:**

```dart
Text('Hello World')
```

✅ **Correct:**

```dart
Text(context.l10n.helloWorld)
```

## How to Add New Wordings

1. **Add the key to `@lib/l10n/app_en.arb`**: This is the template file.
2. **Add the key to other `.arb` files**: Ensure the other supported locale files also have the new key. You should automatically propose a default translation if none is given.
3. **Run code generation**: Run `flutter gen-l10n` when you need to generate the new changes from the
   `*.arb` files.

## Naming Conventions

- **Keys**: Use `camelCase`.
- **Descriptive Names**: Keys should describe the content or the context (e.g., `welcomeTitle`, `errorGeneratingCard`).

## Usage in Code

We use a `BuildContext` extension to access localizations easily.

### Basic Usage

```dart
// Use inside a widget build method
Text(context.l10n.myNewString)
```

### With Placeholders

If your string needs dynamic values, define placeholders in the `.arb` file.

**In `app_en.arb`:**

```json
"welcomeUser": "Welcome, {name}!",
"@welcomeUser": {
  "placeholders": {
    "name": {
      "type": "String"
    }
  }
}
```

**In Dart:**

```dart
Text(context.l10n.welcomeUser('Alice'))
```

### Plurals

For counts (singular/plural), use the ICU plural format.

**In `app_en.arb`:**

```json
"itemCount": "{count, plural, =0{No items} =1{1 item} other{{count} items}}",
"@itemCount": {
  "placeholders": {
    "count": {
      "type": "int"
    }
  }
}
```

**In Dart:**

```dart
Text(context.l10n.itemCount(5)) // Output: "5 items"
```
