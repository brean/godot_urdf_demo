![logo](logo.jpg)

# YAML.gd 1.0.0 ![Godot v4.x](https://img.shields.io/badge/Godot-v4.x-%23478cbf) ![Godot v3.x](https://img.shields.io/badge/Godot-v3.x-%23478cbf)

A YAML parser written entirely in GDScript.  
`YAML.gd` allows you to parse YAML content directly within your projects without requiring C++ modules or compilation, making it easy to integrate and use on any platform supported by Godot.

[!["Buy Me A Coffee"](coffee.png)](https://ko-fi.com/lowlevel1989)

## Features

- 100% implemented in GDScript.
- No compilation needed – just drop it into your project.
- Supports:
  - Simple and nested dictionaries.
  - Lists and mixed structures (lists within dictionaries and vice versa).
  - Empty/null values.
  - Multiline blocks (`|`, `>`).
  - Chomping modifiers (`|-`, `|+`) and newline handling.
  - Quoted strings (single and double quotes).
  - Inline comments and blank lines.
  - Automatic type casting (`true`, `false`, numbers, `null`).
- Fully tested with a comprehensive test suite.

## ⚠️ Important Warning

Do **not** edit `.yaml` files directly from the Godot editor.  
The editor may automatically convert spaces to tabs, which **breaks YAML syntax** (YAML requires indentation using **spaces only**).

Use an external editor with proper configuration such as:

- **Vim**
- **VSCode**
- **Sublime Text**
- **Notepad++**

Make sure "tabs to spaces" is enabled.

## Basic usage:

```gdscript
var parser = YAMLParser.new()

var yfile = FileAccess.open(
                "res://assets/yaml_dot_gd/tests/yamls/basic/test_01.yaml",
                FileAccess.READ)
var yaml = yfile.get_as_text()
yfile.close()

var result = parser.parse(yaml)
if typeof(result) == TYPE_DICTIONARY and result.has("name"):
    print(result["name"])
```

## Test Results

```text
=== Running Basic Tests ===
✔️ Test 1: Simple key-value pairs
✔️ Test 2: Nested dictionaries
✔️ Test 3: Simple lists
✔️ Test 4: Mixed structures
✔️ Test 5: Empty values
➡️ Basic Tests: 5/5 passed

=== Running Multiline Tests ===
✔️ Test 1: Literal block
✔️ Test 2: Folded block
✔️ Test 3: Strip chomping
✔️ Test 4: Keep chomping
✔️ Test 5: Quoted string
➡️ Multiline Tests: 5/5 passed

=== Running Advanced Tests ===
✔️ Test 1: Complex nested structure
✔️ Test 2: Multiple levels of nesting
✔️ Test 3: Mixed list types
✔️ Test 4: Comments and empty lines
✔️ Test 5: Miscellaneous edge cases
➡️ Advanced Tests: 5/5 passed

✅ **ALL TESTS PASSED**


