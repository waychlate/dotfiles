;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-

;; Place your private configuration here! Remember, you do not need to run 'doom
;; sync' after modifying this file!

(setq doom-font (font-spec :family "JetBrainsMono Nerd Font" :size 14))
(setq doom-variable-pitch-font (font-spec :family "Source Sans 3" :size 16))

(after! org
  ;; use fixed + variable pitch in org
  (use-package! mixed-pitch
    :hook
    (org-mode . mixed-pitch-mode))

  ;; Preview Latex
  (use-package! org-fragtog
    :hook (org-mode . (lambda ()
                        (org-fragtog-mode)
                        ;; Preview all LaTeX fragments on buffer load
                        (org-latex-preview '(16)))))
  
  ;; Make LaTeX previews scale relative to buffer font
  (let ((scale (/ (float (face-attribute 'default :height)) 100.0)))
    (setq org-format-latex-options
          (plist-put org-format-latex-options :scale scale)))

  ;; get rid of superfluous indents 
  (setq adaptive-fill-mode nil)

  ;; org-modern config
  (use-package! org-modern
    :hook (org-mode . org-modern-mode)
    :config
    (setq org-modern-star 'replace
          org-modern-list '((43 . "•") (45 . "–") (42 . "→"))))

  (setq org-hide-emphasis-markers t)

  ;; Org capture templates
  (setq org-capture-templates
        `(("i" "Inbox" entry (file "inbox.org")
           ,(concat "* TODO %?\n"
                    "/Entered on/ %U"))))

  ;; Use full window for org-capture
  (add-hook 'org-capture-mode-hook 'delete-other-windows)

  ;; Refile
  (setq org-refile-use-outline-path 'file)
  (setq org-outline-path-complete-in-steps nil)

  ;; TODO state configuration
  (setq org-todo-keywords
        '((sequence "TODO(t)" "NEXT(n)" "HOLD(h)" "|" "DONE(d)")))
  (setq org-todo-keyword-faces
        '(("NEXT" . (:foreground "orange" :weight bold))
          ("HOLD" . (:foreground "red" :weight bold))))
  
  (defun log-todo-next-creation-date (&rest ignore)
    "Log NEXT creation time in the property drawer under the key 'ACTIVATED'"
    (when (and (string= (org-get-todo-state) "NEXT")
               (not (org-entry-get nil "ACTIVATED")))
      (org-entry-put nil "ACTIVATED" (format-time-string "[%Y-%m-%d]"))))
  (add-hook 'org-after-todo-state-change-hook #'log-todo-next-creation-date)

  ;; Agenda
  (setq org-agenda-custom-commands
        '(("g" "Get Things Done (GTD)"
           ((agenda ""
                    ((org-agenda-skip-function
                      '(org-agenda-skip-entry-if 'deadline))
                     (org-deadline-warning-days 0)))
            (todo "NEXT"
                  ((org-agenda-skip-function
                    '(org-agenda-skip-entry-if 'deadline))
                   (org-agenda-prefix-format "  %i %-12:c [%e] ")
                   (org-agenda-overriding-header "\nTasks\n")))
            (agenda nil
                    ((org-agenda-entry-types '(:deadline))
                     (org-agenda-format-date "")
                     (org-deadline-warning-days 7)
                     ;; (org-agenda-skip-function
                     ;;  '(org-agenda-skip-entry-if 'notregexp "\\* NEXT"))
                     (org-agenda-overriding-header "\nDeadlines (do them now)")))
            (tags-todo "inbox"
                       ((org-agenda-prefix-format "  %?-12t% s")
                        (org-agenda-overriding-header "\nInbox\n")))
            (tags "CLOSED>=\"<today>\""
                  ((org-agenda-overriding-header "\nCompleted Today I suppose...\n")))))))
  )

(custom-set-faces!
  '(org-document-title :height 1.5)
  '(org-level-1 :height 1.3 :inherit outline-1)
  '(org-level-2 :height 1.2 :inherit outline-2)
  '(org-level-3 :height 1.1 :inherit outline-3)
  '(org-level-4 :height 1.0 :inherit outline-4)
  '(org-level-5 :height 1.0 :inherit outline-5)
  '(org-level-6 :height 1.0 :inherit outline-6))

;;Make undo and redo more forgiving
(setq undo-limit 80000000)
(setq undo-strong-limit 120000000)
(setq undo-outer-limit 360000000)
(setq undo-auto-amalgamate-limit 5)
;; Enable "fine-grained" undo in evil-mode
(setq evil-want-fine-undo t)

(add-hook 'org-mode-hook
          (lambda ()
            (setq-local line-spacing 0.2)))

(after! org-roam
  (use-package! websocket)
  (use-package! org-roam-ui
    :config
    (setq org-roam-ui-sync-theme t
          org-roam-ui-follow t
          org-roam-ui-update-on-save t
          org-roam-ui-open-on-start t))

  (setq org-roam-node-display-template
        (concat "${title:100} "))

  ;; org-roam capture template for books
  (setq org-roam-capture-templates
        '(("d" "default" plain "%?"
           :target (file+head "%<%Y%m%d%H%M%S>-${slug}.org" "#+title: ${title}\n")
           :unnarrowed t)
          ("b" "book" plain "%?"
           :target (file+head "books/%<%Y%m%d%H%M%S>-${slug}.org"
                              ":PROPERTIES:
:Author: %^{Author}
:Year:   %^{Year}
:Status: %^{Status|Reading|Finished|To Read}
:END:
#+title: ${title}
#+filetags: :book:

* Summary")
           :unnarrowed t))))

(setq pgtk-use-im-context-on-new-connection nil) ; Helps with some rendering bugs
;; To specifically hide the title bar text but keep the frame:
(setf (alist-get 'drag-internal-border default-frame-alist) t)
(setf (alist-get 'internal-border-width default-frame-alist) 5)

;; Log time of finished TODO
(setq org-log-done 'time)

;; make sure emacsclient is looking for the daemon in the correct directory
(setq server-socket-dir (format "/run/user/%d/emacs" (user-real-uid)))

;; Background transparency
(set-frame-parameter nil 'alpha-background 90) ; For the current frame
(add-to-list 'default-frame-alist '(alpha-background . 90)) ; For all future frames

(setq treemacs-is-never-other-window nil)

;; Some functionality uses this to identify you, e.g. GPG configuration, email
;; clients, file templates and snippets. It is optional.
;; (setq user-full-name "John Doe"
;;       user-mail-address "john@doe.com")

;; Doom exposes five (optional) variables for controlling fonts in Doom:
;;
;; - `doom-font' -- the primary font to use
;; - `doom-variable-pitch-font' -- a non-monospace font (where applicable)
;; - `doom-big-font' -- used for `doom-big-font-mode'; use this for
;;   presentations or streaming.
;; - `doom-symbol-font' -- for symbols
;; - `doom-serif-font' -- for the `fixed-pitch-serif' face
;;
;; See 'C-h v doom-font' for documentation and more examples of what they
;; accept. For example:
;;
;;(setq doom-font (font-spec :family "Fira Code" :size 12 :weight 'semi-light)
;;      doom-variable-pitch-font (font-spec :family "Fira Sans" :size 13))
;;
;; If you or Emacs can't find your font, use 'M-x describe-font' to look them
;; up, `M-x eval-region' to execute elisp code, and 'M-x doom/reload-font' to
;; refresh your font settings. If Emacs still can't find your font, it likely
;; wasn't installed correctly. Font issues are rarely Doom issues!

;; There are two ways to load a theme. Both assume the theme is installed and
;; available. You can either set `doom-theme' or manually load a theme with the
;; `load-theme' function. This is the default:
(setq doom-theme 'catppuccin)

;; This determines the style of line numbers in effect. If set to `nil', line
;; numbers are disabled. For relative line numbers, set this to `relative'.
(setq display-line-numbers-type t)

;; If you use `org' and don't want your org files in the default location below,
;; change `org-directory'. It must be set before org loads!
(setq org-directory "~/org/")

(after! org
  (setq org-agenda-files
        (list (expand-file-name "~/org/agenda") (expand-file-name "~/org/inbox.org")))
  (setq +org-capture-todo-file "inbox.org"))


;; Whenever you reconfigure a package, make sure to wrap your config in an
;; `after!' block, otherwise Doom's defaults may override your settings. E.g.
;;
;;   (after! PACKAGE
;;     (setq x y))
;;
;; The exceptions to this rule:
;;
;;   - Setting file/directory variables (like `org-directory')
;;   - Setting variables which explicitly tell you to set them before their
;;     package is loaded (see 'C-h v VARIABLE' to look up their documentation).
;;   - Setting doom variables (which start with 'doom-' or '+').
;;
;; Here are some additional functions/macros that will help you configure Doom.
;;
;; - `load!' for loading external *.el files relative to this one
;; - `use-package!' for configuring packages
;; - `after!' for running code after a package has loaded
;; - `add-load-path!' for adding directories to the `load-path', relative to
;;   this file. Emacs searches the `load-path' when you load packages with
;;   `require' or `use-package'.
;; - `map!' for binding new keys
;;
;; To get information about any of these functions/macros, move the cursor over
;; the highlighted symbol at press 'K' (non-evil users must press 'C-c c k').
;; This will open documentation for it, including demos of how they are used.
;; Alternatively, use `C-h o' to look up a symbol (functions, variables, faces,
;; etc).
;;
;; You can also try 'gd' (or 'C-c c d') to jump to their definition and see how
;; they are implemented.

