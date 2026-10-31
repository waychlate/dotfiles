;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-

;; Place your private configuration here! Remember, you do not need to run 'doom
;; sync' after modifying this file!

(setq doom-font (font-spec :family "Iosevka Nerd Font" :size 14))
;; (setq doom-variable-pitch-font (font-spec :family "Iosevka Aile" :size 12))
(setq doom-variable-pitch-font (font-spec :family "Overpass" :size 12))

(setq org-preview-latex-default-process 'dvisvgm)

;; Turn off number lines for files that aren't code
(add-hook 'prog-mode-hook 'display-line-numbers-mode)
(setq-default display-line-numbers-width 3)

(setq-default cursor-type 'bar)

(setq browse-url-browser-function 'browse-url-generic
      browse-url-generic-program "firefox") ; Replace "firefox" with "chrome" or "safari" if preferred


(use-package! writeroom-mode
  :defer t)

(use-package! org-super-agenda
  :after org
  :config
  (setq org-super-agenda-header-prefix "\n❯ ")
  ;; Hide the thin width char glyph
  (add-hook 'org-agenda-mode-hook
            #'(lambda () (setq-local nobreak-char-display nil)))
  (org-super-agenda-mode))

(after! org
  (setq org-agenda-files
        (append (directory-files-recursively "~/org/agenda/" "\\.org$")
                (list (expand-file-name "~/org/inbox.org"))))
  
  (setq org-icalendar-combined-description "My Unified Emacs Agenda"
        org-icalendar-timezone "America/New-York"
        org-icalendar-date-time-format ":%Y%m%dT%H%M%S"
        org-icalendar-combined-agenda-file "~/org/org-agenda.ics"
        org-icalendar-categories '(all-tags category todo-state))

  (setq org-icalendar-include-todo nil)

  (setq org-icalendar-exclude-todo-categories nil)
  (setq org-icalendar-use-deadline '(event-if-todo event-if-not-todo))
  (setq org-icalendar-use-scheduled '(event-if-todo event-if-not-todo))

  (setq org-agenda-default-appointment-duration 60)

  (defun my/org-gcal-api-push ()
    "Compiles the date-locked local .ics file and hands it to Python for instant API streaming."
    ;; 1. Regenerate the .ics only when an agenda file was saved since the last export
    ;;    (the export blocks Emacs ~2s, and this runs on every focus change)
    (when (seq-some (lambda (f) (file-newer-than-file-p f org-icalendar-combined-agenda-file))
                    (org-agenda-files))
      (org-icalendar-combine-agenda-files))
    ;; 2. Run the python script asynchronously from its directory
    (let ((default-directory "/home/doa/org/gcal/"))
      (start-process "gcal-api-sync" nil
                     "python" "gcal_sync.py")))

  ;; Tie the script to save actions
  (add-function :after after-focus-change-function
                (lambda ()
                  (unless (frame-focus-state)
                    (my/org-gcal-api-push))))

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
  ;; computed when a buffer opens: at daemon startup there's no frame, so :height is 1
  (add-hook 'org-mode-hook
            (lambda ()
              (setq org-format-latex-options
                    (plist-put org-format-latex-options :scale
                               (* (/ (float (face-attribute 'default :height)) 100.0) 1.5))))
            -90)

  ;; get rid of superfluous indents 
  (setq adaptive-fill-mode nil)

  ;; org-modern config
  (use-package! org-modern
    :hook (org-mode . org-modern-mode)
    :config
    (setq org-modern-star 'replace
          org-modern-list '((43 . "•") (45 . "◆") (42 . "→")))
    (let ((green (doom-color 'green))
          (orange (doom-color 'orange))
          (red   (doom-color 'red))
          (base  (doom-color 'base)))
      (setq org-modern-todo-faces
            `(("TODO" :background ,green :foreground ,base :weight bold)
              ("NEXT" :background ,orange :foreground ,base :weight bold)
              ("HOLD" :background ,red   :foreground ,base :weight bold))))
    )

  ;; Customizing org text
  (setq org-adapt-indentation nil)
  (setq org-startup-indented t)
  (setq org-hide-emphasis-markers t)

  ;; try leading if t doesn't work
  (setq org-modern-hide-stars nil)
  (setq org-pretty-entities t)
  (setq org-ellipsis " ·")
  (setq org-startup-with-inline-images t)

  ;; Turn off org-mode indents
  ;; (add-hook 'org-mode-hook (lambda () (org-indent-mode -1)))

  (use-package! org-appear
    :commands (org-appear-mode)
    :hook     (org-mode . org-appear-mode)
    :config
    (setq org-appear-autoemphasis   t   ; Show bold, italics, verbatim, etc.
          org-appear-autolinks      t   ; Show links
	  org-appear-autosubmarkers t)) ; Show sub- and superscripts


  ;; Org capture templates
  (setq org-capture-templates
        `(("i" "Inbox" entry (file "inbox.org")
           ,(concat "* TODO %?\n"
                    "/Entered on/ %U"))
          ("e" "Event" entry  (file+headline "agenda/calendar.org" "Future")
           "* %?\n%^T")
          ))

  (add-hook 'org-mode-hook 'visual-line-mode)
  (add-hook 'org-mode-hook 'olivetti-mode)

  ;; Refile
  (setq org-refile-use-outline-path 'file)
  (setq org-outline-path-complete-in-steps nil)

  (setq org-refile-targets
        `(((,(expand-file-name "agenda/projects.org" org-directory)
            ,(expand-file-name "agenda/tasks.org" org-directory)) :maxlevel . 4)))

  (defun my/org-refile-projects-tasks-only-p ()
    "In projects.org, only accept headings at or under a \"tasks\" heading."
    (or (not (equal (buffer-file-name) (expand-file-name "agenda/projects.org" org-directory)))
        (member "tasks" (org-get-outline-path t))))
  (setq org-refile-target-verify-function #'my/org-refile-projects-tasks-only-p)

  (defun my/org-refile-to-calendar ()
    "Refile the entry at point, offering only calendar.org headings."
    (interactive)
    (let ((org-refile-targets
           `((,(expand-file-name "agenda/calendar.org" org-directory) :maxlevel . 4))))
      (call-interactively #'org-refile)))
  (map! :map org-mode-map :localleader "s e" #'my/org-refile-to-calendar)

  ;; TODO state configuration
  (setq org-todo-keywords
        '((sequence "TODO(t)" "NEXT(n)" "HOLD(h)" "[ ](b)" "|" "DONE(d)")))
  (setq org-todo-keyword-faces
        '(("NEXT" . (:foreground "orange" :weight bold))
          ("HOLD" . (:foreground "red" :weight bold))))

  (defun log-todo-next-creation-date (&rest ignore)
    "Log NEXT creation time in the property drawer under the key 'ACTIVATED'"
    (when (and (string= (org-get-todo-state) "NEXT")
               (not (org-entry-get nil "ACTIVATED")))
      (org-entry-put nil "ACTIVATED" (format-time-string "[%Y-%m-%d]"))))
  (add-hook 'org-after-todo-state-change-hook #'log-todo-next-creation-date)

  ;; Tags (global; inbox.org used to carry its own file-local #+TAGS)
  (setq org-tag-persistent-alist '(("@home" . ?h) ("@phone" . ?p) ("@errand" . ?e)
                        ("work" . ?w) ("sideproject" . ?s) ("waiting" . ?W)
                        ("grind" . ?g) ("fun" . ?f)))

  ;; Agenda: effort column (blank effort shows ~0:30, the assumed default)
  (defun my/org-agenda-effort ()
    ;; Time-grid lines are formatted in the agenda buffer; skip them
    (if (derived-mode-p 'org-mode)
        (format "%-5s" (or (org-entry-get nil "EFFORT") "~0:30"))
      "     "))
  (setq org-agenda-prefix-format
        '((agenda . "  %i %-12:c %(my/org-agenda-effort) %?-12t% s")
          (todo   . "  %i %-12:c %(my/org-agenda-effort) ")
          (tags   . "  %i %-12:c %(my/org-agenda-effort) ")
          (search . "  %i %-12:c")))

  (defun my/org-today-header ()
    "Today header; warns when no :fun: item is scheduled and no deadline is within 48h."
    (let ((fun (org-map-entries #'point "+fun+SCHEDULED<=\"<today>\"/TODO|NEXT" 'agenda))
          (due (org-map-entries #'point "DEADLINE<=\"<+2d>\"/TODO|NEXT" 'agenda)))
      (concat "\nToday" (unless (or fun due) "  ⚠ no :fun: item picked") "\n")))

  (defun my/org-schedule-today ()
    "Schedule the item at point for today."
    (interactive)
    (let ((today (format-time-string "%Y-%m-%d")))
      (if (derived-mode-p 'org-agenda-mode)
          (org-agenda-schedule nil today)
        (org-schedule nil today))))
  (map! :map org-mode-map :localleader "d n" #'my/org-schedule-today)
  (map! :map org-agenda-mode-map :localleader "d n" #'my/org-schedule-today)

  (defun my/org-energy-view (next-match groups)
    "Deadlines + Today + rest of NEXT (NEXT-MATCH filtered, GROUPS for super-agenda) + inbox."
    (let ((skip-done '(org-agenda-skip-entry-if 'todo '("DONE" "HOLD"))))
      `((agenda ""
                ((org-agenda-span 1) (org-agenda-start-day "0d")
                 (org-agenda-entry-types '(:deadline))
                 (org-deadline-warning-days 7)
                 (org-agenda-skip-function ',skip-done)
                 (org-agenda-sorting-strategy '(deadline-up))
                 (org-agenda-overriding-header "\nDeadlines (next 7 days)\n")))
        (agenda ""
                ((org-agenda-span 7) (org-agenda-start-day "0d")
                 (org-agenda-entry-types '(:timestamp :sexp))
                 (org-agenda-show-all-dates nil)
                 (org-agenda-prefix-format "  %i %-12:c %?-12t")
                 (org-agenda-skip-function ',skip-done)
                 (org-agenda-overriding-header "\nEvents (next 7 days)\n")))
        (agenda ""
                ((org-agenda-span 1) (org-agenda-start-day "0d")
                 (org-agenda-entry-types '(:scheduled))
                 (org-scheduled-past-days 365)
                 (org-agenda-skip-function ',skip-done)
                 (org-agenda-overriding-header (my/org-today-header))))
        (tags-todo ,next-match
                   ((org-agenda-skip-function '(org-agenda-skip-entry-if 'scheduled))
                    (org-super-agenda-groups ',groups)
                    (org-agenda-overriding-header "\nRest of NEXT\n")))
        (tags-todo "inbox"
                   ((org-agenda-prefix-format "  %?-12t% s")
                    (org-agenda-overriding-header "\nInbox\n")))
        (tags "CLOSED>=\"<today>\""
              ((org-agenda-overriding-header "\nCompleted Today I suppose...\n"))))))

  (setq org-agenda-custom-commands
        `(("g" "What now? (any energy)" ,(my/org-energy-view "/NEXT" nil))
          ("l" "What now? (low energy: no grind)" ,(my/org-energy-view "-grind/NEXT" nil))
          ("h" "What now? (high energy: grind first)"
           ,(my/org-energy-view "/NEXT" '((:name "Grind" :tag "grind") (:name "Other" :anything t))))
          ("2" "Two Weeks Agenda"
           agenda ""
           ((org-agenda-span 14)
            (org-agenda-start-on-weekday nil)
            (org-agenda-start-day "0d")))))
  )

(after! org-download
  (setq org-download-screenshot-method "wl-paste -t image/png > %s")
  ;; This line is the "secret sauce" to stop the error message
  (setq org-download-screenshot-file "/tmp/screenshot.png"))

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
(set-frame-parameter nil 'alpha-background 95) ; For the current frame
(add-to-list 'default-frame-alist '(alpha-background . 95)) ; For all future frames

;; Buffer doesn't wait until cursor hits the bottom of the screen before it begins to scroll
(setq scroll-margin 8)

(setq +doom-dashboard-name "ace")

(defun my-custom-doom-banner ()
  (if (display-graphic-p)
      (let ((img (create-image (expand-file-name "banner.png" doom-user-dir)
                               nil nil :max-height 400)))
        (insert (make-string (max 0 (/ (- +doom-dashboard--width
                                          (round (car (image-size img)))) 2)) ?\s))
        (insert-image img)
        (insert "\n\n"))
    (insert (propertize (+doom-dashboard--center +doom-dashboard--width "e m a c s")
                        'face 'doom-dashboard-banner) "\n")))

(setq +doom-dashboard-functions (delete 'doom-dashboard-widget-banner +doom-dashboard-functions))
(add-to-list '+doom-dashboard-functions 'my-custom-doom-banner)

(custom-set-faces!
  '(doom-dashboard-banner :height 1.0))

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
;; 
;; (setq doom-theme 'catppuccin)
;; (setq doom-theme 'doom-ayu-mirage)
;; (setq doom-theme 'doom-nord-aurora)
(setq doom-theme 'doom-flatwhite) ;; This might be the greatest white-theme I've laid my eyes on

;; This determines the style of line numbers in effect. If set to `nil', line
;; numbers are disabled. For relative line numbers, set this to `relative'.
(setq display-line-numbers-type t)

;; If you use `org' and don't want your org files in the default location below,
;; change `org-directory'. It must be set before org loads!
(setq org-directory "~/org/")

(after! org
  (setq org-agenda-files
        (list (expand-file-name "~/org/agenda") (expand-file-name "~/org/inbox.org")))
  (setq +org-capture-todo-file "inbox.org")

  ;; Save the corresponding buffers
  (defun gtd-save-org-buffers ()
    "Save `org-agenda-files' buffers without user confirmation.
See also `org-save-all-org-buffers'"
    (interactive)
    (message "Saving org-agenda-files buffers...")
    (save-some-buffers t (lambda () 
                           (when (member (buffer-file-name) org-agenda-files) 
                             t)))
    (message "Saving org-agenda-files buffers... done"))

  ;; Add it after refile
  (advice-add 'org-refile :after
              (lambda (&rest _)
                (gtd-save-org-buffers)))
  )


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


;;; --- Journal (org-roam nodes in ~/org/roam/journal/) ---
(defvar my/journal-dir (expand-file-name "roam/journal/" org-directory))

(defun my/journal--keyword (key)
  "Value of #+KEY: in the current buffer, or \"\"."
  (save-excursion
    (goto-char (point-min))
    (if (re-search-forward (format "^#\\+%s:[ \t]*\\(.*\\)$" key) nil t)
        (match-string 1)
      "")))

(defun my/journal--entries ()
  "Plists (:file :date :series :title :special) for every journal entry."
  (mapcar
   (lambda (f)
     (with-temp-buffer
       (insert-file-contents f nil 0 4096)
       (list :file f
             :date (let ((d (my/journal--keyword "date")))
                     (if (string-match "[0-9]\\{4\\}-[0-9]\\{2\\}-[0-9]\\{2\\}" d)
                         (match-string 0 d)
                       ""))
             :series (my/journal--keyword "series")
             :title (my/journal--keyword "title")
             :special (my/journal--keyword "special"))))
   (when (file-directory-p my/journal-dir)
     (directory-files my/journal-dir t "\\.org\\'"))))

(defun my/journal-read-series ()
  "Pick an existing series, or create one after confirmation."
  (let* ((existing (delete-dups
                    (seq-remove #'string-empty-p
                                (mapcar (lambda (e) (plist-get e :series))
                                        (my/journal--entries)))))
         (new "➕ new series…")
         (pick (completing-read "Series: " (append existing (list new)) nil t)))
    (if (not (equal pick new))
        pick
      (let ((s (string-trim (read-string "New series name: "))))
        (if (and (not (string-empty-p s))
                 (y-or-n-p (format "Create new series \"%s\"? " s)))
            s
          (my/journal-read-series))))))

(defun my/journal--slug (title)
  (string-trim (downcase (replace-regexp-in-string "[^[:alnum:]]+" "-" title)) "-" "-"))

(defun my/journal-new ()
  "Create a journal entry: title, Date, series, special."
  (interactive)
  (let* ((title (string-trim (read-string "Title: ")))
         (time (progn (when (string-empty-p title) (user-error "Title required"))
                      (org-read-date nil t)))
         (series (my/journal-read-series))
         (special (read-string "Special (one line): "))
         (file (expand-file-name
                (format "%s-%s.org" (format-time-string "%F" time) (my/journal--slug title))
                my/journal-dir))
         (now (format-time-string "[%F %a %R]")))
    (when (file-exists-p file) (user-error "Already exists: %s" file))
    (make-directory my/journal-dir t)
    (find-file file)
    (insert (format ":PROPERTIES:\n:ID:          %s\n:CREATED:     %s\n:LAST_EDITED: %s\n:END:\n#+title: %s\n#+date: %s\n#+series: %s\n#+special: %s\n#+filetags: :journal:\n\n"
                    (org-id-new) now now title (format-time-string "[%F %a]" time) series special))
    (save-buffer)))

(defun my/journal-find ()
  "Browse journal entries, newest first."
  (interactive)
  (let* ((entries (sort (my/journal--entries)
                        (lambda (a b) (string> (plist-get a :date) (plist-get b :date)))))
         (cands (mapcar (lambda (e)
                          (cons (format "%s | %s | %s%s"
                                        (plist-get e :date) (plist-get e :series) (plist-get e :title)
                                        (if (string-empty-p (plist-get e :special)) ""
                                          (concat " — " (plist-get e :special))))
                                e))
                        entries))
         (pick (completing-read
                "Journal: "
                (lambda (str pred action)
                  (if (eq action 'metadata)
                      '(metadata (display-sort-function . identity))
                    (complete-with-action action cands str pred)))
                nil t)))
    (find-file (plist-get (cdr (assoc pick cands)) :file))))

(defun my/journal--touch-last-edited ()
  "Before-save hook: bump :LAST_EDITED: in journal entries."
  (when (and buffer-file-name (derived-mode-p 'org-mode)
             (file-in-directory-p buffer-file-name my/journal-dir))
    (save-excursion
      (org-with-wide-buffer
       (goto-char (point-min))
       (org-entry-put nil "LAST_EDITED" (format-time-string "[%F %a %R]"))))))
(add-hook 'before-save-hook #'my/journal--touch-last-edited)

(map! :leader
      (:prefix ("j" . "journal")
       :desc "New entry"  "n" #'my/journal-new
       :desc "Find entry" "f" #'my/journal-find))
;;; --- end journal ---
