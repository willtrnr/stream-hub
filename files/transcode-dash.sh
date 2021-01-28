#! /usr/bin/env bash

name="$1"
output="${2:-/var/lib/nginx/tmp/dash}"

if [ -z "$name" ]; then
  exit 1
fi

ffmpeg_args=(
  -loglevel info
  -hwaccel auto
)

input_args=(
  -re
  -i "rtmp://localhost/live/$name"
)

video_args=(
  -c:v h264_nvenc
  -r:v 24000/1001
  -g:v 48
  -keyint_min:v 48
  -profile:v main
  -preset:v hq
  -rc:v vbr_hq
  -pix_fmt:v yuv420p
)

audio_args=(
  -c:a aac
  -r:a 48000
)

output_args=(
  -f dash
  -ldash 1
  -streaming 1
  -window_size 3
  -use_template 1
  -use_timeline 0
  -seg_duration 2
  -remove_at_exit 1
  -utc_timing_url "http://time.akamai.com/?iso"
)

transcode_args=(
  -threads 1
  "${video_args[@]}"
  "${audio_args[@]}"
  "${output_args[@]}"
)

mkdir -p "${output}/${name}_"{480p,720p,1080p}

function cleanup {
  pkill -TERM -P $$
  rm -rf "${output}/${name}_"{480p,720p,1080p}
}

trap 'cleanup' INT TERM EXIT

/usr/bin/ffmpeg "${ffmpeg_args[@]}" "${input_args[@]}" \
  -filter:v scale=-2:480  -b:v 800k  -b:a 128k "${transcode_args[@]}" "${output}/${name}_480p/index.mpd" \
  -filter:v scale=-2:720  -b:v 2400k -b:a 192k "${transcode_args[@]}" "${output}/${name}_720p/index.mpd" \
  -filter:v scale=-2:1080 -b:v 4800k -b:a 256k "${transcode_args[@]}" "${output}/${name}_1080p/index.mpd" \
  & wait
