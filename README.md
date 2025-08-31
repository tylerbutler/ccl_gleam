# Categorical Configuration Language (CCL) – Informal Specification

[![Package Version](https://img.shields.io/hexpm/v/ccl_gleam)](https://hex.pm/packages/ccl_gleam)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/ccl_gleam/)

This spec is based on <https://chshersh.com/blog/2025-01-06-the-most-elegant-configuration-language.html>.

## 1. Overview

CCL is a minimal, composable configuration format consisting of an **ordered sequence of key–value pairs**.  
Keys and values are plain strings. There is no typing, quoting, escaping, or nesting in the core.  
The **comments extension** treats certain entries as comments by using a reserved key (e.g., `/`), which applications ignore.

---

## 2. Encoding and Line Endings

- **Encoding:** UTF‑8 only.
- **Line endings:** LF (`\n`) or CRLF (`\r\n`); parsers must normalize to LF internally.

---

## 3. Keys

- **Definition:** Any sequence of characters **not containing `=`**.
- **Trimming:** Remove all leading and trailing **whitespace** (spaces, tabs, etc.) from the key.
- Keys may contain spaces, punctuation, and Unicode characters.
- Keys are case‑sensitive.
- Keys are not quoted or escaped.

---

## 4. Values

- **Definition:** All characters after the first `=` on the key line, plus any continuation lines until the next key line or EOF.
- **Leading trim:** Remove only **space characters** (U+0020) from the start of the value.  
  Tabs and other whitespace are preserved as literal content.
- **Trailing trim:** Remove all trailing whitespace (spaces, tabs, etc.).
- **Multiline values:**  
  - Any line following the key line that does **not** start with a valid key is part of the current value.
  - Leading spaces on continuation lines are trimmed; tabs are preserved.
  - Blank lines inside a value are preserved (after trimming).

---

## 5. Separator

- The **first `=`** in the line separates the key from the value.
- Everything before it (after key trimming) is the key.
- Everything after it (before value trimming) is the start of the value.

---

## 6. Comments Extension

- **Concept:** Comments are just key–value pairs whose key matches a reserved “comment key” (commonly `/`).
- **Parsing:** The parser treats them like any other entry.
- **Application behavior:** Applications may ignore entries whose key equals the comment key.
- **Example:**

	```
	/= This is an environment config 
	port = 8080 serve = index.html
	/= This is a database config
	mode = in-memory
	connections = 16
	```

Parsed entries:

1. (`/`, `This is an environment config`)
2. (`port`, `8080`)
3. (`serve`, `index.html`)
4. (`/`, `This is a database config`)
5. (`mode`, `in-memory`)
6. (`connections`, `16`)

---

## 7. Composition

- Concatenating two valid CCL documents yields another valid CCL document.
- Duplicate keys are allowed; resolution is application‑defined (last‑wins, first‑wins, merge, collect‑all, etc.).
- Comments survive composition and can be preserved or dropped by the application.

---

## 8. Parsing Outline

1. Normalize line endings to LF.
2. Read the next non‑EOF line.
3. If the line contains `=`, split on the **first** `=`:
 - Trim key (leading/trailing whitespace).
 - Trim value (leading spaces only, trailing whitespace).
4. Append continuation lines until:
 - A line contains `=` and the part before it (after trimming) has no `=`, or
 - EOF.
5. Emit the (key, value) pair.
6. Repeat until EOF.

---

## 9. Notes

- Keys can appear indented; detection ignores leading/trailing whitespace around the would‑be key.
- Lines starting with `=` (empty key after trimming) are **not** key lines and are treated as value continuations.
- Tabs in keys are trimmed like spaces.
- Tabs in values are preserved unless they are trailing, in which case they are removed by trailing‑whitespace trim.
- The comment key is not reserved by the core spec — it’s a convention agreed upon by the application.
