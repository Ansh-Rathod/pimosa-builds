#!/bin/bash
# This script is used by Pimosa starting from version 1.1.9 (build 19).
echo "v3"
# Set the HOME environment variable (if needed)
export HOME="$HOME"

# Homebrew treats a PTY as interactive and can ask [y/N] (unsupported macOS,
# source builds, overwrites). Force auto-yes so the user never has to type y.
export NONINTERACTIVE=1
export CI=1
export HOMEBREW_NO_ANALYTICS=1
export HOMEBREW_NO_ENV_HINTS=1

# Detect current shell
CURRENT_SHELL=$(basename "$SHELL")

# Source environment configuration files (suppress output)
if [ -f ~/.bash_profile ]; then source ~/.bash_profile &>/dev/null; fi
if [ -f ~/.bashrc ]; then source ~/.bashrc &>/dev/null; fi
if [ -f ~/.profile ]; then source ~/.profile &>/dev/null; fi
if [ -f ~/.zshrc ]; then source ~/.zshrc &>/dev/null; fi
if [ -f ~/.zprofile ]; then source ~/.zprofile &>/dev/null; fi
if [ -f ~/.zlogin ]; then source ~/.zlogin &>/dev/null; fi

# Determine the architecture
ARCH=$(uname -m)

# Set the default Homebrew installation path based on the architecture
if [[ "$ARCH" == "x86_64" ]]; then
  HOMEBREW_PREFIX="/usr/local"
else
  HOMEBREW_PREFIX="/opt/homebrew"
fi

# Function to prompt for password with Cancel button using AppleScript
prompt_password() {
    local attempt=$1
    local show_error=$2
    local dialog_text="Pimosa needs administrator access to install required libraries for image manipulation and video processing."
    
    # Add error message only if show_error is true
    if [ "$show_error" = "true" ]; then
        dialog_text="$dialog_text

❌ Incorrect password. Attempt $attempt of 3."
    fi

    osascript <<EOT
        try
            display dialog "$dialog_text" & return & return & "Please enter your password:" \
                default answer "" \
                with hidden answer \
                buttons {"Cancel", "OK"} \
                default button 2 \
                with icon caution
            return text returned of result
        on error
            return "CANCELLED"
        end try
EOT
}

# Function to validate password using sudo with proper error handling
validate_password() {
    local password="$1"
    echo "$password" | sudo -S -v >/dev/null 2>&1
    return $?
}

ask_for_password() {
  local MAX_ATTEMPTS=3
  local ATTEMPT=1
  local PASSWORD=""
  local SHOW_ERROR="false"
  
  # Ensure script is run on macOS
  if [[ "$(uname)" != "Darwin" ]]; then
      echo "❌ This script requires macOS due to AppleScript usage."
      return 1
  fi

  # Password prompt and validation loop
  while [ $ATTEMPT -le $MAX_ATTEMPTS ]; do
      # Clear any previous sudo cache
      sudo -k
      
      # Get password from prompt with attempt count and error state
      PASSWORD=$(prompt_password $ATTEMPT $SHOW_ERROR)
      
      # Handle Cancel button
      if [ "$PASSWORD" = "CANCELLED" ]; then
          echo "Installation canceled by the user."
          return 1
      fi
      
      # Check if password is empty
      if [ -z "$PASSWORD" ]; then
          SHOW_ERROR="true"
          ((ATTEMPT++))
          continue
      fi
      
      # Validate the password
      if validate_password "$PASSWORD"; then
          echo "✅ Sudo access granted."
          unset PASSWORD
          return 0
      else
          SHOW_ERROR="true"
          echo "❌ Incorrect password. Attempt $ATTEMPT of $MAX_ATTEMPTS."
          ((ATTEMPT++))
      fi
      
      sleep 1
  done

  # Check if maximum attempts were reached
  if [ $ATTEMPT -gt $MAX_ATTEMPTS ]; then
      echo "❌ Maximum password attempts reached. Please try again later."
      unset PASSWORD
      return 1
  fi

  trap 'echo ""; echo "❌ Script interrupted."; unset PASSWORD; exit 1' INT TERM
}

resolve_brew() {
  if [ -x "$HOMEBREW_PREFIX/bin/brew" ]; then
    echo "$HOMEBREW_PREFIX/bin/brew"
  elif [ -x /opt/homebrew/bin/brew ]; then
    echo /opt/homebrew/bin/brew
  elif [ -x /usr/local/bin/brew ]; then
    echo /usr/local/bin/brew
  elif command -v brew >/dev/null 2>&1; then
    command -v brew
  fi
}

load_brew_env() {
  BREW_BIN=$(resolve_brew)
  if [ -n "$BREW_BIN" ]; then
    eval "$("$BREW_BIN" shellenv)" >/dev/null 2>&1 || true
    BREW_BIN=$(resolve_brew)
  fi
}

