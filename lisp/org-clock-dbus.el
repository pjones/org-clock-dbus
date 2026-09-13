;;; org-clock-dbus.el --- Monitor org-clock from D-Bus -*- lexical-binding: t; -*-

;; Copyright (c) 2024-2026 Peter J. Jones <pjones@devalot.com>

;; Author: Peter J. Jones <pjones@devalot.com>
;; Maintainer: Peter J. Jones <pjones@devalot.com>
;; Keywords: comm outlines unix
;; URL: https://github.com/pjones/org-clock-db
;; Package-Requires: ((emacs "28.1") (org "9.6.0"))
;; Version: 1.1.0

;; This file is not part of GNU Emacs.

;; This program is free software; you can redistribute it and/or modify it under
;; the terms of the GNU General Public License as published by the Free Software
;; Foundation; either version 3, or (at your option) any later version.

;; This program is distributed in the hope that it will be useful, but WITHOUT
;; ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
;; FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
;; details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:
;;
;; This is an Emacs package that creates a D-Bus API for the org-mode
;; clock.  It includes an (optional) command line tool that can be
;; used to control the Org clock and display clock information in your
;; desktop's panel.

;;; Code:
(require 'dbus)
(require 'org-clock)

(defgroup org-clock-dbus nil
  "Org Clock D-Bus mode."
  :group 'org
  :prefix "org-clock-dbus-")

(defconst org-clock-dbus-service
  (concat dbus-service-emacs ".Org.Clock")
  "The service name to register and use.")

(defconst org-clock-dbus-path
  (concat dbus-path-emacs "/Org/Clock")
  "The path name to register and use.")

(defvar org-clock-dbus--method-stop nil
  "The handle to the stop method registration.")

(defvar org-clock-dbus--property-state nil
  "The handle to the state property registration.")

(defun org-clock-dbus--value ()
  "Return a D-Bus value for the Clock property."
  (if (org-clocking-p)
      (let ((start-time (floor (float-time org-clock-start-time)))
            (description org-clock-heading))
        ;; NOTE: The Rust code relies on this data structure:
        `((:dict-entry "running" (:variant :boolean t))
          (:dict-entry "started" (:variant :uint64 ,start-time))
          (:dict-entry "heading" (:variant :string ,description))))
    '((:dict-entry "running" (:variant :boolean nil)))))

(defun org-clock-dbus--update ()
  "Broadcast a D-Bus signal with the latest `org-clock' data."
  (dbus-set-property
   :session
   org-clock-dbus-service org-clock-dbus-path org-clock-dbus-service
   "state" (org-clock-dbus--value)))

(defvar org-clock-dbus--hooks
  '(org-clock-in-hook
    org-clock-out-hook
    org-clock-cancel-hook)
  "List of `org-mode' hooks to attach to.")

(defun org-clock-dbus--load ()
  "Set up the hooks necessary for Org Clock D-Bus to run."
  (when (eq :primary-owner
            (dbus-register-service
             :session org-clock-dbus-service
             :do-not-queue))
    (when (null org-clock-dbus--method-stop)
      (dolist (hook org-clock-dbus--hooks)
        (add-hook hook #'org-clock-dbus--update))
      (setq org-clock-dbus--property-state
            (dbus-register-property
             :session
             org-clock-dbus-service
             org-clock-dbus-path
             org-clock-dbus-service
             "state" :readwrite nil t))
      (setq org-clock-dbus--method-stop
            (dbus-register-method
             :session
             org-clock-dbus-service
             org-clock-dbus-path
             org-clock-dbus-service
             "Stop"
             (lambda (&rest _args)
               (org-clock-out nil t)
               :ignore)))
      (org-clock-dbus--update))))

(defun org-clock-dbus--unload ()
  "Remove Org Clock D-Bus mode from `org-mode' hooks."
  (dolist (hook org-clock-dbus--hooks)
    (remove-hook hook #'org-clock-dbus--update))
  (dbus-unregister-service :session org-clock-dbus-service)
  (when org-clock-dbus--method-stop
    (dbus-unregister-object org-clock-dbus--method-stop)
    (setq org-clock-dbus--method-stop nil))
  (when org-clock-dbus--property-state
    (dbus-unregister-object org-clock-dbus--property-state)
    (setq org-clock-dbus--property-state nil)))

;;;###autoload
(define-minor-mode org-clock-dbus-mode
  "Toggle Org Clock D-Bus mode."
  :init-value nil
  :lighter " clock-dbus"
  :group 'org-clock-dbus
  :global t
  (if org-clock-dbus-mode
      (org-clock-dbus--load)
    (org-clock-dbus--unload)))

(provide 'org-clock-dbus)

;;; org-clock-dbus.el ends here
