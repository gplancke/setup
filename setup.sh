#!/bin/bash

HERE="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

#############################################
# This function asks for a password if none
# is already provided
#############################################

function read_pwd {
	maybePwd="$1"

	if [ -n "$maybePwd" ]; then
		echo "$maybePwd"
	else
		stty -echo
		printf "Password: "
		read PASSWORD
		stty echo
		printf "\n"

		echo $PASSWORD
	fi
}

#############################################
# This function is used across the setup.sh
# It used to detect the current distro/os
# and return it as a string
#############################################

function detect_distro {
  if [[ $OSTYPE == darwin* ]]; then
    echo "darwin"
  elif [[ $OSTYPE == linux-gnu* ]]; then
    echo "ubuntu"
  else
    echo "ubuntu"
  fi
}

#############################################
# Installs homebrew on darwin and linux
# On linux it installs linuxbrew
# We tend to use nix instead
#############################################

function install_brew {
  local osType=$1

  echo "Installing homebrew"

  if [ "$osType" = "darwin" ]; then
    [ -d "/opt/homebrew" ] || curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh | bash
    [ -d "/opt/homebrew" ] && eval "$(/opt/homebrew/bin/brew shellenv)"
  else
    [ -d "/home/linuxbrew/.linuxbrew" ] || [ -d "~/.linuxbrew" ] || \
      curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh | bash
    [ -d "/home/linuxbrew/.linuxbrew/bin" ] && eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    [ ! -d "/home/linuxbrew/.linuxbrew/bin" ] && [ -d "~/.linuxbrew/bin" ] && eval "$(~/.linuxbrew/bin/brew shellenv)"
  fi
}

#############################################
# Install ni on darwin and linux
# On darwin, we add the nix-darwin util
#############################################

function install_nix {
  local osType=$1

  if [ ! -d "$HOME/.nix-profile" ]; then
		echo "Installing Nix"
		curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
	  source $HOME/.nix-profile/etc/profile.d/nix.sh

		mkdir -p $HOME/.local/bin
		cat > $HOME/.local/bin/nix-uninstall << _EOF
#!/bin/bash

/nix/nix-installer uninstall
_EOF
		chmod +x $HOME/.local/bin/nix-uninstall

	  if [ "$osType" = "darwin" ]; then
	    source $HOME/.nix-profile/etc/profile.d/nix.sh
			nix-build https://github.com/LnL7/nix-darwin/archive/master.tar.gz -A installer
			./result/bin/darwin-installer
			cp ./result/bin/darwin-uninstaller $HOME/.local/bin
			rm -rf ./result/bin
	  fi
	else
		echo "Nix is already installed"
  fi
}

#############################################
# Install zsh plugin manager
# We want to replace this with a nix flake
#############################################

function install_zsh_manager {
  # Installing Antigen for zsh
  if [ ! -f "$HOME/.config/antigen/antigen.zsh" ]; then
    mkdir -p "$HOME/.config/antigen"
    curl -L git.io/antigen > $HOME/.config/antigen/antigen.zsh
  fi
}

#############################################
# Install tmux plugin manager (tpm)
# We want to replace this with a nix flake
# We also want to get rid of tmux
#############################################

function install_tmux_manager {
  [ ! -d "${HOME}/.tmux/plugins/tpm" ] && \
    git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
}

#############################################
# Add tmux powerline to tmux
# It is used to display the status bar
# Config is done inside main tmux config
# We want to replace this something builtin to the tmux nix flake
#############################################

function install_tmux_powerline {
  [ ! -d "${HOME}/.tmux/status/tmux-powerline" ] && \
    git clone https://github.com/erikw/tmux-powerline.git ~/.tmux/status/tmux-powerline
}

#############################################
# Install vim plugin manager
# We are not using this anymore
# In favor of Lazy which can bootstrap itself
#############################################

function install_vim_manager {
	echo "We use lazy plugin manager for neovim"
  # if [ ! -f "$HOME/.local/share/nvim/site/autoload/plug.vim" ]; then
  #   curl -fLo "${XDG_DATA_HOME:-$HOME/.local/share}"/nvim/site/autoload/plug.vim --create-dirs \
  #          https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
  # fi
}

#############################################
# Install theme manager
# Mainly base16 themes
# However, we tend to use catpuccin as mush as we can now
#############################################

