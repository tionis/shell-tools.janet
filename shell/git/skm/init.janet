(import ./parser :export true)
(import spork/path)
(import spork/sh)

(defn git/loud [& args] (sh/exec "git" "-C" (dyn :repo-path) ;args))
(defn git/fail [& args] (sh/exec-fail "git" "-C" (dyn :repo-path) ;args))
(defn git/slurp [& args] (sh/exec-slurp "git" "-C" (dyn :repo-path) ;args))
(defn git/slurp-all [& args] (sh/exec-slurp-all "git" "-C" (dyn :repo-path) ;args))

(defn is-in-dir [child parent]
  (not (deep= (first (path/parts (path/relpath parent child))) "..")))

(def- worktree-list-pattern
  (peg/compile ~{:item (replace (* "worktree "
                                   (capture (to "\0")) "\0HEAD "
                                   (capture (to "\0")) "\0branch "
                                   (capture (to "\0\0")) "\0\0")
                                ,|{:path $0 :head $1 :branch $2})
                 :main (some :item)}))

(defn worktree/list [dir] (peg/match worktree-list-pattern (sh/exec-slurp "git" "-C" dir "worktree" "list" "--porcelain" "-z")))

(defn git/symbolic-full-name [repo name]
  (sh/exec-slurp "git" "-C" repo "rev-parse" "--symbolic-full-name" "main"))

(defn git/get-work-tree [path]
  (def path "/home/tionis/.glyph")
  (def ret (sh/exec-slurp-all "git" "-C" path "rev-parse" "--show-toplevel"))
  (if (= (ret :status) 0)
    (ret :out)
    (let [worktrees (worktree/list path)
          allowed-signers-branch (sh/exec-slurp "git" "-C" path "config" "skm.allowedSignersBranch")]
      (if (and allowed-signers-branch (not= allowed-signers-branch ""))
        (let [branch-full-name (git/symbolic-full-name path allowed-signers-branch)
              worktree-by-branch-name (group-by |($0 :branch) worktrees)]
          (get-in worktree-by-branch-name [branch-full-name 0 :path]))
        ((first worktrees) :path)))))

(defn git-dir [&opt repo]
  (default repo (dyn :repo-path))
  (if (dyn :git-dir)
    (dyn :git-dir)
    (let [git-dir (path/join repo (sh/exec-slurp "git" "-C" repo "rev-parse" "--git-dir"))]
      (setdyn :git-dir git-dir)
      git-dir)))

(defn allowed-signers-relative-path [&opt repo]
  (default repo (dyn :repo-path))
  (if (dyn :allowed-signers-relative-path)
    (dyn :allowed-signers-relative-path)
    (let [result (sh/exec-slurp-all "git" "-C" repo "config" "--local" "skm.allowedSignersFile")]
      (if (and (= (result :status) 0)
               (result :out)
               (not= (result :out) ""))
        (setdyn :allowed-signers-relative-path (result :out))
        (setdyn :allowed-signers-relative-path ".allowed_signers")))))

(defn trust
  "set trust anchor"
  [commit]
  (if commit
    (git/fail "config" "skm.last-verified-commit" commit)
    (git/fail "config" "skm.last-verified-commit")))

(defn get-tmp-dir [] # TODO replace this horrible hack
  (def p (path/join "/tmp" (string/format "%j" (math/floor (* 10000000 (math/random) (os/clock))))))
  (os/mkdir p)
  p)

(defn ssh-verify [data signature allowed-signers &named namespace]
  (default namespace "git")
  (def tmp-dir (get-tmp-dir))
  (def allowed-signers-file (path/join tmp-dir "allowed_signers"))
  (spit allowed-signers-file allowed-signers)
  (def signature-file (path/join tmp-dir "commit.sig"))
  (spit signature-file signature) # TODO hotfix
  (spit (path/join tmp-dir "commit") data)
  (def principal
    (sh/exec-slurp "ssh-keygen" "-Y" "find-principals" "-s" signature-file "-f" allowed-signers-file))
  (def proc (os/spawn ["ssh-keygen"
                       "-Y" "verify"
                       "-f" allowed-signers-file
                       "-n" namespace
                       "-s" signature-file
                       "-I" principal] :p {:in :pipe}))
  (ev/write (proc :in) data)
  (ev/close (proc :in))
  (os/proc-wait proc)
  (if (not= (proc :return-code) 0)
    (error "could not verify commit signature"))
  true)

(defn verify-one-commit
  "verify a commit using the allowed_signers files from it's parent trees"
  [commit]
  (def allowed_signers (git/slurp "show" (string commit "^:" (allowed-signers-relative-path)))) # TODO use real plumbing command
  (def parsed-commit (parser/parse-commit (git/slurp "cat-file" "-p" commit)))
  (def commit-without-sig (parser/render-commit (put (struct/to-table parsed-commit) :gpgsig nil)))
  (if (not (parsed-commit :gpgsig)) (error "commit not signed"))
  (ssh-verify commit-without-sig (parsed-commit :gpgsig) allowed_signers))

(defn check-allowed-signers
  []
  (def allowed_signers_path (git/slurp "config" "gpg.ssh.allowedSignersFile"))
  (unless (is-in-dir allowed_signers_path (git-dir))
    (def basedir (path/dirname allowed_signers_path))
    (if (or (= (sh/exec-slurp "git" "-C" basedir "rev-parse" "--is-inside-git-dir") "true")
            (= (sh/exec-slurp "git" "-C" basedir "rev-parse" "--is-inside-work-tree") "true"))
      (do (setdyn :repo-path (git/get-work-tree basedir))
          (eprint "warning: allowed_signers file is in another git-repo, checking it instead"))
      (error "allowed-signers outside of git-repo and not in another git-repo, nothing to check"))))

(defn generate-allowed-signers
  "generate the allowed_signers file using a previously set trust anchor"
  [commit]
  (check-allowed-signers)
  (var last-verified-commit "")
  (try
    (set last-verified-commit (git/slurp "config" "skm.last-verified-commit"))
    ([err] (error (string "could not get trust anchor: " err))))
  (if (or (not last-verified-commit) (= last-verified-commit "")) (error "No last verified commit set"))
  (def all_commits (string/split "\n" (git/slurp "rev-list" commit "--" (allowed-signers-relative-path))))
  (def commits-to-verify @[])
  (var found_commit false)
  (each commit all_commits
    (when (= commit last-verified-commit)
      (set found_commit true)
      (break))
    (array/push commits-to-verify commit))
  (unless found_commit (error "could not find last-verified-commit in current history"))
  (each commit (reverse commits-to-verify)
    (verify-one-commit commit)
    (set last-verified-commit commit))
  (trust last-verified-commit)
  (def allowed-signers-cache-file (path/join (git-dir) "allowed_signers"))
  (spit allowed-signers-cache-file (git/slurp "show" (string commit ":" (allowed-signers-relative-path))))
  (git/fail "config" "gpg.ssh.allowedSignersFile" allowed-signers-cache-file)
  (print "allowed_signers was verified and copied into git_dir"))

(defn verify-commit
  [commit]
  (generate-allowed-signers (git/slurp "rev-parse" commit))
  (git/loud "verify-commit" commit))