fail_install() {
  local formula="$1"
  echo "Error: Failed to install $formula"
  echo -e "Error: An error occurred during one or more installations."
  exit 1
}

# brew has no apt-style -y for formulae; pipe yes so leftover [y/N] prompts
# in the PTY never block. --overwrite replaces colliding files without asking.
brew_install() {
  local formula="$1"
  if [ -z "$BREW_BIN" ]; then
    fail_install "$formula"
  fi
  if ! yes | "$BREW_BIN" install --overwrite "$formula"; then
    fail_install "$formula"
  fi
}

ffmpeg_bin_works() {
  local bin="$1"
  [ -x "$bin" ] || return 1
  local version_output
  version_output=$("$bin" -version 2>/dev/null)
  [ $? -eq 0 ] && [[ "$version_output" == *"ffmpeg version"* ]]
}

ffmpeg_has_subtitles() {
  local bin="$1"
  "$bin" -hide_banner -h filter=subtitles 2>/dev/null | grep -qi "Filter subtitles"
}

# ffmpeg-full is keg-only, so `which ffmpeg` often misses it (or finds slim ffmpeg).
collect_ffmpeg_candidates() {
  local prefix
  if [ -n "$BREW_BIN" ]; then
    prefix=$("$BREW_BIN" --prefix ffmpeg-full 2>/dev/null) || true
    if [ -n "$prefix" ]; then
      echo "$prefix/bin/ffmpeg"
    fi
  fi
  echo "/opt/homebrew/opt/ffmpeg-full/bin/ffmpeg"
  echo "/usr/local/opt/ffmpeg-full/bin/ffmpeg"
  echo "/opt/homebrew/bin/ffmpeg"
  echo "/usr/local/bin/ffmpeg"
  echo "/opt/local/bin/ffmpeg"
  if command -v ffmpeg >/dev/null 2>&1; then
    command -v ffmpeg
  fi
}

# Prefer ffmpeg-full / any ffmpeg that can burn subtitles.
resolve_ffmpeg_path() {
  local p fallback=""
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    ffmpeg_bin_works "$p" || continue
    if ffmpeg_has_subtitles "$p"; then
      echo "$p"
      return 0
    fi
    if [ -z "$fallback" ]; then
      fallback="$p"
    fi
  done < <(collect_ffmpeg_candidates | awk 'NF && !seen[$0]++')
  if [ -n "$fallback" ]; then
    echo "$fallback"
    return 0
  fi
  return 1
}

check_ffmpeg_full() {
  local path
  path=$(resolve_ffmpeg_path) || return 1
  ffmpeg_has_subtitles "$path"
}

# Function to check if ImageMagick is installed and working
check_imagemagick() {
  local version_output
  version_output=$(magick -version 2>/dev/null)
  if [ $? -eq 0 ] && [[ "$version_output" == *"ImageMagick"* ]]; then
    return 0
  fi
  return 1
}

# Function to check if ExifTool is installed and working
check_exiftool() {
  local version_output
  version_output=$(exiftool -ver 2>/dev/null)
  if [ $? -eq 0 ]; then
    return 0
  fi
  return 1
}

# Function to check if pdfcpu is installed and working
check_pdfcpu() {
  local version_output
  version_output=$(pdfcpu version 2>/dev/null)
  if [ $? -eq 0 ] && [[ "$version_output" == *"pdfcpu:"* ]]; then
    return 0
  fi
  return 1
}

check_ytdlp() {
  local version_output
  version_output=$(yt-dlp --version 2>/dev/null)
  if [ $? -eq 0 ]; then
    return 0
  fi
  return 1
}

load_brew_env

# Check if tools are installed and working
ffmpeg_exists=$(check_ffmpeg_full && echo true || echo false)
imagemagick_exists=$(check_imagemagick && echo true || echo false)
exiftool_exists=$(check_exiftool && echo true || echo false)
pdfcpu_exists=$(check_pdfcpu && echo true || echo false)
ytdlp_exists=$(check_ytdlp && echo true || echo false)

# Only proceed with Homebrew installation if any tool is missing
if ! $ffmpeg_exists || ! $imagemagick_exists || ! $exiftool_exists || ! $pdfcpu_exists || ! $ytdlp_exists; then
  # Check if Homebrew needs to be installed
  if [ -z "$BREW_BIN" ] || ! "$BREW_BIN" --version &>/dev/null; then
    echo -e "\nNote: Homebrew is not installed. Installing Homebrew since one or more required tools are missing...\n"
    
    # Ask for password and check if it was provided successfully
    if ! ask_for_password; then
        echo -e "\nSkipping Homebrew installation since authentication failed.\n"
        echo -e "Error: An error occurred during one or more installations."
        exit 1
    fi

    # Install Homebrew with error checking (NONINTERACTIVE skips the RETURN prompt)
    if ! NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; then
        echo "Error: Failed to install Homebrew"
        echo -e "Error: An error occurred during one or more installations."
        exit 1
    fi
    
    # Add Homebrew to PATH based on shell and architecture
    if [[ "$ARCH" == "x86_64" ]]; then
        if [[ "$CURRENT_SHELL" == "zsh" ]]; then
            echo 'eval "$(/usr/local/bin/brew shellenv)"' >> ~/.zprofile
        else
            echo 'eval "$(/usr/local/bin/brew shellenv)"' >> ~/.bash_profile
        fi
    else
        if [[ "$CURRENT_SHELL" == "zsh" ]]; then
            echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
        else
            echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.bash_profile
        fi
    fi
    
    # Source the updated profile
    source ~/.bash_profile 2>/dev/null || true
    source ~/.zprofile 2>/dev/null || true
    load_brew_env

    echo -e "\nHomebrew installation completed.\n"
  else
    echo -e "\nHomebrew installation completed.\n"
  fi
