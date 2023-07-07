(import spork/path)

(defn- windows/home
  []
  (if-let [user-profile (os/getenv "USERPROFILE")]
    (break user-profile))
  (if-let [user-home-path (os/getenv "HOMEPATH")
           user-home-drive (os/getenv "HOMEDRIVE")]
    (break (path/join user-home-drive user-home-path)))
  (error "could not determine user directory"))

(defn- posix/home
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

(defn- get-home
  []
  (case (os/which) # TODO check bsd/dragonfly/macos platforms for posix/home compability
    :windows (windows/home)
    :mingw (posix/home)
    :cygwin (posix/home)
    :macos (posix/home)
    :web (error "home directory not supported")
    :linux (posix/home)
    :freebsd (posix/home)
    :openbsd (posix/home)
    :netbsd (posix/home)
    :dragonfly (posix/home)
    :bsd (posix/home)
    :posix (posix/home)))

(defn- get-myself
  []
  (path/join (os/cwd) (get (dyn *args*) 0 ""))) # TODO this does not work in all cases, improve this!

(defn home
  `returns home directory of user, if input path parts are given
  they are merge with spork/path/join to get a combined path`
  [& parts]
  (path/join (get-home) ;parts))

(defn mydir
  `returns directory of currently executing script, if input path parts are given
  they are merge with spork/path/join to get a combined path`
  [& parts]
  (path/join (path/dirname (get-myself)) ;parts))

(defn myself
  `returns path of currently executing script, if input path parts are given
  they are merge with spork/path/join to get a combined path`
  [& parts]
  (path/join (get-myself) ;parts))

(import spork/path :prefix "" :export true)
