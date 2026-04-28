# Research: Flutter Syntax Highlighting Packages for Response Body Rendering

- **Query**: Flutter syntax highlighting packages and approaches for rendering JSON/HTML/XML code with syntax highlighting
- **Scope**: Mixed (internal codebase analysis + external package comparison)
- **Date**: 2026-04-28

## Findings

### Current Codebase State

The app renders HTTP request/response bodies as plain monospace text inside `_CollapsibleBody` widget.

| File Path | Description |
|---|---|
| `lib/features/dev_tools/request_logger/presentation/widgets/request_log_detail_placeholder.dart` | Contains `_CollapsibleBody` (line 388-624) which renders body text via `SelectableText` with `fontFamily: 'monospace'` |
| `lib/features/dev_tools/request_logger/data/utils/body_serializer.dart` | Serializes response bodies; already uses `jsonEncode` for Map/List, preserves content-type info |
| `lib/features/dev_tools/request_logger/domain/entities/request_log_entry.dart` | `RequestLogEntry` entity; `responseBody` is `String?` (already serialized) |

**Current rendering pattern** (line 429-432 of `request_log_detail_placeholder.dart`):
```dart
SelectableText(
  body,
  style: theme.textTheme.bodySmall?.copyWith(
    fontFamily: 'monospace',
    height: 1.4,
  ),
),
```

**Key constraint**: The widget already uses `SelectableText` for text selection. Any solution must preserve selectable text behavior.

---

### Package Comparison Table

| Package | Version | Last Update | SDK Constraint | Languages | Selection Support | Approach | Dependencies | Notes |
|---|---|---|---|---|---|---|---|---|
| **re_highlight** | 0.0.3 | Recent (2024) | `>=2.17.0 <4.0.0` | 196 languages (JSON, XML, HTML via xml, etc.) | YES - outputs `TextSpan` usable with `SelectableText.rich()` or `TextEditingController` | Pure Dart port of highlight.js v11.9.0; outputs `TextSpan` via `TextSpanRenderer` | `flutter`, `path`, `collection` | By Reqable team; actively maintained; already cached locally |
| **syntax_highlight** | 0.5.0 | Recent (Serverpod) | `>=3.0.5 <4.0.0` | 15 languages (JSON, HTML, CSS, Dart, Go, Java, JS, Kotlin, Python, Rust, SQL, Swift, TS, YAML) | YES - via `CodeEditorController` (extends `TextEditingController`) or raw `TextSpan` output | TextMate grammar-based (VSCode-style); outputs `TextSpan` via `Highlighter.highlight()` | `flutter`, `collection`, `string_scanner`, `super_clipboard` | By Serverpod team; good quality; requires async init to load grammar assets; **heavy dependency on `super_clipboard`** and `super_native_extensions` |
| **highlight** | 0.7.0 | 2021 (stale) | `>=2.12.0 <3.0.0` | 100+ languages | NO direct Flutter support - outputs HTML or Node tree | Pure Dart syntax parser; basis for `flutter_highlight` | `collection` | **Effectively abandoned** (last release 2021); SDK constraint `<3.0.0` but still resolves |
| **flutter_highlight** | 0.7.0 | 2021 (stale) | `>=2.12.0 <3.0.0` | 100+ (via highlight) | **NO** - uses `RichText` which is NOT selectable | Flutter widget wrapper around `highlight` | `flutter`, `highlight` | Same abandonment issue; widget uses `RichText` not `SelectableText` |
| **flutter_code_editor** | 0.3.5 | Active (Akvelon) | `>=2.17.0 <4.0.0` | 100+ (via flutter_highlight) | YES - full editing via `CodeController`/`CodeField` | Full code editor with folding, autocomplete | Heavy: `flutter_highlight`, `highlight`, `autotrie`, `linked_scroll_controller`, etc. | Overkill for read-only syntax display; many dependencies |

---

### Detailed Analysis of Top Candidates

#### 1. re_highlight (Recommended)

