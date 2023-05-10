(import ./dot-env)
(use ./which)

(def- cygwin-package-manager
  [:install (fn [& packages] (os/execute ["setup-x86_64.exe" "-q" "-P" (string/join packages ",")] :p))
   :uninstall (fn [& x] (error "Not implemented yet"))])

(defn- arch-pkg-manager []
  (cond
    (which "yay")
    [:package-manager :yay
     :aur true
     :install (fn [& pkgs] (os/execute ["yay" "-S" ;pkgs] :p))
     :uninstall (fn [& pkgs] (os/execute ["yay" "-Rns" ;pkgs] :p))]
    (which "paru")
    [:package-manager :paru
     :aur true
     :install (fn [& pkgs] (os/execute ["paru" "-S" ;pkgs] :p))
     :uninstall (fn [& pkgs] (os/execute ["paru" "-Rns" ;pkgs] :p))]
    [:package-manager :pacman
     :aur false
     :install (fn [& pkgs] (os/execute ["sudo" "pacman" "-S" ;pkgs] :p))
     :uninstall (fn [& pkgs] (os/execute ["sudo" "pacman" "-Rns" ;pkgs] :p))]))

(def- distro-id-map
  {"arch" [:distribution :arch]
   "debian" [:distribution :debian
             :package-manager :apt
             :install (fn [& pkgs] (os/execute ["sudo" "apt" "install" ;pkgs] :p))
             :uninstall (fn [& pkgs] (os/execute ["sudo" "apt" "remove" ;pkgs] :p))]
   "ubuntu" [:distribution :ubuntu
             :package-manager :apt
             :install (fn [& pkgs] (os/execute ["sudo" "apt" "install" ;pkgs] :p))
             :uninstall (fn [& pkgs] (os/execute ["sudo" "apt" "remove" ;pkgs] :p))]})

(defn- os-release-to-distro [os-release]
  (def os (or (distro-id-map (os-release "ID"))
              (distro-id-map (os-release "ID_LIKE"))
              [:distribution :unknown]))
  (case ((struct ;os) :distribution)
    :arch (array ;os ;(arch-pkg-manager))
    os))

(def- termux-package-manager
  [:package-manager :termux-pkg
   :install (fn [& pkgs] (os/execute ["pkg" "install" ;pkgs] :p))
   :uninstall (fn [& pkgs] (os/execute ["pkg" "remove" ;pkgs] :p))])

(defn- detect-linux-distro []
  (label distro
    (if (os/getenv "TERMUX_VERSION")
      (return distro (array :distribution :termux :version (os/getenv "TERMUX_VERSION") ;termux-package-manager)))
    (if-let [stat (os/stat "/etc/os-release") os-release (dot-env/parse (slurp "/etc/os-release"))]
      (return distro (os-release-to-distro os-release)))
    # TODO try executing lsb_release -si
    # TODO try reading /etc/lsb-release
    # TODO try reading /etc/debian_version
    [:distribution :unknown :version :unknown]))

(defn- detect-macos-version []
  [:version :unknown
   :package-manager :unknown])

(defn detect []
  (case (os/which)
    :windows {:os :windows :package-manager :unknown}
    :mingw {:os :mingw :package-manager :unknown}
    :cygwin (struct :os :cygwin :package-manager :cygwin :package ;cygwin-package-manager)
    :macos (struct :os :macos ;(detect-macos-version))
    :web {:os :web :package-manager :unknown}
    :linux (struct :os :linux ;(detect-linux-distro))
    :freebsd {:os :freebsd :package-manager :unknown}
    :openbsd {:os :openbsd :package-manager :unknown}
    :netbsd {:os :netbsd :package-manager :unknown}
    :dragonfly {:os :dragonfly :package-manager :unknown}
    :bsd {:os :bsd :package-manager :unknown}
    :posix {:os :posix :package-manager :unknown}))
