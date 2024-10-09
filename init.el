;;; -*- lexical-binding: t; -*-
(defvar elpaca-installer-version 0.7)
(defvar elpaca-directory (expand-file-name "elpaca/" user-emacs-directory))
(defvar elpaca-builds-directory (expand-file-name "builds/" elpaca-directory))
(defvar elpaca-repos-directory (expand-file-name "repos/" elpaca-directory))
(defvar elpaca-order '(elpaca :repo "https://github.com/progfolio/elpaca.git"
                              :ref nil :depth 1
                              :files (:defaults "elpaca-test.el" (:exclude "extensions"))
                              :build (:not elpaca--activate-package)))
(let* ((repo  (expand-file-name "elpaca/" elpaca-repos-directory))
       (build (expand-file-name "elpaca/" elpaca-builds-directory))
       (order (cdr elpaca-order))
       (default-directory repo))
  (add-to-list 'load-path (if (file-exists-p build) build repo))
  (unless (file-exists-p repo)
    (make-directory repo t)
    (when (< emacs-major-version 28) (require 'subr-x))
    (condition-case-unless-debug err
        (if-let ((buffer (pop-to-buffer-same-window "*elpaca-bootstrap*"))
                 ((zerop (apply #'call-process `("git" nil ,buffer t "clone"
                                                 ,@(when-let ((depth (plist-get order :depth)))
                                                     (list (format "--depth=%d" depth) "--no-single-branch"))
                                                 ,(plist-get order :repo) ,repo))))
                 ((zerop (call-process "git" nil buffer t "checkout"
                                       (or (plist-get order :ref) "--"))))
                 (emacs (concat invocation-directory invocation-name))
                 ((zerop (call-process emacs nil buffer nil "-Q" "-L" "." "--batch"
                                       "--eval" "(byte-recompile-directory \".\" 0 'force)")))
                 ((require 'elpaca))
                 ((elpaca-generate-autoloads "elpaca" repo)))
            (progn (message "%s" (buffer-string)) (kill-buffer buffer))
          (error "%s" (with-current-buffer buffer (buffer-string))))
      ((error) (warn "%s" err) (delete-directory repo 'recursive))))
  (unless (require 'elpaca-autoloads nil t)
    (require 'elpaca)
    (elpaca-generate-autoloads "elpaca" repo)
    (load "./elpaca-autoloads")))
(add-hook 'after-init-hook #'elpaca-process-queues)
(elpaca `(,@elpaca-order))
(elpaca elpaca-use-package
  ;; Enable use-package :ensure support for Elpaca.
  (elpaca-use-package-mode))



(use-package emacs :ensure nil
  :bind (("M-o" . other-window)
         ("M-l" . downcase-dwim)
         ("M-u" . upcase-dwim)
         ("M-c" . capitalize-dwim)
         ("C-h '" . describe-char))
  :init
  ;; Configure backups. Put all of them in the separate directory.
  ;; Copied from the emacs wiki.
  (setq backup-by-copying t     ; don't clobber symlinks
        backup-directory-alist '(("." . "~/.saves/")) ; don't litter my fs tree
        delete-old-versions t
        kept-new-versions 6
        kept-old-versions 2
        version-control t)      ; use versioned backups
  ;; Disable audio bell on error
  (setq ring-bell-function 'ignore)

  ;; Emacs 28 and newer: Hide commands in M-x which do not work in the current
  ;; mode.  Vertico commands are hidden in normal buffers. This setting is
  ;; useful beyond Vertico.
  (setq read-extended-command-predicate #'command-completion-default-include-p)
  
  ;; Support opening new minibuffers from inside existing minibuffers.
  (setq enable-recursive-minibuffers t)

  ;; Spaces > tabs.
  ;; Use 4 spaces for tabs whenever possible.
  ;; Remember that there's `untabify' command which helps you convert tabs to spaces.
  (setq-default indent-tabs-mode nil)
  (setq-default tab-width 4)

  ;; Enable indentation+completion using the TAB key.
  ;; `completion-at-point' is often bound to M-TAB.
  (setq tab-always-indent 'complete)

  ;; Delete selection on typing
  (delete-selection-mode)

  ;; Enable clipboard synchronization on wayland.
  
  (when (= 0 (shell-command "wl-copy -v"))
    ;; credit: yorickvP on Github
    (setq wl-copy-process nil)
    (defun wl-copy (text)
      (setq wl-copy-process (make-process :name "wl-copy"
                                          :buffer nil
                                          :command '("wl-copy" "-f" "-n")
                                          :connection-type 'pipe
                                          :noquery t))
      (process-send-string wl-copy-process text)
      (process-send-eof wl-copy-process))
    (defun wl-paste ()
      (if (and wl-copy-process (process-live-p wl-copy-process))
          nil     ; should return nil if we're the current paste owner
        (shell-command-to-string "wl-paste -n | tr -d \r")))
    (setq interprogram-cut-function 'wl-copy)
    (setq interprogram-paste-function 'wl-paste))
  ;; Don't show the splash screen
  (setq inhibit-startup-message t)

  ;; Turn off some unneeded UI elements
  (menu-bar-mode -1)  ; Leave this one on if you're a beginner!
  (tool-bar-mode -1)
  (scroll-bar-mode -1)

  ;; Allow short answers
  (setopt use-short-answers t)

  ;; Ask confirmation on emacs exit
  (setq confirm-kill-emacs #'y-or-n-p))

(use-package multiple-cursors :ensure t :demand t
  :bind (("C-S-c C-S-c" . mc/edit-lines)
         ("C->" . mc/mark-next-like-this)
         ("C-<" . mc/mark-previous-like-this)
         ("C-c C-<" . mc/mark-all-like-this)
         ("C-S-<mouse-1>" . mc/add-cursor-on-click))
  :config
  ;; Don't ask to allow running command on all cursors.
  ;; If you want to disable this behavior for some functions
  ;; just add those in `mc/cmds-to-run-once'.
  (setq mc/always-run-for-all t))
(use-package expand-region :ensure t :demand t
  :bind ("C-=" . er/expand-region))

;;; Completions and other general must-have stuff.

;; Better completion for M-x
(use-package vertico :ensure t :demand t
  :init
  (vertico-mode))
;; Persist history over Emacs restarts. Vertico sorts by history position.
(use-package savehist
  :init
  (savehist-mode))

;; Fuzzy search for vertico
(use-package orderless :ensure t :demand t
  :init
  ;; Configure a custom style dispatcher (see the Consult wiki)
  ;; (setq orderless-style-dispatchers '(+orderless-consult-dispatch orderless-affix-dispatch)
  ;;       orderless-component-separator #'orderless-escapable-split-on-space)
  (setq completion-styles '(orderless basic)
        completion-category-defaults nil
        completion-category-overrides '((file (styles partial-completion)))))
;; Useful annotations for vertico
(use-package marginalia :ensure t :demand t
  :init
  (marginalia-mode))

;; General in-place auto completion
;; If you want more context-related completions consider `cape' package
(use-package corfu :ensure t :demand t
  :init
  (global-corfu-mode))
;; Use Dabbrev with Corfu!
(use-package dabbrev
  ;; Swap M-/ and C-M-/
  :bind (("M-/" . dabbrev-completion)
         ("C-M-/" . dabbrev-expand))
  :config
  (add-to-list 'dabbrev-ignored-buffer-regexps "\\` ")
  ;; Since 29.1, use `dabbrev-ignored-buffer-regexps' on older.
  (add-to-list 'dabbrev-ignored-buffer-modes 'doc-view-mode)
  (add-to-list 'dabbrev-ignored-buffer-modes 'pdf-view-mode)
  (add-to-list 'dabbrev-ignored-buffer-modes 'tags-table-mode))

;; Example configuration for Consult
(use-package consult :ensure t :demand t
  ;; Replace bindings. Lazily loaded due by `use-package'.
  :bind (;; C-c bindings in `mode-specific-map'
         ("C-c M-x" . consult-mode-command)
         ("C-c h" . consult-history)
         ("C-c k" . consult-kmacro)
         ("C-c m" . consult-man)
         ("C-c i" . consult-info)
         ("C-h t" . consult-theme)
         ([remap Info-search] . consult-info)
         ;; C-x bindings in `ctl-x-map'
         ("C-x M-:" . consult-complex-command) ;; orig. repeat-complex-command
         ("C-x b" . consult-buffer) ;; orig. switch-to-buffer
         ("C-x 4 b" . consult-buffer-other-window) ;; orig. switch-to-buffer-other-window
         ("C-x 5 b" . consult-buffer-other-frame) ;; orig. switch-to-buffer-other-frame
         ("C-x t b" . consult-buffer-other-tab) ;; orig. switch-to-buffer-other-tab
         ("C-x r b" . consult-bookmark)         ;; orig. bookmark-jump
         ("C-x p b" . consult-project-buffer) ;; orig. project-switch-to-buffer
         ;; Custom M-# bindings for fast register access
         ("M-#" . consult-register-load)
         ("M-'" . consult-register-store) ;; orig. abbrev-prefix-mark (unrelated)
         ("C-M-#" . consult-register)
         ;; Other custom bindings
         ("M-y" . consult-yank-pop) ;; orig. yank-pop
         ;; M-g bindings in `goto-map'
         ("M-g e" . consult-compile-error)
         ("M-g f" . consult-flymake) ;; Alternative: consult-flycheck
         ("M-g g" . consult-goto-line)   ;; orig. goto-line
         ("M-g M-g" . consult-goto-line) ;; orig. goto-line
         ("M-g o" . consult-outline) ;; Alternative: consult-org-heading
         ("M-g m" . consult-mark)
         ("M-g k" . consult-global-mark)
         ("M-g i" . consult-imenu)
         ("M-g I" . consult-imenu-multi)
         ;; M-s bindings in `search-map'
         ("M-s d" . consult-find) ;; Alternative: consult-fd
         ("M-s c" . consult-locate)
         ("M-s g" . consult-grep)
         ("M-s G" . consult-git-grep)
         ("M-s r" . consult-ripgrep)
         ("M-s l" . consult-line)
         ("M-s L" . consult-line-multi)
         ("M-s k" . consult-keep-lines)
         ("M-s u" . consult-focus-lines)
         ;; Isearch integration
         ("M-s e" . consult-isearch-history)
         :map isearch-mode-map
         ("M-e" . consult-isearch-history) ;; orig. isearch-edit-string
         ("M-s e" . consult-isearch-history) ;; orig. isearch-edit-string
         ("M-s l" . consult-line) ;; needed by consult-line to detect isearch
         ("M-s L" . consult-line-multi) ;; needed by consult-line to detect isearch
         ;; Minibuffer history
         :map minibuffer-local-map
         ("M-s" . consult-history) ;; orig. next-matching-history-element
         ("M-r" . consult-history)) ;; orig. previous-matching-history-element

  ;; Enable automatic preview at point in the *Completions* buffer. This is
  ;; relevant when you use the default completion UI.
  :hook (completion-list-mode . consult-preview-at-point-mode)

  ;; The :init configuration is always executed (Not lazy)
  :init

  ;; Optionally configure the register formatting. This improves the register
  ;; preview for `consult-register', `consult-register-load',
  ;; `consult-register-store' and the Emacs built-ins.
  (setq register-preview-delay 0.5
        register-preview-function #'consult-register-format)

  ;; Optionally tweak the register preview window.
  ;; This adds thin lines, sorting and hides the mode line of the window.
  (advice-add #'register-preview :override #'consult-register-window)

  ;; Use Consult to select xref locations with preview
  (setq xref-show-xrefs-function #'consult-xref
        xref-show-definitions-function #'consult-xref))
(use-package embark :ensure t :demand t
  :bind
  (("C-." . embark-act)         ;; pick some comfortable binding
   ("C-;" . embark-dwim)        ;; good alternative: M-.
   ("C-h B" . embark-bindings)) ;; alternative for `describe-bindings'
  :init
  ;; Optionally replace the key help with a completing-read interface
  (setq prefix-help-command #'embark-prefix-help-command)

  ;; Show the Embark target at point via Eldoc. You may adjust the
  ;; Eldoc strategy, if you want to see the documentation from
  ;; multiple providers. Beware that using this can be a little
  ;; jarring since the message shown in the minibuffer can be more
  ;; than one line, causing the modeline to move up and down:

  ;; (add-hook 'eldoc-documentation-functions #'embark-eldoc-first-target)
  ;; (setq eldoc-documentation-strategy #'eldoc-documentation-compose-eagerly)

  :config
  ;; Hide the mode line of the Embark live/completions buffers
  (add-to-list 'display-buffer-alist
               '("\\`\\*Embark Collect \\(Live\\|Completions\\)\\*"
                 nil
                 (window-parameters (mode-line-format . none)))))
(use-package embark-consult :ensure t :demand t
  :hook
  (embark-collect-mode . consult-preview-at-point-mode))

;; Show more useful information in eldoc
(use-package helpful :ensure t :demand t
  :bind (("C-h f" . helpful-callable)
         ("C-h v" . helpful-variable)
         ("C-h k" . helpful-key)
         ("C-h x" . helpful-command)))

(use-package tree-sitter :ensure t :demand t)
(use-package tree-sitter-langs :ensure t :demand t :after tree-sitter
  :init
  (global-tree-sitter-mode)
  ;; Awesome fast syntax highlighting!
  (add-hook 'tree-sitter-after-on-hook #'tree-sitter-hl-mode))


;;; More opinionated packages
(use-package rainbow-delimiters :ensure t :demand t
  :hook prog-mode)

;; Snippets!
(use-package tempel
  :bind (("M-+" . tempel-complete) ;; Alternative tempel-expand
         ("M-*" . tempel-insert))
  :init
  ;; Setup completion at point
  (defun tempel-setup-capf ()
    ;; Add the Tempel Capf to `completion-at-point-functions'.
    ;; `tempel-expand' only triggers on exact matches. Alternatively use
    ;; `tempel-complete' if you want to see all matches, but then you
    ;; should also configure `tempel-trigger-prefix', such that Tempel
    ;; does not trigger too often when you don't expect it. NOTE: We add
    ;; `tempel-expand' *before* the main programming mode Capf, such
    ;; that it will be tried first.
    (setq-local completion-at-point-functions
                (cons #'tempel-expand
                      completion-at-point-functions)))

  (add-hook 'conf-mode-hook 'tempel-setup-capf)
  (add-hook 'prog-mode-hook 'tempel-setup-capf)
  (add-hook 'text-mode-hook 'tempel-setup-capf))
(use-package tempel-collection :ensure t)

;; Lovely themes
(use-package ef-themes :ensure t :demand t
  :bind ("C-c t t" . ef-themes-toggle)
  :init
  (setq ef-themes-to-toggle '(ef-elea-dark ef-light ef-dream ef-night ef-autumn ef-maris-dark))
  ;; Disable all other themes to avoid awkward blending:
  (mapc #'disable-theme custom-enabled-themes)
  (load-theme 'ef-elea-dark :no-confirm))

(use-package hl-todo :ensure t :demand t
  :init
  (global-hl-todo-mode))

;; Newer version of transient package required for magit.
(use-package transient :ensure t)

(use-package magit :ensure t :demand t)

(use-package avy :ensure t :demand t
  :bind ("M-j" . avy-goto-char-timer)
  :config
  (setq avy-all-windows t
        avy-all-windows-alt nil
        avy-background t
        avy-single-candidate-jump nil))


(defun open-eshel-new-window ()
    (interactive)
    (split-window-below)
    (other-window 1)
    (eshell)
    (shrink-window 15)
    )


(global-set-key (kbd "C-O") #'open-eshel-new-window)
(setq ns-right-alternate-modifier nil)

;; org mode
(use-package org
  :ensure t
  :demand t
  :config
  (add-hook 'org-mode-hook #'org-indent-mode))
;;(use-package org-modern :ensure t :demand t)
;;(add-hook 'org-mode-hook #'org-modern-mode)


;;(set-face-attribute 'default nil :family "Iosevka")
(set-face-attribute 'variable-pitch nil :family "Iosevka Aile")


(modify-all-frames-parameters
 '((right-divider-width . 30)
   (internal-border-width . 30)))
(dolist (face '(window-divider
                window-divider-first-pixel
                window-divider-last-pixel))
  (face-spec-reset-face face)
  (set-face-foreground face (face-attribute 'default :background)))
(set-face-background 'fringe (face-attribute 'default :background))



(with-eval-after-load 'org (global-org-modern-mode))
(use-package org-download
  :ensure t
  :demand t
  :after org
  :defer nil
  :custom
  (org-image-actual-width 800)
  :bind
  ("C-M-y" . org-download-clipboard)
  :config
    (require 'org-download))
(setq-default org-download-image-dir "~/Notes/pngs/")

(setq org-image-actual-width (list 1050))



;; ekg
(use-package triples :ensure t :demand t)
(use-package ekg :ensure t :demand t
  :bind (("C-c n" . ekg-capture)
         ("C-c s" . ekg-show-notes-with-tag)
         ("C-c a" . ekg-show-notes-with-all-tags)
         ))

;; copilot mode
(elpaca (copilot :host github :repo "copilot-emacs/copilot.el" :files ("dist" "*.el"))
  (use-package copilot
    ;;:hook (prog-mode . copilot-mode)
    :config
    (define-key copilot-completion-map (kbd "C-<tab>") 'copilot-accept-completion)
    (define-key copilot-completion-map (kbd "C-n") 'copilot-next-completion)
    (define-key copilot-completion-map (kbd "C-p") 'copilot-previous-completion)
    (define-key copilot-completion-map (kbd "C-g") 'copilot-abort-completion)
    (define-key copilot-completion-map (kbd "C-h") 'copilot-help)
    (define-key copilot-completion-map (kbd "C-?") 'copilot-help)
    (define-key copilot-completion-map (kbd "C-k") 'copilot-cancel-completion)
    (define-key copilot-completion-map (kbd "C-SPC") 'copilot-accept-completion)

    ;; turn on/off copilot mode
    (global-set-key (kbd "C-c RET") 'copilot-mode)
    (global-set-key (kbd "C-c C-c") 'copilot-mode)
    
        
    (add-hook 'mode-hook
          (lambda ()
            (setq indent-tabs-mode nil)  ;; Use spaces instead of tabs
            (setq tab-width 4)           ;; Set tab width to 4 spaces
            (setq-default c-basic-offset 4)  ;; Set C-style indentation
            ))
    ))



;; language tool
(use-package languagetool
  :ensure t
  :defer t
  :commands (languagetool-check
             languagetool-clear-suggestions
             languagetool-correct-at-point
             languagetool-correct-buffer
             languagetool-set-language
             languagetool-server-mode
             languagetool-server-start
             languagetool-server-stop)
  :config
  (setq languagetool-java-arguments '("-Dfile.encoding=UTF-8")
        languagetool-console-command "/opt/homebrew/opt/languagetool/libexec/languagetool-commandline.jar"
        languagetool-server-command "/opt/homebrew/opt/languagetool/libexec/languagetool-server.jar"))



(use-package rustic :ensure t :demand t
  ;;(setq rustic-lsp-client 'eglot)
  )
;; Optional: Block until all essential packages are installed
(elpaca-wait)

;; java
(use-package dap-mode
  :ensure t
  :demand t
  )
(use-package lsp-java
  :ensure t
  :demand t
  :hook (java-mode . lsp)
  :config
  (add-hook 'java-mode-hook #'lsp)
  )
(use-package flycheck
  :ensure t
  :demand t
  :init (global-flycheck-mode))

(use-package projectile
  :ensure t
  :diminish projectile-mode
  :config
  (projectile-mode +1)
  ;; Optionally use default keymap prefix (C-c p)
  (define-key projectile-mode-map (kbd "C-c p") 'projectile-command-map))


(use-package lsp-ui
  :ensure t
  :commands lsp-ui-mode
  :after lsp-mode
  :hook (lsp-mode . lsp-ui-mode)
  :config
  (setq lsp-ui-sideline-enable t
        lsp-ui-sideline-show-hover t
        lsp-ui-doc-enable t
        lsp-ui-doc-position 'at-point  ;; Display doc at the point of the cursor
        lsp-ui-doc-header t
        lsp-ui-doc-include-signature t
        lsp-ui-peek-enable t
        lsp-ui-peek-show-directory t))


;; transparent
(defun toggle-transparency ()
   (interactive)
   (let ((alpha (frame-parameter nil 'alpha)))
     (set-frame-parameter
      nil 'alpha
      (if (eql (cond ((numberp alpha) alpha)
                     ((numberp (cdr alpha)) (cdr alpha))
                     ;; Also handle undocumented (<active> <inactive>) form.
                     ((numberp (cadr alpha)) (cadr alpha)))
               100)
          '(85 . 50) '(100 . 100)))))
 (global-set-key (kbd "C-c $") 'toggle-transparency)

(set-frame-parameter (selected-frame) 'alpha '(85 . 50))
(add-to-list 'default-frame-alist '(alpha . (85 . 50)))

;; Install all uninstalled packages
(elpaca-process-queues)
(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(package-selected-packages '(lsp-mode))
 '(warning-suppress-types '((use-package) (use-package))))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 )
