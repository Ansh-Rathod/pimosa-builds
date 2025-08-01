#!/bin/bash
echo "v1"
# Set the HOME environment variable (if needed)
export HOME="$HOME"

# Source environment configuration files (suppress output)
if [ -f ~/.bash_profile ]; then source ~/.bash_profile &>/dev/null; fi
if [ -f ~/.bashrc ]; then source ~/.bashrc &>/dev/null; fi
if [ -f ~/.profile ]; then source ~/.profile &>/dev/null; fi
if [ -f ~/.zshrc ]; then source ~/.zshrc &>/dev/null; fi
if [ -f ~/.zprofile ]; then source ~/.zprofile &>/dev/null; fi
if [ -f ~/.zlogin ]; then source ~/.zlogin &>/dev/null; fi

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

exiftool_exists=$(check_exiftool && echo true || echo false)
pdfcpu_exists=$(check_pdfcpu && echo true || echo false)

if ! $exiftool_exists; then
  echo -e "Note: ExifTool is not installed. Installing ExifTool...\n"
  brew install exiftool
  echo -e "\nExifTool installation completed.\n"
else
  echo -e "ExifTool installation completed.\n"
fi

if ! $pdfcpu_exists; then
  echo -e "Note: pdfcpu is not installed. Installing pdfcpu...\n"
  brew install pdfcpu
  echo -e "\npdfcpu installation completed.\n"
else
  echo -e "pdfcpu installation completed.\n"
fi

check_command() {
  local version_output
  version_output=$("$@" 2>/dev/null)
  if [ $? -eq 0 ]; then
    return 0
  else
    return 1
  fi
}

exiftool_working=false
pdfcpu_working=false

if check_command exiftool -ver; then
  exiftool_working=true
fi

if check_command pdfcpu version; then
  pdfcpu_working=true
fi

if $exiftool_working && $pdfcpu_working; then
  # Get the paths of the tools
  EXIFTOOL_PATH=$(which exiftool)
  PDFCPU_PATH=$(which pdfcpu)

  echo -e "\nPaths for installed tools:"
  echo -e "---------------------------------"
  echo -e "ExifTool path: $EXIFTOOL_PATH"
  echo -e "pdfcpu path: $PDFCPU_PATH"
  echo -e "---------------------------------\n"

  echo -e "All checks and installations are completed successfully."
else
  if ! $exiftool_working; then
    echo -e "- ExifTool is not working properly\n"
  fi
  if ! $pdfcpu_working; then
    echo -e "- pdfcpu is not working properly\n"
  fi
  echo -e "Error: An error occurred during one or more installations."
fi