**Strengths**:
- Outputs `TextSpan` natively via `TextSpanRenderer` -- works directly with `SelectableText.rich()` or a custom `TextEditingController`
- 196 languages (JSON, XML, and uses XML mode for HTML -- this is the same approach highlight.js uses)
- 73 built-in themes including `githubTheme`, `githubDarkTheme`, `atomOneDarkTheme`, etc.
- Pure Dart, no native dependencies, no asset loading required
- Synchronized with highlight.js v11.9.0 and passes all test cases
- Lightweight: only depends on `flutter`, `path`, `collection`
- Zero async initialization required

**Weaknesses**:
- Version 0.0.3 suggests early-stage package
- No dedicated `SelectableText` widget provided -- need to wire up `TextSpan` manually (but this is trivial)
- No dedicated HTML language mode (uses XML mode, which is standard for HTML in highlight.js ecosystem)

**Integration pattern** (from source code analysis):
```dart
import 'package:re_highlight/re_highlight.dart';
import 'package:re_highlight/languages/json.dart';
import 'package:re_highlight/languages/xml.dart';
import 'package:re_highlight/styles/github.dart';

// Setup (can be done once and reused)
final highlight = Highlight();
highlight.registerLanguage('json', langJson);
highlight.registerLanguage('xml', langXml);

// Per-render
final result = highlight.highlight(code: bodyText, language: 'json');
final renderer = TextSpanRenderer(baseStyle, githubTheme);
result.render(renderer);
final TextSpan? span = renderer.span;

// Use with SelectableText.rich
SelectableText.rich(span!, style: baseStyle);
```

**Or via TextEditingController** (for editable fields, from example):
```dart
class CodeThemeController extends TextEditingController {
  @override
  TextSpan buildTextSpan({...}) {
    final result = _highlight.highlightAuto(text, languages);
    final renderer = TextSpanRenderer(style, theme);
    result.render(renderer);
    return renderer.span ?? super.buildTextSpan(...);
  }
}
```

#### 2. syntax_highlight

**Strengths**:
- TextMate grammar-based (VSCode quality highlighting)
- Built-in `CodeEditor` widget with line numbers and selection
- Bracket colorization (nice for JSON/XML)
- By Serverpod team (well-funded, professional)
- Explicit JSON and HTML grammar support
- Auto light/dark theme switching via `HighlighterTheme.loadForBrightness()`

