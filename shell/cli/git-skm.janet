#!/bin/env janet
(import spork/sh)
(use ../git/skm/init)

(def zero-commit "0000000000000000000000000000000000000000")

(defn cli/trust [args]
  (setdyn :repo-path (os/cwd))
  (if (first args)
    (trust (first args))
    (error "no commit hash to trust given")))

(defn cli/generate-allowed-signers [args]
  (setdyn :repo-path (os/cwd))
  (generate-allowed-signers "HEAD"))

(defn cli/verify-commit [args]
  (setdyn :repo-path (os/cwd))
  (if (first args)
    (verify-commit (first args))
    (verify-commit "HEAD")))

(defn cli/hooks/update [refname oldrev newrev]
  (def excludeExisting ["--not" "--all"])
  (printf "%s %s %s" oldrev newrev refname)
  (when (not= newrev zero-commit)
    (def span
      (if (= oldrev zero-commit)
        (string/split "\n" (sh/exec-slurp "git" "rev-list" newrev ;excludeExisting))
        (string/split "\n" (sh/exec-slurp "git" "rev-list" (string oldrev ".." newrev) ;excludeExisting))))
    (setdyn :repo-path (os/cwd))
    (verify-commit newrev)
    (each commit span
      (try
        (os/execute ["git" "verify-commit" commit] :px) # TODO this does not update allowed_signers yet
        ([err] (error (string "could not verify signature of commit "
                              commit " due to: " err
                              "\nrejecting push")))))))

(defn cli/hooks/update-simple [refname oldrev newrev]
  (def excludeExisting ["--not" "--all"])
  (printf "%s %s %s" oldrev newrev refname)
  (when (not= newrev zero-commit)
    (setdyn :repo-path (os/cwd))
    (verify-commit newrev)))

(defn cli/hooks/pre-receive []
  (forever
    (def input (string/trimr (file/read stdin :line)))
    (if (= input "") (break))
    (def [oldrev newrev refname] (string/split " " input))
    (printf "%s %s %s" oldrev newrev refname)
    (cli/hooks/update refname oldrev newrev)))

(def cli/hooks/help-message
  `Available hooks:
    - update - check each commit of each pushed rev against a newly generated allowed_signers file
    - update-simple - like update but only check the last commit
    - pre-receive - simple hook that works like the update hook but checks all ref at the same time`)

(defn cli/hooks [args]
  (def hook-type (first args))
  (case hook-type
    "help" (print cli/hooks/help-message)
    "pre-receive" (cli/hooks/pre-receive)
    "update" (cli/hooks/update ;(slice args 1 -1))
    "update-simple" (cli/hooks/update-simple ;(slice args 1 -1))
    (do (print "unknown hook-type, showing help:\n" cli/hooks/help-message))))

(defn cli/help []
  (print `simple key management
         available subcommands:
           help - show this help
           generate - generate the allowed_signers file
           verify-commit - verify a specific commit (or HEAD if no commit ref was given)
           hook pre-receive - git hook handling (use in pre-receive hook via git-skm hook pre-receive "$@")
           trust - set trust anchor (this is the last commit hash that you trust)`))

(defn main [_ & args]
  (case (first args)
    "help" (cli/help)
    "verify-commit" (cli/verify-commit (slice args 1 -1))
    "generate" (cli/generate-allowed-signers (slice args 1 -1))
    "hook" (cli/hooks (slice args 1 -1))
    "trust" (cli/trust (slice args 1 -1))
    (cli/help)))
