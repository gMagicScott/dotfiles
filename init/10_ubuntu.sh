# If the old files isn't removed, the duplicate APT alias will break sudo!
sudoers_old="/etc/sudoers.d/sudoers-cowboy"; [[ -e "$sudoers_old" ]] && sudo rm "$sudoers_old"

# Installing this sudoers file makes life easier.
sudoers_file="sudoers-dotfiles"
sudoers_src=~/.dotfiles/conf/ubuntu/$sudoers_file
sudoers_dest="/etc/sudoers.d/$sudoers_file"
if [[ ! -e "$sudoers_dest" || "$sudoers_dest" -ot "$sudoers_src" ]]; then
  cat <<EOF
The sudoers file can be updated to allow certain commands to be executed
without needing to use sudo. This is potentially dangerous and should only
be attempted if you are logged in as root in another shell.

This will be skipped if "Y" isn't pressed within the next 15 seconds.
EOF
  read -N 1 -t 15 -p "Update sudoers file? [y/N] " update_sudoers; echo
  if [[ "$update_sudoers" =~ [Yy] ]]; then
    e_header "Updating sudoers"
    visudo -cf "$sudoers_src" >/dev/null && {
      sudo cp "$sudoers_src" "$sudoers_dest" &&
      sudo chmod 0440 "$sudoers_dest"
    } >/dev/null 2>&1 &&
    echo "File $sudoers_dest updated." ||
    echo "Error updating $sudoers_dest file."
  else
    echo "Skipping."
  fi
fi


# Update APT.
e_header "Updating APT"
sudo apt-get -qq update
sudo apt-get -qq upgrade

# Install APT packages.
packages=(
  build-essential libssl-dev
  git-core
  tree sl id3tool
  nmap telnet
  htop
  libxslt-dev libxml2-dev
)

list=()
for package in "${packages[@]}"; do
  if [[ ! "$(dpkg -l "$package" 2>/dev/null | grep "^ii  $package")" ]]; then
    list=("${list[@]}" "$package")
  fi
done

if (( ${#list[@]} > 0 )); then
  e_header "Installing APT packages: ${list[*]}"
  for package in "${list[@]}"; do
    sudo apt-get -qq install "$package" &> /dev/null
    if [ $? -eq 0 ]; then
      e_success "$package successfully installed"
    fi
  done
fi


# Install Git Extras
if [[ ! "$(type -P git-extras)" ]]; then
  e_header "Installing Git Extras"
  (
    cd ~/.dotfiles/libs/git-extras &&
    sudo make install
  )
fi

# Install CrashPlan
if [[ ! "$(type -P /usr/local/bin/CrashPlanDesktop)" ]]; then
  e_header "Installing CrashPlan"
  pushd /tmp &> /dev/null
    mkdir CrashPlan && cd CrashPlan
    curl -L http://download.crashplan.com/installs/linux/install/CrashPlan/CrashPlan_3.5.3_Linux.tgz | tar -zx
    cd CrashPlan-install
    # Lots of SED to answer all the questions with the defaults...
    sed -i 's@more ./EULA.txt@@' install.sh
    sed -i 's@read YN_PD@@' install.sh
    sed -i 's@read JAVADL@@' install.sh
    sed -i 's@read ENTER@@' install.sh
    sed -i 's@agreed=0@agreed=1@' install.sh
    sed -i 's@read TARGETDIR_X@@' install.sh
    sed -i 's@read BINSDIR_X@@' install.sh
    sed -i 's@read MANIFESTDIR_X@@' install.sh
    sed -i 's@read INITDIR_X@@' install.sh
    sed -i 's@read RUNLVLDIR_X@@' install.sh
    sed -i 's@read YN@@' install.sh
    # Recall skips some parts so I don't need to SED for it
    sudo .`pwd`/install.sh
    if [ $? -eq 0 ]; then
      e_success "CrashPlan successfully installed"
    else
      e_error "CrashPlan install failed, aborting"
      sleep 20
      exit 1
    fi
  popd
fi

# Install Chef
if [[ ! "$(type -P chef-solo)" ]]; then
  e_header "Installing Opscode Chef"
  curl -L https://www.opscode.com/chef/install.sh | sudo bash
fi

# Use Built-In ruby that we get from chef
if [[ ! "$(type -P /opt/chef/embedded/bin/berks)" ]]; then
  e_header "Installing Berkshelf"
  sudo /opt/chef/embedded/bin/gem install berkshelf --no-ri --no-rdoc
fi

cd $HOME/.dotfiles/chef && /opt/chef/embedded/bin/berks install --path cookbooks && sudo chef-solo -c solo.rb -j solo.json
