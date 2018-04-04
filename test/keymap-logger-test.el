;;; keymap-logger-test.el --- Basic tests for keymap-logger.el

;; Copyright (C) 2017-2018  Anders Lindgren

;; Author: Anders Lindgren
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

;; Basic tests for keymap-logger.el.

;;; Code:

(require 'keymap-logger)


;; ------------------------------------------------------------
;; Test helpers
;;

(defmacro keymap-logger-test-log-wrapper (&rest body)
  `(with-current-buffer (get-buffer-create "*KeymapLogger*")
     (let ((buffer-read-only nil))
       (erase-buffer))
     (let ((keymap-logger-mode t))
       (progn
         ,@body)
       (buffer-string))))


;; ------------------------------------------------------------
;; Log
;;

(ert-deftest keymap-logger-test-log-basic ()
  (should (equal (keymap-logger-test-log-wrapper
                  (keymap-logger-log "Test"))
                 "Test\n")))


(ert-deftest keymap-logger-test-log-block ()
  (should (equal (keymap-logger-test-log-wrapper
                  (keymap-logger-block
                    (keymap-logger-log "Test")
                    'my-result))
                 "\
/--------------------
| Test
\\-------------------- => my-result
"))
  (should (equal (keymap-logger-test-log-wrapper
                  (keymap-logger-block
                    (keymap-logger-block
                      (keymap-logger-log "Test")
                      'my-inner-result)
                    'my-outer-result))
                 "\
/--------------------
| /--------------------
| | Test
| \\-------------------- => my-inner-result
\\-------------------- => my-outer-result
")))

(ert-deftest keymap-logger-test-log-block-with-title ()
  (should (equal (keymap-logger-test-log-wrapper
                  (keymap-logger-block-with-title "Title"
                    (keymap-logger-log "Test")
                    'my-result))
                 "\
/-------------------- Title
| Test
\\-------------------- => my-result
"))
  (should (equal (keymap-logger-test-log-wrapper
                  (keymap-logger-block-with-title "Outer"
                    (keymap-logger-block-with-title "Inner"
                      (keymap-logger-log "Test")
                      'my-inner-result)
                    'my-outer-result))
                 "\
/-------------------- Outer
| /-------------------- Inner
| | Test
| \\-------------------- => my-inner-result
\\-------------------- => my-outer-result
")))


;; ------------------------------------------------------------
;; Log calling functions
;;

(ert-deftest keymap-logger-test-apply ()
  (should (equal (keymap-logger-apply #'list) '()))
  (should (equal (keymap-logger-apply #'list '(1)) '(1)))
  (should (equal (keymap-logger-apply #'list '(1 2 3 4)) '(1 2 3 4)))
  (should (equal (keymap-logger-apply #'list 0 '(1 2 3 4)) '(0 1 2 3 4)))
  nil)


(ert-deftest keymap-logger-test-funcall ()
  (should (equal (keymap-logger-funcall #'list) '()))
  (should (equal (keymap-logger-funcall #'list 1) '(1)))
  (should (equal (keymap-logger-funcall #'list 1 2 3) '(1 2 3)))
  (should (equal (keymap-logger-funcall #'list 1 '(2 3)) '(1 (2 3))))
  nil)

;; ------------------------------------------------------------
;; The end
;;

(provide 'keymap-logger-test)

;;; keymap-logger-test.el ends here
