(import spork/path :export true)

(defn- path/windows/home
  []
  (if-let [user-profile (os/getenv "USERPROFILE")]
    (break user-profile))
  (if-let [user-home-path (os/getenv "HOMEPATH")
           user-home-drive (os/getenv "HOMEDRIVE")]
    (break (path/join user-home-drive user-home-path)))
  (error "could not determine user directory"))

(defn- path/posix/home
  []
  (if-let [home (os/getenv "HOME")]
    (break home))
  # TODO use c binding here
  ##include <unistd.h>
  ##include <sys/types.h>
  ##include <pwd.h>
  #struct passwd *pw = getpwuid(getuid());
  #const char *homedir = pw->pw_dir;
  )

(defn- path/get-home
  []
  (case (os/which) # TODO check bsd/dragonfly/macos platforms for posix/home compability
    :windows (path/windows/home)
    :mingw (path/posix/home)
    :cygwin (path/posix/home)
    :macos (path/posix/home)
    :web (error "home directory not supported")
    :linux (path/posix/home)
    :freebsd (path/posix/home)
    :openbsd (path/posix/home)
    :netbsd (path/posix/home)
    :dragonfly (path/posix/home)
    :bsd (path/posix/home)
    :posix (path/posix/home)))

(defn- path/get-myself
  []
  (path/join (os/cwd) (get (dyn *args*) 0 ""))) # TODO this does not work in all cases, improve this!

(defn path/home
  `returns home directory of user, if input path parts are given
  they are merge with spork/path/join to get a combined path`
  [& parts]
  (path/join (path/get-home) ;parts))

(defn path/mydir
  `returns directory of currently executing script, if input path parts are given
  they are merge with spork/path/join to get a combined path`
  [& parts]
  (path/join (path/dirname (path/get-myself)) ;parts))

(defn path/myself
  `returns path of currently executing script, if input path parts are given
  they are merge with spork/path/join to get a combined path`
  [& parts]
  (path/join (path/get-myself) ;parts))
