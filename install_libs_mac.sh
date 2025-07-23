#!/bin/bash
# This script is used by Pimosa starting from version 1.1.9 (build 19).
echo "v2"
# Set the HOME environment variable (if needed)
export HOME="$HOME"

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

# Function to check if ffmpeg is installed and working
check_ffmpeg() {
  local version_output
  version_output=$(ffmpeg -version 2>/dev/null)
  if [ $? -eq 0 ] && [[ "$version_output" == *"ffmpeg version"* ]]; then
    return 0
  fi
  return 1
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
  if [ $? -eq 0 ] && [[ "$version_output" == *"pdfcpu version"* ]]; then
    return 0
  fi
  return 1
}

# Check if tools are installed and working
ffmpeg_exists=$(check_ffmpeg && echo true || echo false)
imagemagick_exists=$(check_imagemagick && echo true || echo false)
exiftool_exists=$(check_exiftool && echo true || echo false)
pdfcpu_exists=$(check_pdfcpu && echo true || echo false)

# Only proceed with Homebrew installation if any tool is missing
if ! $ffmpeg_exists || ! $imagemagick_exists || ! $exiftool_exists || ! $pdfcpu_exists; then
  # Check if Homebrew needs to be installed
  if ! brew --version &>/dev/null; then
    echo -e "\nNote: Homebrew is not installed. Installing Homebrew since one or more required tools are missing...\n"
    
    # Ask for password and check if it was provided successfully
    if ! ask_for_password; then
        echo -e "\nSkipping Homebrew installation since authentication failed.\n"
        echo -e "Error: An error occurred during one or more installations."
        exit 1
    fi

    # Install Homebrew with error checking
    if ! yes '' | /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; then
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

    echo -e "\nHomebrew installation completed.\n"
  else
    echo -e "\nHomebrew installation completed.\n"
  fi
else
  echo -e "\nAll required tools are already installed.\n"
fi

# Install missing tools with error checking
if ! $ffmpeg_exists; then
  echo -e "Note: ffmpeg is not installed. Installing ffmpeg...\n"
  if ! brew install ffmpeg; then
    echo "Error: Failed to install ffmpeg"
    echo -e "Error: An error occurred during one or more installations."
    exit 1
  fi
  echo -e "\nffmpeg installation completed.\n"
else
  echo -e "ffmpeg installation completed.\n"
fi

if ! $imagemagick_exists; then
  echo -e "Note: ImageMagick is not installed. Installing ImageMagick...\n"
  if ! brew install imagemagick; then
    echo "Error: Failed to install ImageMagick"
    echo -e "Error: An error occurred during one or more installations."
    exit 1
  fi
  echo -e "\nImageMagick installation completed.\n"
else
  echo -e "ImageMagick installation completed.\n"
fi

if ! $exiftool_exists; then
  echo -e "Note: ExifTool is not installed. Installing ExifTool...\n"
  if ! brew install exiftool; then
    echo "Error: Failed to install ExifTool"
    echo -e "Error: An error occurred during one or more installations."
    exit 1
  fi
  echo -e "\nExifTool installation completed.\n"
else
  echo -e "ExifTool installation completed.\n"
fi

if ! $pdfcpu_exists; then
  echo -e "Note: pdfcpu is not installed. Installing pdfcpu...\n"
  if ! brew install pdfcpu; then
    echo "Error: Failed to install pdfcpu"
    echo -e "Error: An error occurred during one or more installations."
    exit 1
  fi
  echo -e "\npdfcpu installation completed.\n"
else
  echo -e "pdfcpu installation completed.\n"
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

if check_command ffmpeg -version; then
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

# Only print paths if all tools are working correctly
if $ffmpeg_working && $imagemagick_working && $exiftool_working && $pdfcpu_working; then
  # Get the paths of the tools
  FFMPEG_PATH=$(which ffmpeg)
  IMAGEMAGICK_PATH=$(which magick)
  EXIFTOOL_PATH=$(which exiftool)
  PDFCPU_PATH=$(which pdfcpu)
  
  # Print the paths with some formatting
  echo -e "\nPaths for installed tools:"
  echo -e "---------------------------------"
  echo -e "FFmpeg path: $FFMPEG_PATH"
  echo -e "ImageMagick path: $IMAGEMAGICK_PATH"
  echo -e "ExifTool path: $EXIFTOOL_PATH"
  echo -e "pdfcpu path: $PDFCPU_PATH"
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
  echo -e "Error: An error occurred during one or more installations."
fi