function install_theme_manager {
  # echo "Installing theming"
  if [ ! -d "$HOME/.local/share/base16-manager" ]; then
    mkdir -p "$HOME/.local/share/base16-manager"
    git clone https://github.com/base16-manager/base16-manager.git \
      $HOME/.local/share/base16-manager && \
      cp $HOME/.local/share/base16-manager/base16-manager $HOME/.local/bin/
    $HOME/.local/bin/base16-manager install chriskempson/base16-shell
    $HOME/.local/bin/base16-manager install chriskempson/base16-vim
    $HOME/.local/bin/base16-manager install nicodebo/base16-fzf

    $HOME/.local/bin/base16-manager set ocean
  fi
}

#############################################
# Install binaries
# However we want to replace this w/ home-manager
# Home manager is installed alongside nix
#############################################

function install_bins {
  [ -f "$HERE/configfiles/nix/env.nix" ] \
    && nix-env -ir -f $dir/configfiles/nix/env.nix
}

function install_curl_and_git_if_needed {
	local hasNix=$(hash nix 2>/dev/null && echo "1" || echo "0")
	local hasBrew=$(hash brew 2>/dev/null && echo "1" || echo "0")
	if [ "$hasNix" -eq "1" ]; then
		hash curl 2>/dev/null || nix-env -i curl
		hash git 2>/dev/null || nix-env -i git
	elif [ "$hasBrew" -eq "1" ]; then
		hash curl 2>/dev/null || brew install curl
		hash git 2>/dev/null || brew install git
	else
		echo "Cannot install curl and git"
	fi
}

#############################################
# Some extra steps are needed after everything
# is installed
# For instance, switch to zsh as main shell
#############################################

function finishing_up {
  local dir="$1"
  local distro="$2"

  # hash nvim 2>/dev/null && nvim +PlugClean +PlugInstall +PlugUpdate +qa
  [ "$distro" != "darwin" ] && chsh -s /bin/zsh
}


#############################################
# Thin wrapper around dot.sh
# We might want to revisit this
# And simplify dotfiles management
#############################################

function dotfiles {
  local op=${1:-link}
	local pwd=$(read_pwd "${2}")

	local DOTFILES_URL="git@github.com:gplancke/dotfiles.git"
	local DOTFILES_CLONE_DIR="$HOME/.mydotfiles"
	local DOTFILES_SCRIPT_URL="https://raw.githubusercontent.com/gplancke/dotdot/main/dot.sh"

	echo "Installing dotfiles"

	[ ! -d "$DOTFILES_CLONE_DIR" ] && git clone $DOTFILES_URL $DOTFILES_CLONE_DIR
	[ ! -f "$HOME/.dotdot" ] && echo "$DOTFILES_CLONE_DIR" > "$HOME/.dotdot"
	[ ! -f "$HOME/.local/bin/dot.sh" ] && \
		curl -sSL $DOTFILES_SCRIPT_URL > "$HOME/.local/bin/dot.sh" \
		chmod +x "$HOME/.local/bin/dot.sh"

  "$HOME"/.local/dot.sh "$op" "$pwd"
}

#############################################
# This function installs the terminal environment
# It calls all the other functions
#############################################

function install_terminal() {
  local distro="$1"
	local pwd=$(read_pwd "${2}")

  # On Mac we must disable tls check for git temporarily
  hash git 2>/dev/null && git config --global http.sslVerify false

	# Creating needed directories
  mkdir -p $HOME/.local/{bin,share,etc,src}
  mkdir -p $HOME/.local/share/{node_modules,python_packages,gems,pnpm}
  mkdir -p $HOME/Workspace/Projects

	# Install brew and Nix
  case $distro in
    "ubuntu" | "debian")
      sudo apt update -y
      sudo apt upgrade -y
      sudo apt install -y build-essential curl git zsh fonts-hack-ttf

      install_brew "linux"
      install_nix "linux"

      brew install docker
      ;;
    "darwin")
      install_brew "darwin"
      install_nix "darwin"

      brew install zsh openssl
      brew tap homebrew/cask-fonts
      brew install font-hack-nerd-font
      brew install docker docker-compose

      # Install a working version of cocoapods
      brew uninstall --force ruby
      arch -x86_64 gem install ffi
      arch -x86_64 gem install cocoapods
      ;;
    *)
      echo "Not supported right now"
      ;;
  esac


	# Install nix packages
  install_bins
	# Basically at this point, we will need curl and git at least
	install_curl_and_git_if_needed
	# Install all plugins managers
  install_zsh_manager
  install_vim_manager
  install_tmux_manager
  install_tmux_powerline
  install_theme_manager

  dotfiles link $pwd

  finishing_up "${HERE}" "${distro}"

  hash git 2>/dev/null && git config --global http.sslVerify true
  echo "Done installing. You should login and logout again"
}

