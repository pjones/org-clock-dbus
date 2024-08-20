;;; org-clock-dbus.el --- Monitor org-clock from outside Emacs -*- lexical-binding: t; -*-

;; Copyright (c) 2024 Peter J. Jones <pjones@devalot.com>

;; Author: Peter J. Jones <pjones@devalot.com>
;; Maintainer: Peter J. Jones <pjones@devalot.com>
;; Keywords: org
;; URL: https://github.com/pjones/org-clock-db
;; Package-Requires: ((emacs "28.1") (org "9.6.0"))
;; Version: 0.1.0

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

;;; Code:
(require 'dbus)
(require 'org-clock)

(defgroup org-clock-dbus nil
  "Org Clock D-Bus mode."
  :group 'org
  :prefix "org-clock-dbus-")

(defun org-clock-dbus--update ()
  "Broadcast a D-Bus signal with the latest `org-clock' data.

This exposes the current clock's start time and heading to any process
listening to the correct D-Bus signal.

You can monitor this signal via the following command:

    \"dbus-monitor type='signal',interface='org.gnu.Emacs.Org.Clock'\"

Read the code below for the two event names and the signal arguments
they provide."
  (if (org-clocking-p)
      (let ((start-time (floor (float-time org-clock-start-time)))
            (description org-clock-heading))
        (dbus-send-signal
         :session nil dbus-path-emacs
         (concat dbus-interface-emacs ".Org.Clock") "Started"
         start-time description))
    (dbus-send-signal
     :session nil dbus-path-emacs
     (concat dbus-interface-emacs ".Org.Clock") "Stopped")))

(defun org-clock-dbus--timer-callback (&rest _args)
  "Periodically called to update D-Bus."
  (org-clock-dbus--update))

(defvar org-clock-dbus--hooks
  '(org-clock-in-hook
    org-clock-out-hook
    org-clock-cancel-hook)
  "List of `org-mode' hooks to attach to.")

(defun org-clock-dbus--load ()
  "Set up the hooks necessary for Org Clock D-Bus to run."
  (dolist (hook org-clock-dbus--hooks)
    (add-hook hook #'org-clock-dbus--update))
  (advice-add 'org-clock-update-mode-line :after
              'org-clock-dbus--timer-callback))

(defun org-clock-dbus--unload ()
  "Remove Org Clock D-Bus mode from `org-mode' hooks."
  (dolist (hook org-clock-dbus--hooks)
    (remove-hook hook #'org-clock-dbus--update))
  (advice-remove 'org-clock-update-mode-line
                 'org-clock-dbus--timer-callback))

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
