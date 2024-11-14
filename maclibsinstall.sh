#!/bin/bash

# Set the HOME environment variable (if needed)
export HOME="$HOME"

# Source environment configuration files
if [ -f ~/.bash_profile ]; then
  source ~/.bash_profile
fi

if [ -f ~/.bashrc ]; then
  source ~/.bashrc
fi

if [ -f ~/.profile ]; then
  source ~/.profile
fi

if [ -f ~/.zshrc ]; then
  source ~/.zshrc
fi

if [ -f ~/.zprofile ]; then
  source ~/.zprofile
fi

if [ -f ~/.zlogin ]; then
  source ~/.zlogin
fi

# Determine the architecture
ARCH=$(uname -m)

# Set the default Homebrew installation path based on the architecture
if [[ "$ARCH" == "x86_64" ]]; then
  # Intel Macs
  HOMEBREW_PREFIX="/usr/local"
else
  # Apple Silicon Macs
  HOMEBREW_PREFIX="/opt/homebrew"
fi

# Variable to track if all installations were successful
all_installed=true

# Check if Homebrew is installed
if ! command -v brew &>/dev/null; then
  echo -e "\nNote: Homebrew is not installed. Installing Homebrew...\n"

  # Run the Homebrew installation script and automatically press Enter
  yes '' | /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || all_installed=false

  # Add Homebrew to PATH
  if [[ "$ARCH" == "x86_64" ]]; then
    echo 'eval "$(/usr/local/bin/brew shellenv)"' >> ~/.bash_profile
  else
    echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
  fi

  # Source the updated profile
  source ~/.bash_profile || source ~/.zprofile
  echo -e "\nHomebrew installation completed.\n"
else
  echo -e "\nHomebrew is already installed.\n"
fi

# Check if ffmpeg is installed
if ! ffmpeg -version &>/dev/null; then
  echo -e "Note: ffmpeg is not installed. Installing ffmpeg...\n"
  brew install ffmpeg || all_installed=false
  echo -e "\nffmpeg installation completed.\n"
else
  echo -e "ffmpeg is already installed.\n"
fi

# Check if ImageMagick is installed
if ! magick -version &>/dev/null; then
  echo -e "Note: ImageMagick is not installed. Installing ImageMagick...\n"
  brew install imagemagick || all_installed=false
  echo -e "\nImageMagick installation completed.\n"
else
  echo -e "ImageMagick is already installed.\n"
fi

# Only print paths if all installations were successful
if $all_installed; then
  # Get the paths of ffmpeg and ImageMagick
  FFMPEG_PATH=$(which ffmpeg)
  IMAGEMAGICK_PATH=$(which magick)

  # Print the paths with some formatting
  echo -e "\nPaths for installed libraries:"
  echo -e "---------------------------------"
  echo -e "FFmpeg path: $FFMPEG_PATH"
  echo -e "ImageMagick path: $IMAGEMAGICK_PATH"
  echo -e "---------------------------------\n"

  echo -e "All checks and installations are completed.\n"
else
  echo -e "\nError: An error occurred during one or more installations.\n"
fi
