# keymap-logger - Instrument keymaps and log transforms

*Author:* Anders Lindgren<br>
*Version:* 0.0.0<br>
*URL:* [https://github.com/Lindydancer/keymap-logger](https://github.com/Lindydancer/keymap-logger)<br>

Add code to emit trace output for keymap lookups, for keymaps that
perform transformations, like `input-decode-map`.

NOTE: This is an "early release" intended to be tested by a small
audience.  Please, DO NOT add it to package archives like Melpa --
I will do that once this package has gotten some mileage.

## Usage

`keymap-logger-mode` -- When enabled, all key transformations are
logged to the buffer *KeymapLogger*, and the buffer is initially
displayed.

In the *KeymapLogger* buffer, pressing `t` toggles the mode and `x`
erase the buffer.

A simple translation use the following form.  In this case the
`backspace` key was pressed:

    In input-decode-map key backspace => nil
    In local-function-key-map key backspace => [127]
    In key-translation-map key 127 => nil

More complex cases, where functions bound to the transform keymaps
themselves read events are rendered using text boxes.  In the
following case, the `mode-like-keyboard` package was enabled and
the user clicked the `CTRL` and `k` labels on the header line and
mode line, respectively.  (Lines truncated for readability):

    /--------------------
    | In input-decode-map key 27-91-60 mode-line-keyboard-wrapper-...
    | /-------------------- (mode-line-keyboard-wrapper-for-xterm-... nil)
    | | Buffer: #<buffer *scratch*>
    | | (xterm-mouse-translate-extended nil) => [(down-mouse-1 ...)]
    | | mode-line-keyboard--inhibit-tranform: nil
    | | mode-line-keyboard-visible-mode: t
    | | /-------------------- (read-key nil)
    | | | /--------------------
    | | | | In input-decode-map key 27-91-60 mode-line-keyboard-...
    | | | | /-------------------- (mode-line-keyboard-wrapper-for-... nil)
    | | | | | Buffer: #<buffer *scratch*>
    | | | | | (xterm-mouse-translate-extended nil) => [(mouse-1 ...)]
    | | | | | mode-line-keyboard--inhibit-tranform: t
    | | | | | mode-line-keyboard-visible-mode: t
    | | | | \-------------------- => [(mouse-1 ...)]
    | | | \-------------------- => [(mouse-1 ...)]
    | | \-------------------- => (mouse-1 )
    | | Buffers: (#<buffer *scratch*> #<buffer  *Minibuf-1*> ...)
    | | Event: (mouse-1 ...)
    | | /-------------------- (mode-line-keyboard-apply-control-... nil)
    | | | /-------------------- (read-key nil)
    | | | | /--------------------
    | | | | | In input-decode-map key 27-91-60 mode-line-keyboard-...
    | | | | | /-------------------- (mode-line-keyboard-wrapper-... nil)
    | | | | | | Buffer: #<buffer *scratch*>
    | | | | | | (xterm-mouse-translate-extended nil) => [(down-mouse-1 ...)]
    | | | | | | mode-line-keyboard--inhibit-tranform: nil
    | | | | | | mode-line-keyboard-visible-mode: t
    | | | | | | /-------------------- (read-key nil)
    | | | | | | | /--------------------
    | | | | | | | | In input-decode-map key 27-91-60 mode-line-keyboard-...
    | | | | | | | | /-------------------- (mode-line-keyboard-wrapper-...
    | | | | | | | | | Buffer: #<buffer *scratch*>
    | | | | | | | | | (xterm-mouse-translate-extended nil) => [(mouse-1...)]
    | | | | | | | | | mode-line-keyboard--inhibit-tranform: t
    | | | | | | | | | mode-line-keyboard-visible-mode: t
    | | | | | | | | \-------------------- => [(mouse-1 ...)]
    | | | | | | | \-------------------- => [(mouse-1 ...)]
    | | | | | | \-------------------- => (mouse-1 )
    | | | | | | Buffers: (#<buffer *scratch*> #<buffer  *Minibuf-1*> ...)
    | | | | | | Event: (mouse-1 ...)
    | | | | | \-------------------- => [107]
    | | | | \-------------------- => [107]
    | | | | In local-function-key-map key 107 => nil
    | | | | In key-translation-map key 107 => nil
    | | | \-------------------- => 107
    | | \-------------------- => [11]
    | \-------------------- => [11]
    \-------------------- => [11]

## Other commands

- `keymap-logger-read-event-loop` -- Loop over `read-event` and
  echo the result.  Exit the loop by pressing `q`.
- `keymap-logger-read-key-loop` -- Loop over `read-key` and echo
  the result.  Exit the loop by pressing `q`.
- `keymap-logger-read-key-sequence-loop` -- Loop over
  `read-key-sequence` and echo the result.  Exit the loop by
  pressing `q`.
- `keymap-logger-list-events` -- List events (symbols) found in
  various keymaps.

## Dependencies

This package need Emacs 24.3 for two things: `user-error` and
`special-mode`.  If you want to run it on earlier Emacs version, you
can replace them with `error` and nil, respectively.


---
Converted from `keymap-logger.el` by [*el2markdown*](https://github.com/Lindydancer/el2markdown).
