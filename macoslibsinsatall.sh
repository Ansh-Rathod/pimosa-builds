#!/bin/bash

# Set the HOME environment variable (if needed)
export HOME="\$HOME"

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
ARCH=\$(uname -m)

# Set the default Homebrew installation path based on the architecture
if [[ "\$ARCH" == "x86_64" ]]; then
  # Intel Macs
  HOMEBREW_PREFIX="/usr/local"
else
  # Apple Silicon Macs
  HOMEBREW_PREFIX="/opt/homebrew"
fi

# Check if Homebrew is installed
if ! command -v brew &>/dev/null; then
  echo "Homebrew is not installed. Installing Homebrew..."

  # Run the Homebrew installation script and automatically press Enter
  yes '' | /bin/bash -c "\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  # Add Homebrew to PATH
  if [[ "\$ARCH" == "x86_64" ]]; then
    echo 'eval "\$(/usr/local/bin/brew shellenv)"' >> ~/.bash_profile
  else
    echo 'eval "\$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
  fi

  # Source the updated profile
  source ~/.bash_profile || source ~/.zprofile
else
  echo "Homebrew is already installed."
fi

# Check if ffmpeg is installed
if ! ffmpeg -version &>/dev/null; then
  echo "ffmpeg is not installed. Installing ffmpeg..."
  brew install ffmpeg
else
  echo "ffmpeg is already installed."
fi

# Check if ImageMagick is installed
if ! magick -version &>/dev/null; then
  echo "ImageMagick is not installed. Installing ImageMagick..."
  brew install imagemagick
else
  echo "ImageMagick is already installed."
fi

echo "All checks and installations are completed."