**Weaknesses**:
- Requires async initialization (`await Highlighter.initialize([...])`) -- must load grammar JSON assets at startup
- Only 15 languages (sufficient for our use case: JSON, HTML, XML not directly but HTML grammar handles it)
- **Heavy dependency chain**: pulls in `super_clipboard`, `super_native_extensions`, `device_info_plus`, `irondash_engine_context`, `irondash_message_channel`, `pixel_snap` -- these add native platform code and complexity
- Asset files must be bundled (grammars/*.json, themes/*.json)
- For read-only display, the `CodeEditor` is unnecessary overhead; using just `Highlighter.highlight()` to get `TextSpan` is the minimal approach but still requires the dependency chain

#### 3. highlight + flutter_highlight (NOT recommended)

**Critical issues**:
- **Effectively abandoned** since 2021 (4+ years without update)
- SDK constraint `<3.0.0` is outdated (still resolves but risky)
- `flutter_highlight`'s `HighlightView` uses `RichText` which does NOT support text selection
- Would need to write custom widget to use `SelectableText.rich` with the highlight output
- The underlying `highlight` package outputs a Node tree (not TextSpan directly), requiring conversion code

#### 4. flutter_code_editor (NOT recommended for this use case)

**Why not**:
- Full code editor is overkill for read-only syntax display
- Heavy dependency chain (flutter_highlight, highlight, autotrie, linked_scroll_controller, etc.)
- Inherits the stale highlight/flutter_highlight underneath
- Designed for editing, not viewing

---

### Lightweight Alternative: Manual JSON/XML Highlighting (No Package)

For our specific use case (primarily JSON, secondarily HTML/XML), a custom solution is viable:

**JSON**: Dart's `dart:convert` `JsonEncoder` already pretty-prints. We could parse JSON into tokens (strings, numbers, booleans, null, keys, brackets) and build a `TextSpan` tree manually. This is ~100-200 lines of code.

**XML/HTML**: More complex; regex-based tokenization for tags, attributes, content is doable but fragile.

**Trade-off**: Avoids any third-party dependency but requires maintenance. Only worth it if JSON-only is sufficient and we never need more languages.

---

### Selection Support Analysis

| Approach | SelectableText Support | Implementation Complexity |
|---|---|---|
| `re_highlight` TextSpan + `SelectableText.rich()` | Full support | Low (5-10 lines to wire up) |
| `syntax_highlight` Highlighter.highlight() + `SelectableText.rich()` | Full support | Low (but heavy deps) |
| `re_highlight` TextSpan + `TextEditingController` | Full support (editable) | Medium |
| `flutter_highlight` HighlightView | **NOT selectable** | N/A |
| Manual JSON parser + `SelectableText.rich()` | Full support | Medium |

---

### Recommended Approach

**Primary recommendation: `re_highlight`**

Rationale:
1. **Selection support**: Outputs `TextSpan` that works directly with `SelectableText.rich()` -- exactly what the current codebase needs
2. **Minimal dependencies**: Only `flutter`, `path`, `collection` -- no native code, no asset loading
3. **No async init**: Can create and use immediately, no startup cost
4. **196 languages**: Far more than needed, but JSON and XML are first-class citizens
5. **73 themes**: Can pick a theme that matches MD3 dark/light modes (e.g., `githubTheme` / `githubDarkTheme`)
6. **Modern codebase**: Synced with highlight.js v11.9.0, actively used by Reqable (a commercial HTTP debugging tool -- exactly our use case)
7. **Dart SDK compatible**: `>=2.17.0 <4.0.0` covers our `^3.10.4`

**Implementation sketch** for `_CollapsibleBody`:
1. Add `re_highlight: ^0.0.3` to `pubspec.yaml`
2. Create a utility function `buildHighlightedTextSpan(String body, String language, TextStyle baseStyle, Map<String, TextStyle> theme)` that returns a `TextSpan`
3. Detect content type from response headers or body structure to determine language
4. Replace `SelectableText(body, style: baseStyle)` with `SelectableText.rich(highlightedSpan, style: baseStyle)`
5. Theme selection: use `githubTheme` for light mode, `githubDarkTheme` for dark mode (or `atomOneDarkTheme`)

---

### Gotchas and Limitations

1. **No HTML language in re_highlight**: HTML is handled via the `xml` language mode (same as highlight.js). This works well for HTML tags/attributes but may not highlight inline JavaScript/CSS embedded in HTML. For our dev-tools use case, this is acceptable.

2. **Performance with large bodies**: `re_highlight` runs synchronously. For very large response bodies (100KB+), the highlight parsing could cause jank. Mitigation options:
   - Skip highlighting for bodies exceeding a size threshold (e.g., 50KB)
   - Use `compute()` to run highlighting in an isolate
   - The existing `_CollapsibleBody` already collapses long content, so only the visible portion needs fast rendering

3. **Content-type detection**: The `body_serializer.dart` already knows the `Content-Type` header. We need to pass content-type info through to the UI layer so the widget can choose the right language (JSON vs XML vs plain text).

4. **re_highlight version 0.0.x**: The 0.0.x version suggests pre-release maturity. However, it is backed by Reqable (commercial product) and is a faithful port of highlight.js, which is battle-tested.

5. **JSON pretty-printing**: `re_highlight` highlights existing text but does not format it. For JSON pretty-printing, use `JsonEncoder.withIndent('  ').convert()` before highlighting. This is already partially handled in `body_serializer.dart` via `_safeJsonEncode`, but that uses `jsonEncode` without indentation -- we should add pretty-printing at the display layer.

### Related Spec Documents

- No existing spec files found for syntax highlighting feature (new feature)

### External References

- [re_highlight on GitHub](https://github.com/reqable/re-highlight) -- Reqable's highlight.js Dart port
- [re_highlight on pub.dev](https://pub.dev/packages/re_highlight)
- [highlight.js](https://github.com/highlightjs/highlight.js) -- upstream project (v11.9.0)
- [syntax_highlight on GitHub](https://github.com/serverpod/syntax_highlight) -- Serverpod's TextMate-based alternative
- [Flutter SelectableText.rich API](https://api.flutter.dev/flutter/widgets/SelectableText/SelectableText.rich.html)