else
  echo -e "\nAll required tools are already installed.\n"
fi

# Install missing tools with error checking
if ! $ffmpeg_exists; then
  echo -e "Note: ffmpeg-full is not installed. Installing ffmpeg-full...\n"
  brew_install ffmpeg-full
  echo -e "\nffmpeg installation completed.\n"
else
  echo -e "ffmpeg installation completed.\n"
fi

if ! $imagemagick_exists; then
  echo -e "Note: ImageMagick is not installed. Installing ImageMagick...\n"
  brew_install imagemagick
  echo -e "\nImageMagick installation completed.\n"
else
  echo -e "ImageMagick installation completed.\n"
fi

if ! $exiftool_exists; then
  echo -e "Note: ExifTool is not installed. Installing ExifTool...\n"
  brew_install exiftool
  echo -e "\nExifTool installation completed.\n"
else
  echo -e "ExifTool installation completed.\n"
fi

if ! $pdfcpu_exists; then
  echo -e "Note: pdfcpu is not installed. Installing pdfcpu...\n"
  brew_install pdfcpu
  echo -e "\npdfcpu installation completed.\n"
else
  echo -e "pdfcpu installation completed.\n"
fi

if ! $ytdlp_exists; then
  echo -e "Note: yt-dlp is not installed. Installing yt-dlp...\n"
  brew_install yt-dlp
  echo -e "\nyt-dlp installation completed.\n"
else
  echo -e "yt-dlp installation completed.\n"
fi

echo -e "\nAll required tools are installed.\n"

# Function to check if a command runs successfully
check_command() {
  local version_output
  version_output=$("$@" 2>/dev/null)
  if [ $? -eq 0 ]; then
    return 0
  else
    return 1
  fi
}

# Verify tools are working correctly by checking their versions
ffmpeg_working=false
imagemagick_working=false
exiftool_working=false
pdfcpu_working=false
ytdlp_working=false

FFMPEG_PATH=$(resolve_ffmpeg_path) || true
if [ -n "$FFMPEG_PATH" ] && ffmpeg_bin_works "$FFMPEG_PATH"; then
  ffmpeg_working=true
fi

if check_command magick -version; then
  imagemagick_working=true
fi

if check_command exiftool -ver; then
  exiftool_working=true
fi

if check_command pdfcpu version; then
  pdfcpu_working=true
fi

if check_command yt-dlp --version; then
  ytdlp_working=true
fi

# Only print paths if all tools are working correctly
if $ffmpeg_working && $imagemagick_working && $exiftool_working && $pdfcpu_working && $ytdlp_working; then
  # Get the paths of the tools
  IMAGEMAGICK_PATH=$(which magick)
  EXIFTOOL_PATH=$(which exiftool)
  PDFCPU_PATH=$(which pdfcpu)
  YTDLP_PATH=$(which yt-dlp)
  
  # Print the paths with some formatting
  echo -e "\nPaths for installed tools:"
  echo -e "---------------------------------"
  echo -e "FFmpeg path: $FFMPEG_PATH"
  echo -e "ImageMagick path: $IMAGEMAGICK_PATH"
  echo -e "ExifTool path: $EXIFTOOL_PATH"
  echo -e "pdfcpu path: $PDFCPU_PATH"
  echo -e "yt-dlp path: $YTDLP_PATH"
  echo -e "---------------------------------\n"
  
  echo -e "All checks and installations are completed successfully."
else
  if ! $ffmpeg_working; then
    echo -e "- FFmpeg is not working properly\n"
  fi
  if ! $imagemagick_working; then
    echo -e "- ImageMagick is not working properly\n"
  fi
  if ! $exiftool_working; then
    echo -e "- ExifTool is not working properly\n"
  fi
  if ! $pdfcpu_working; then
    echo -e "- pdfcpu is not working properly\n"
  fi
  if ! $ytdlp_working; then
    echo -e "- yt-dlp is not working properly\n"
  fi
  echo -e "Error: An error occurred during one or more installations."
fi
