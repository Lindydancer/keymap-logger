;;; keymap-logger.el --- Instrument keymaps and log transforms

;; Copyright (C) 2017-2018  Anders Lindgren

;; Author: Anders Lindgren
;; Created: 2017-12-14
;; Version: 0.0.0
;; Package-Requires: ((emacs "24.3"))
;; URL: https://github.com/Lindydancer/keymap-logger

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; Add code to emit trace output for keymap lookups, for keymaps that
;; perform transformations, like `input-decode-map'.
;;
;; NOTE: This is an "early release" intended to be tested by a small
;; audience.  Please, DO NOT add it to package archives like Melpa --
;; I will do that once this package has gotten some mileage.

;; Usage:
;;
;; `keymap-logger-mode' -- When enabled, all key transformations are
;; logged to the buffer *KeymapLogger*, and the buffer is initially
;; displayed.
;;
;; In the *KeymapLogger* buffer, pressing `t' toggles the mode and `x'
;; erase the buffer.
;;
;; A simple translation use the following form.  In this case the
;; `backspace' key was pressed:
;;
;;     In input-decode-map key backspace => nil
;;     In local-function-key-map key backspace => [127]
;;     In key-translation-map key 127 => nil
;;
;; More complex cases, where functions bound to the transform keymaps
;; themselves read events are rendered using text boxes.  In the
;; following case, the `mode-like-keyboard' package was enabled and
;; the user clicked the `CTRL' and `k' labels on the header line and
;; mode line, respectively.  (Lines truncated for readability):
;;
;;     /--------------------
;;     | In input-decode-map key 27-91-60 mode-line-keyboard-wrapper-...
;;     | /-------------------- (mode-line-keyboard-wrapper-for-xterm-... nil)
;;     | | Buffer: #<buffer *scratch*>
;;     | | (xterm-mouse-translate-extended nil) => [(down-mouse-1 ...)]
;;     | | mode-line-keyboard--inhibit-tranform: nil
;;     | | mode-line-keyboard-visible-mode: t
;;     | | /-------------------- (read-key nil)
;;     | | | /--------------------
;;     | | | | In input-decode-map key 27-91-60 mode-line-keyboard-...
;;     | | | | /-------------------- (mode-line-keyboard-wrapper-for-... nil)
;;     | | | | | Buffer: #<buffer *scratch*>
;;     | | | | | (xterm-mouse-translate-extended nil) => [(mouse-1 ...)]
;;     | | | | | mode-line-keyboard--inhibit-tranform: t
;;     | | | | | mode-line-keyboard-visible-mode: t
;;     | | | | \-------------------- => [(mouse-1 ...)]
;;     | | | \-------------------- => [(mouse-1 ...)]
;;     | | \-------------------- => (mouse-1 )
;;     | | Buffers: (#<buffer *scratch*> #<buffer  *Minibuf-1*> ...)
;;     | | Event: (mouse-1 ...)
;;     | | /-------------------- (mode-line-keyboard-apply-control-... nil)
;;     | | | /-------------------- (read-key nil)
;;     | | | | /--------------------
;;     | | | | | In input-decode-map key 27-91-60 mode-line-keyboard-...
;;     | | | | | /-------------------- (mode-line-keyboard-wrapper-... nil)
;;     | | | | | | Buffer: #<buffer *scratch*>
;;     | | | | | | (xterm-mouse-translate-extended nil) => [(down-mouse-1 ...)]
;;     | | | | | | mode-line-keyboard--inhibit-tranform: nil
;;     | | | | | | mode-line-keyboard-visible-mode: t
;;     | | | | | | /-------------------- (read-key nil)
;;     | | | | | | | /--------------------
;;     | | | | | | | | In input-decode-map key 27-91-60 mode-line-keyboard-...
;;     | | | | | | | | /-------------------- (mode-line-keyboard-wrapper-...
;;     | | | | | | | | | Buffer: #<buffer *scratch*>
;;     | | | | | | | | | (xterm-mouse-translate-extended nil) => [(mouse-1...)]
;;     | | | | | | | | | mode-line-keyboard--inhibit-tranform: t
;;     | | | | | | | | | mode-line-keyboard-visible-mode: t
;;     | | | | | | | | \-------------------- => [(mouse-1 ...)]
;;     | | | | | | | \-------------------- => [(mouse-1 ...)]
;;     | | | | | | \-------------------- => (mouse-1 )
;;     | | | | | | Buffers: (#<buffer *scratch*> #<buffer  *Minibuf-1*> ...)
;;     | | | | | | Event: (mouse-1 ...)
;;     | | | | | \-------------------- => [107]
;;     | | | | \-------------------- => [107]
;;     | | | | In local-function-key-map key 107 => nil
;;     | | | | In key-translation-map key 107 => nil
;;     | | | \-------------------- => 107
;;     | | \-------------------- => [11]
;;     | \-------------------- => [11]
;;     \-------------------- => [11]

;; Other commands:
;;
;; - `keymap-logger-read-event-loop' -- Loop over `read-event' and
;;   echo the result.  Exit the loop by pressing `q'.
;;
;; - `keymap-logger-read-key-loop' -- Loop over `read-key' and echo
;;   the result.  Exit the loop by pressing `q'.
;;
;; - `keymap-logger-read-key-sequence-loop' -- Loop over
;;   `read-key-sequence' and echo the result.  Exit the loop by
;;   pressing `q'.
;;
;; - `keymap-logger-list-events' -- List events (symbols) found in
;;   various keymaps.

;; Dependencies:
;;
;; This package need Emacs 24.3 for two things: `user-error' and
;; `special-mode'.  If you want to run it on earlier Emacs version, you
;; can replace them with `error' and nil, respectively.

;;; Code:

;; - `string-version-lessp' is only available in very new Emacs
;;   versions.

(defvar keymap-logger-keymaps
  '(input-decode-map
    function-key-map
    ;; Note: By placing `local-function-key-map' after
    ;; `function-key-map' (which is the parent map), it's possible to
    ;; see if a key is defined in the parent or child keymap.
    local-function-key-map
    key-translation-map)
  "List of keymaps (symbols) to instrument.")


(defvar keymap-logger-add-extra-events t
  "Non-nil when `keymap-logger-extra-events' should be added to keymaps.")


(defvar keymap-logger-extra-event-list
  '(down-mouse-1
    down-mouse-2
    down-mouse-3
    down-mouse-4
    down-mouse-5
    mouse-1
    mouse-2
    mouse-3
    mouse-4
    mouse-5
    double-down-mouse-1
    double-down-mouse-2
    double-down-mouse-3
    double-down-mouse-4
    double-down-mouse-5
    double-mouse-1
    double-mouse-2
    double-mouse-3
    double-mouse-4
    double-mouse-5
    triple-down-mouse-1
    triple-down-mouse-2
    triple-down-mouse-3
    triple-down-mouse-4
    triple-down-mouse-5
    triple-mouse-1
    triple-mouse-2
    triple-mouse-3
    triple-mouse-4
    triple-mouse-5
    up
    down
    left
    right
    insert
    prior
    next
    home
    end
    backspace
    deletechar
    (0 . 255))
  "List of special events to add to keymaps, to make them appear in logs.

The entries in the list is either a symbol, an integer, or a pair
one the form (FROM . TO), where FROM and TO are integers.

The special events are only added to keymaps when the variable
`keymap-logger-add-extra-events' is non-nil.

Note, when a special event already is present (possibly as a
prefix key) it can't be added to the keymap.")


(defvar keymap-logger-add-prefix-as-subkeymap t
  "When non-nil, unbound prefixes are bound to subkeymaps.

When nil, the prefix is bound, list normal events.

See `keymap-logger-extra-event-list' for the list of prefixes.")


(defvar keymap-logger-extra-prefix-list
  '(mode-line
    header-line
    left-fringe
    right-fringe)
  "List of prefix events.")

(defvar keymap-logger-depth 0
  "Current log depth.

This is used when a function in a keymap explicitly calls things
like `read-key-sequence'.")

(defun keymap-logger-to-string (object)
  "Convert OBJECT to a string."
  (if (stringp object)
      object
    (format "%S" object)))


;; Forward declaration.
(defvar keymap-logger-mode)

(defun keymap-logger-log (format-string &rest args)
  "Insert log message in the Keymap Logger buffer, when enabled.

FORMAT-STRING is a format control string and ARGS are objects
that can be substituted into it, see `format' for details.

Return the Keymap Logger buffer or nil."
  (and keymap-logger-mode
       (let ((buf (get-buffer-create "*KeymapLogger*"))
             (prefix ""))
         (dotimes (_i keymap-logger-depth)
           (setq prefix (concat prefix "| ")))
	 (with-current-buffer buf
           (let ((buffer-read-only nil))
	     (goto-char (point-max))
	     (insert prefix)
	     (insert (apply #'format format-string args))
	     (insert "\n")
	     (let ((win (get-buffer-window buf)))
	       (when win
	         (set-window-point win (point))))))
	 buf)))


(defmacro keymap-logger-block-with-title (title &rest body)
  "Print TITLE and evaluate BODY inside a keymap logger block.

If TITLE is nil, output is supressed.

The value of the body is the value of the macro."
  (declare (indent 1) (debug t))
  (let ((res-symbol
         (make-symbol "res-in-keymap-logger-block-with-title"))
        (title-value
         (make-symbol "title-res-in-keymap-logger-block-with-title")))
    `(let (,res-symbol
           (,title-value ,title))
       (keymap-logger-log "/--------------------%s"
                          (if ,title-value
                              (concat " " ,title-value)
                            ""))
       (let ((keymap-logger-depth (+ keymap-logger-depth 1)))
         (setq ,res-symbol (progn ,@body)))
       (keymap-logger-log "\\-------------------- => %S" ,res-symbol)
       ,res-symbol)))


(defmacro keymap-logger-block (&rest body)
  "Evaluate BODY inside a keymap logger block.

The value of the block is the value of the macro."
  (declare (indent 0) (debug t))
  `(keymap-logger-block-with-title nil ,@body))


(defun keymap-logger-flatten-for-apply (args)
  "Flatten ARGS in preparation for calling `apply'."
  (and args
       ;; One or more arguments.
       (if (not (null (cdr args)))
           ;; Two or more arguments.
           (cons (car args) (keymap-logger-flatten-for-apply (cdr args)))
         ;; Exactly one argument
         (car args))))


(defun keymap-logger-apply (func &rest args)
  "Call FUNC with ARGS like `apply', with optional logging.

When Keymap Logger mode is enabled, log the call to FUNC and the
return value."
  (let ((flat-args (keymap-logger-flatten-for-apply args)))
    (keymap-logger-block-with-title (format "%S" (cons func flat-args))
      (apply func flat-args))))


(defun keymap-logger-funcall (func &rest args)
  "Call FUNC with ARGS like `funcall', with optional logging.

When Keymap Logger mode is enabled, log the call to FUNC and the
return value."
  (keymap-logger-apply func args))


(defun keymap-logger-log-binding (keymap-name key-name value prompt)
  "Log en event, when Keymap Logger mode is enabled.

When a keymap is instrumented, every key is bound to a
synthesized function that calls this function with the following
arguments: KEYMAP-NAME is the name of the keymap.  KEY-NAME is a
made up name that corresponds to the key, like \"27-91-60\".
VALUE is the original binding.  And PROMPT is the argument passed
to the synthesized function."
  (if (or (vectorp value)
          (null value))
      ;; The key was originally bound to a vector (i.e. remapped to
      ;; other keys) or to nil (the key was ignored).
      (progn
        (keymap-logger-log "In %s key %s => %S" keymap-name key-name value)
        value)
    (keymap-logger-block
      (keymap-logger-log "In %s key %s %S" keymap-name key-name value)
      (keymap-logger-funcall value prompt))))


(defun keymap-logger-add-event (keymap event &optional prefix)
  "Add, to KEYMAP, EVENT or [PREFIX EVENT] and bind it to nil."
  ;; Appologies for the awkward language in the doc string, but
  ;; `checkdoc' insists that the parameters should occur in the same
  ;; order as in the parameter list.
  (let ((vec (if prefix
                 (vector prefix event)
               (vector event))))
    (unless (lookup-key keymap vec)
      (define-key keymap vec nil))))


(defun keymap-logger-add-extra-events (&optional keymap-list)
  "Add the events in `keymap-logger-extra-event-list' to KEYMAP-LIST.

KEYMAP-LIST is a list of keymaps.  If it is nil,
`keymap-logger-keymaps' is used.

The events are bound in top of the keymap, and after each prefix
in the list `keymap-logger-extra-prefix-list'."
  (unless keymap-list
    (setq keymap-list keymap-logger-keymaps))
  (let ((event-list keymap-logger-extra-event-list)
	(prefix-list keymap-logger-extra-prefix-list))
    (unless keymap-logger-add-prefix-as-subkeymap
      (setq event-list (append event-list keymap-list))
      (setq prefix-list '()))
    (dolist (symbol keymap-list)
      (let ((keymap (symbol-value symbol)))
        (dolist (prefix (cons nil prefix-list))
          (dolist (event keymap-logger-extra-event-list)
            (if (consp event)
                (let ((from (car event))
                      (to (cdr event)))
                  (while (<= from to)
                    (keymap-logger-add-event keymap from prefix)
                    (setq from (+ from 1))))
              (keymap-logger-add-event keymap event prefix))))))))


(defun keymap-logger-instrument-keymap (keymap
                                        base-name
                                        &optional
                                        seen-keys)
  "Instrument KEYMAP for Keymap Logger Mode.

BASE-NAME is the name (a symbol) of the top keymap,
e.g. `function-key-map'.

SEEN-KEYS is a list representing the keys bound to KEYMAP in the
keymap named BASE-NAME.

All instrumented keys will be bound to synthetized functions
named `keymap-logger--BASE-NAME--KEYS'."
  (unless (keymapp keymap)
    (error "Expected keymap: %S" keymap))
  (dolist (entry (cdr keymap))
    (cond ((eq entry 'keymap))
	  ((not (consp entry))
	   (error "Unexpected entry: %S" entry))
	  ((keymapp entry)
           ;; If a keymap is included in another keymap, it is seen as a
           ;; part of it.
           (keymap-logger-instrument-keymap entry
                                            base-name
                                            seen-keys))
	  (t
	   (let ((new-seen-keys (append seen-keys (list (car entry))))
		 (binding (cdr entry)))
             (if (keymapp binding)
		 ;; Step into the enclosed keymap.
		 (progn
		   ;; If a key is mapped to a symbol and that symbols
		   ;; function definition is a keymap, that keymap is used.
		   (when (symbolp binding)
                     (push binding base-name)
                     ;; As a side-effect of this, autoloaded keymaps are
                     ;; loaded.
                     (lookup-key binding "a")
                     (setq binding (symbol-function binding)))
		   (keymap-logger-instrument-keymap binding
						    base-name
						    new-seen-keys))
               ;; Instrument keymap entry (unless already instrumented).
               (unless (and (symbolp binding)
			    (functionp binding)
			    (get binding 'keymap-logger-instrumented))
		 (let* ((keymap-name (mapconcat #'keymap-logger-to-string
						base-name
						"-"))
			(key-name (mapconcat #'keymap-logger-to-string
                                             new-seen-keys
                                             "-"))
			(func-name (mapconcat #'identity
                                              (list
                                               "keymap-logger"
                                               keymap-name
                                               key-name)
                                              "--"))
			(func-symbol (intern func-name)))
		   ;; TODO: Handle lambda expression.
		   (let ((def `(defun ,func-symbol (prompt)
				 (keymap-logger-log-binding
				  ,keymap-name
				  ,key-name
				  (quote ,binding)
				  prompt))))
                     (eval def))
		   (put func-symbol 'keymap-logger-instrumented t)
		   (setcdr entry func-symbol)))))))))


(defun keymap-logger-instrument-keymap-list (&optional keymap-list)
  "Instrument keymaps in KEYMAP-LIST.

If KEYMAP-LIST is empty, use `keymap-logger-keymaps' instead."
  (unless keymap-list
    (setq keymap-list keymap-logger-keymaps))
  (when keymap-logger-add-extra-events
    (keymap-logger-add-extra-events keymap-list))
  (dolist (symbol keymap-list)
    (keymap-logger-instrument-keymap (symbol-value symbol)
                                     (list symbol))))


;; ----------------------------------------------------------------------
;; Buffer mode.
;;


(defun keymap-logger-view-erase-buffer ()
  "Erase the Keymap Logger buffer."
  (interactive)
  (unless (eq major-mode 'keymap-logger-view-mode)
    (user-error "Not in Keymap Logger View Mode"))
  (let ((buffer-read-only nil))
    (erase-buffer)))


(defvar keymap-logger-view-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "t") #'keymap-logger-mode)
    (define-key map (kbd "x") #'keymap-logger-view-erase-buffer)
    map))


(define-derived-mode keymap-logger-view-mode special-mode "KeymapLogger"
  "Major mode used in the log window of Keymap Logger Mode."
  (set (make-local-variable 'truncate-lines) t))


;; ----------------------------------------------------------------------
;; Global mode.
;;

;;;###autoload
(define-minor-mode keymap-logger-mode
  "Global minor mode that monitors and logs keymap events.

When enabled, this mode instruments the keymaps in the list
`keymap-logger-keymaps'.  Concretely, this means that all
existing entries are replaced with synthesized functions and the
entries in the list `keymap-logger-extra-event-list' are added to
the keymaps.

Log information is inserted into the buffer *KeymapLogger*.

When disabled, the logging stops, but the keymaps are still
instrumented!"
  nil
  nil
  nil
  :global t
  :require 'keymap-logger
  (if keymap-logger-mode
      (progn
        (keymap-logger-instrument-keymap-list)
        (let ((buf (keymap-logger-log "Keymap logging started")))
          (with-current-buffer buf
            (keymap-logger-view-mode))
          (display-buffer buf)))
    (let ((keymap-logger-mode t))
      (display-buffer (keymap-logger-log "Keymap logging stopped")))))


;; ----------------------------------------------------------------------
;; Interactive read loops.
;;

(defun keymap-logger-read-event-loop ()
  "Loop over `read-event' and print the result.

Quit by pressing `q'."
  (interactive)
  (while (let ((entry (read-event)))
	   (message "event: %S" entry)
	   (not (eq entry ?q)))))

(defun keymap-logger-read-key-loop ()
  "Loop over `read-key' and print the result.

Quit by pressing `q'."
  (interactive)
  (while (let ((entry (read-key)))
	   (message "event: %S" entry)
	   (not (eq entry ?q)))))

(defun keymap-logger-read-key-sequence-loop ()
  "Loop over `read-key-sequence' and print the result.

Quit by pressing `q'."
  (interactive)
  (while (let ((entry (read-key-sequence "KEY-SEQUENCE: ")))
	   (message "event: %S" entry)
	   (not (equal entry "q")))))


;; `add-to-list' isn't recommended to be used from elisp, and I don't
;; want to use the Common Lisp compatibility package (`cl-lib').
(defun keymap-logger-insert (element list)
  "Add ELEMENT to LIST, unless it's already in the list, nondestructively.

Return the new list."
  (if (memq element list)
      list
    (cons element list)))


(defun keymap-logger-union (list &rest others)
  "Return list of all element found in LIST and OTHERS."
  (dolist (one others)
    (dolist (entry one)
      (setq list (keymap-logger-insert entry list))))
  list)


(defun keymap-logger-base-event (event)
  "Strip away modifiers like `C-' from EVENT (when a symbol)."
  (when (symbolp event)
    (while
        (let ((string (symbol-name event)))
          (if (string-match "^[CSsMAH]-\\(.*\\)$" string)
              (progn
                (setq event (intern (match-string 1 string)))
                t)
            nil))))
  event)

(defun keymap-logger-events-in-keymap (keymap)
  "Return list of events (symbols) found in KEYMAP."
  (unless (keymapp keymap)
    (error "Expected keymap: %S" keymap))
  (let ((seen '()))
    (dolist (entry (cdr keymap))
      (cond ((eq entry 'keymap))
            ;; `msb-mode' in `minor-mode-map-alist' contains a stray
            ;; "Msb".
            ((stringp entry))
            ;; Occurs in global map.
            ((char-table-p entry))
	    ((not (consp entry))
	     (error "Unexpected entry: %S" entry))
	    ((keymapp entry)
             (setq seen (keymap-logger-union
                         seen
                         (keymap-logger-events-in-keymap entry))))
	    (t
             (let ((event (car entry)))
               (unless (numberp event)
                 (setq seen (keymap-logger-insert
                             (keymap-logger-base-event event)
                             seen))))
             (let ((binding (cdr entry)))
               (when (vectorp binding)
                 (mapc (lambda (event)
                         (unless (numberp event)
                           (setq seen (keymap-logger-insert
                                       (keymap-logger-base-event event)
                                       seen))))
                       binding))))))
    seen))

;;;###autoload
(defun keymap-logger-list-events ()
  "List all events (symbols) found in various keymaps."
  (interactive)
  (with-output-to-temp-buffer "*KeymapLoggerEvents*"
    (let ((keymap-list '())
          ;; Try to sort something5 before something10.  This,
          ;; however, requires `string-version-lessp' which is
          ;; provided only in new Emacs versions.
          ;;
          ;; (Extra credit for the worst ever named elisp function.
          ;; Something like `string-natural-lessp' would have been
          ;; much better.)
          (pred (if (fboundp 'string-version-lessp)
                    #'string-version-lessp
                  #'string-lessp)))
      ;; Special keymaps
      (dolist (var keymap-logger-keymaps)
        (setq keymap-list (keymap-logger-insert
                           (symbol-value var)
                           keymap-list)))
      ;; Minor modes
      (dolist (pair minor-mode-map-alist)
        (setq keymap-list (keymap-logger-insert
                           (cdr pair)
                           keymap-list)))
      ;; Global map.
      (setq keymap-list (keymap-logger-insert
                         global-map
                         keymap-list))
      (let ((seen '()))
        (dolist (keymap keymap-list)
          (setq seen (keymap-logger-union
                      seen
                      (keymap-logger-events-in-keymap
                       keymap))))
        (dolist (entry (sort seen (lambda (lhs rhs)
                                    (funcall
                                     pred
                                     (format "%S" lhs)
                                     (format "%S" rhs)))))
          (princ (format "%S" entry))
          (terpri))))
    (display-buffer standard-output)))

;;  (keymap-logger-instrument-keymap-list)

(provide 'keymap-logger)

;;; keymap-logger.el ends here
