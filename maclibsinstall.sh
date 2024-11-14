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

# Function to check if a command exists
command_exists() {
  command -v "$1" &>/dev/null
}

# First check if both ffmpeg and ImageMagick are installed
ffmpeg_exists=$(command_exists ffmpeg)
imagemagick_exists=$(command_exists magick)

# Only proceed with Homebrew installation if either tool is missing
if ! $ffmpeg_exists || ! $imagemagick_exists; then
  # Check if Homebrew needs to be installed
  if ! command_exists brew; then
    echo -e "\nNote: Homebrew is not installed. Installing Homebrew since one or more required tools are missing...\n"
    yes '' | /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

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

  # Install missing tools
  if ! $ffmpeg_exists; then
    echo -e "Note: ffmpeg is not installed. Installing ffmpeg...\n"
    brew install ffmpeg
    echo -e "\nffmpeg installation completed.\n"
  else
    echo -e "ffmpeg is already installed.\n"
  fi

  if ! $imagemagick_exists; then
    echo -e "Note: ImageMagick is not installed. Installing ImageMagick...\n"
    brew install imagemagick
    echo -e "\nImageMagick installation completed.\n"
  else
    echo -e "ImageMagick is already installed.\n"
  fi
else
  echo -e "\nBoth ffmpeg and ImageMagick are already installed.\n"
fi

# Function to check if a command runs successfully
check_command() {
  if "$@" &>/dev/null; then
    return 0
  else
    return 1
  fi
}

# Verify both tools are working correctly by checking their versions
ffmpeg_working=false
imagemagick_working=false

if check_command ffmpeg -version; then
  ffmpeg_working=true
fi

if check_command magick -version; then
  imagemagick_working=true
fi

# Only print paths if both tools are working correctly
if $ffmpeg_working && $imagemagick_working; then
  # Get the paths of ffmpeg and ImageMagick
  FFMPEG_PATH=$(which ffmpeg)
  IMAGEMAGICK_PATH=$(which magick)

  # Print the paths with some formatting
  echo -e "\nPaths for installed tools:"
  echo -e "---------------------------------"
  echo -e "FFmpeg path: $FFMPEG_PATH"
  echo -e "ImageMagick path: $IMAGEMAGICK_PATH"
  echo -e "---------------------------------\n"

  echo -e "All checks and installations are completed successfully."
else
  if ! $ffmpeg_working; then
    echo "- FFmpeg is not working properly\n"
  fi
  if ! $imagemagick_working; then
    echo "- ImageMagick is not working properly\n"
  fi
  echo -e "Error: An error occurred during one or more installations."
fi