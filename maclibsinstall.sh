#!/bin/bash

# Set the HOME environment variable (if needed)
export HOME="$HOME"

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

# Variable to track if all installations were successful
all_installed=true

# Check if ffmpeg is installed
ffmpeg_installed=true
if ! command -v ffmpeg &>/dev/null; then
  ffmpeg_installed=false
  all_installed=false
fi

# Check if ImageMagick is installed
imagemagick_installed=true
if ! command -v magick &>/dev/null; then
  imagemagick_installed=false
  all_installed=false
fi

# Only install Homebrew if ffmpeg or ImageMagick need to be installed
if ! $ffmpeg_installed || ! $imagemagick_installed; then
  if ! command -v brew &>/dev/null; then
    echo -e "\nNote: Homebrew is not installed. Installing Homebrew...\n"
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
fi

# Install ffmpeg if not already installed
if ! $ffmpeg_installed; then
  echo -e "Note: ffmpeg is not installed. Installing ffmpeg...\n"
  if ! brew install ffmpeg; then
    all_installed=false
  else
    ffmpeg_installed=true
    echo -e "\nffmpeg installation completed.\n"
  fi
else
  echo -e "ffmpeg is already installed.\n"
fi

# Install ImageMagick if not already installed
if ! $imagemagick_installed; then
  echo -e "Note: ImageMagick is not installed. Installing ImageMagick...\n"
  if ! brew install imagemagick; then
    all_installed=false
  else
    imagemagick_installed=true
    echo -e "\nImageMagick installation completed.\n"
  fi
else
  echo -e "ImageMagick is already installed.\n"
fi

# Only print paths if all installations were successful
if $all_installed && $ffmpeg_installed && $imagemagick_installed; then
  # Get the paths of ffmpeg and ImageMagick
  FFMPEG_PATH=$(which ffmpeg)
  IMAGEMAGICK_PATH=$(which magick)

  # Print the paths with some formatting
  echo -e "\nPaths for installed tools:"
  echo -e "---------------------------------"
  echo -e "FFmpeg path: $FFMPEG_PATH"
  echo -e "ImageMagick path: $IMAGEMAGICK_PATH"
  echo -e "---------------------------------\n"

  echo -e "All checks and installations are completed."
else
  echo -e "\nError: An error occurred during one or more installations."
fi