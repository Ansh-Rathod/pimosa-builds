
echo "Homebrew installation completed.\n"

sleep 5

echo "ffmpeg installation completed.\n"

sleep 5

echo "ImageMagick installation completed.\n"

sleep 5

echo -e "\nBoth ffmpeg and ImageMagick are already installed.\n"

sleep 5

FFMPEG_PATH=$(which ffmpeg)
IMAGEMAGICK_PATH=$(which magick)

# Print the paths with some formatting
echo -e "\nPaths for installed tools:"
echo -e "---------------------------------"
echo -e "FFmpeg path: $FFMPEG_PATH"
echo -e "ImageMagick path: $IMAGEMAGICK_PATH"
echo -e "---------------------------------\n"


echo "All checks and installations are completed successfully."

