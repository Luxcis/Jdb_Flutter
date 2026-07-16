# Documentation

- **Use dartdoc:** Write API documentation using Dart’s standard `///` doc comments for all public classes, methods, fields, etc.

## Documentation Philosophy

- **Explain Why, Not What:** In comments, focus on why the code exists or why a certain approach was taken, rather than describing what the code is doing line-by-line. (The code itself should make the “what” clear.)
- **User-Focused Docs:** Always consider what a user of your code might need to know. If you had a question during development and discovered the answer, add that explanation to the docs in the place someone would likely look for it.
- **No Redundant Comments:** Avoid writing documentation that simply restates the obvious (for example, don’t write “Adds two numbers” for a function named `addTwoNumbers`). Instead, provide insight or cover edge cases that aren’t immediately apparent from the code.
- **Consistency:** Use consistent terminology and style in documentation across the project to avoid confusion.

## Commenting Style

- **Triple Slash (`///`):** Always use `///` for documentation comments so tools like dartdoc can pick them up.
- **One-Line Summary:** Begin each doc comment with a concise one-line summary of the entity’s purpose. End this sentence with a period.
- **Blank Line After Summary:** Follow the initial summary line with a blank line, then additional details if needed. This helps generate clean documentation excerpts.
- **Avoid Redundancy:** Don’t include information in the comment that can be inferred from the code context (such as the type of a parameter, or repeating the class name).
- **Getters/Setters:** If a property has both a getter and setter, document it on either the getter or the setter (not both), since tools will display that documentation for the property.

## Writing Style

- **Be Brief:** Use clear and concise language. Omit unnecessary words.
- **Avoid Jargon:** Use simple terms over jargon or abbreviations (unless they are well-known in context).
- **Minimal Markdown:** Use Markdown formatting sparingly within comments. Avoid HTML in comments; stick to Markdown for lists, code blocks, etc.
- **Inline Code Blocks:** Use backticks for inline code and fenced code blocks for longer code examples, and specify the language for syntax highlighting.

## What to Document

- **Public API Surface:** Document all public APIs — classes, enums, typedefs, public methods, and properties — so users of the code understand how to use them.
- **Important Private Elements:** Consider adding comments to complex private functions or classes, especially if they involve non-trivial logic, to aid future maintainers.
- **Library Overview:** At the top of Dart files (libraries), include a documentation comment summarizing the library’s purpose and contents if it’s not obvious.
- **Usage Examples:** Provide code examples in the documentation for how to use complex APIs or to illustrate common use cases.
- **Parameters and Returns:** For functions or methods, describe the purpose of parameters, return values, and exceptions/errors that can be thrown.
- **Order of Comments:** Place the documentation comment immediately above the declaration it describes, and before any annotations (like `@override` or metadata).