#############################################
# This function installs the GUI environment
# It installs all the GUI apps through homebrew
#############################################

function install_gui() {
	local distro="$1"

	if [ "$distro" = "ubuntu" ]; then
		echo "No GUI Apps for Ubuntu"
	elif [ "$distro" = "darwin" ]; then
		[ -z "$(xcode-select -p | grep 'Xcode.app')" ] \
			&& [ -z "$(xcode-select -p | grep 'CommandLineTools')" ] \
			&& xcode-select --install

		brew install --cask \
			flotato \
			rectangle \
			nordvpn \
			bitwarden \
			knockknock \
			netiquette \
			oversight \
			tailscale \
			raycast \
			setapp \ # App is paying
			# synergy
		# Media
		brew install --cask \
			vlc \
			obs \
			tunein \
			spotify
		# Development
		brew install --cask \
			alacritty \
			hyper \
			virtualbox \
			google-chrome \
			visual-studio-code \
			android-studio \
			docker \
			podman-desktop \
			mongodb-compass \
			tableplus
			# linear \
		# Design
		brew install --cask \
			remarkable \
			figma \
			canva \
			framer
		# DIY
		brew install --cask \
			raspberry-pi-imager \
			balenaetcher \
			autodesk-fusion360 \
			easyeda \
			freecad \
			openscad \
			prusaslicer
		# Communications
		brew install --cask \
			zoom \
			microsoft-teams \
			discord \
			whatsapp
			# telegram \
			# slack \

		# Activate key repeat for Vscode
		defaults write com.microsoft.VSCode ApplePressAndHoldEnabled -bool false
		defaults write co.zeit.hyper ApplePressAndHoldEnabled -bool true

		echo "These apps are not installable from command line"
		echo "- yoink (copy/paste buffer) => https://apps.apple.com/fr/app/yoink-simple-glisser-d%C3%A9poser/id457622435?mt=12"
		echo "- neat (github notification) => https://neat.run/"
		echo "- spark (email client) => https://apps.apple.com/us/app/spark-email-app-by-readdle/id1176895641?mt=12"
		echo ""
		echo "Cool apps provider you might wnat to check"
		echo "- objective-see => https://objective-see.org/tools.html"
	else
		echo "Not supported right now"
	fi

}

#############################################
# This first installs the terminal environment
# And conditionally installs the GUI environment
# It also attempts to capture the password needed
# To decrypt the secrets during dotfiles link phase
#
# We might want to revisit this
# As it is not very clean to pass down the password
# all the way down to the vault function
# buried in another script fetched from github
#
# We do this instead of asking for a password
# directly in the vault function in order for the user
# not to have to wait for the vault function to be called
# which can happen after a long time
#############################################

function install() {
	local distro="$(detect_distro)"
	local opts="$1"
	local pwd=$(read_pwd)

	install_terminal $distro $pwd

	if [ ${opts} = "-gui" ] ; then
		install_gui $distro
	fi
}

function printHelp {
  echo "-------------------------"
  echo ""
  echo "Options for terminal env setup"
  echo ""
  echo "  dot link|save|register: Call subscript to manage dotfiles"
  echo "  install [-gui]: Install the environment"
  echo ""
  echo "------"
  echo ""
}

operation="$1"
options="$2"

case $operation in
  dot)
    dotfiles "${options}"
    ;;
  install)
    install "${options}"
    ;;
  *)
    printHelp

esac

#############################################
#############################################
#############################################
#############################################
# END OF SCRIPT
#############################################
#############################################
#############################################
#############################################

#############################################
# This function installs the asdf version manager
# But we don't use it anymore
#############################################

# function install_asdf {
#   local osType=$1
#
#   echo "Installing ASDF"
#
#   if [ ! -d "$HOME/.local/share/asdf" ]; then
#     local cwd=$(pwd)
#
#     git clone https://github.com/asdf-vm/asdf.git $HOME/.local/share/asdf \
#       && cd $HOME/.local/share/asdf \
#       && git checkout "$(git describe --abbrev=0 --tags)" \
#       && cd $cwd
#
#     [ -f "$HOME/.local/share/asdf/asdf.sh" ]  && . $HOME/.local/share/asdf/asdf.sh
#   fi
#
# }

