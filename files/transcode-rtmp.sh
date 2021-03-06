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
  -analyzeduration 1
  -fflags nobuffer
  -i "rtmp://localhost/live/$name"
)

video_args=(
  -c:v h264_nvenc
  -r:v 24000/1001
  -g:v 48
  -keyint_min:v 48
  -profile:v main
  -preset:v llhq
  -rc:v vbr_hq
  -bf:v 2
  -pix_fmt:v yuv420p
)

audio_args=(
  -c:a aac
  -r:a 48000
)

encode_args=(
  -threads 1
  "${video_args[@]}"
  "${audio_args[@]}"
)

output_args=(
  -ldash 1
  -streaming 1
  -write_prft 1
  -window_size 3
  -use_template 1
  -use_timeline 0
  -seg_duration 2
  -target_latency 2
  -index_correction 1
  -extra_window_size 5
  -adaptation_sets 'id=0,streams=v id=1,streams=a'
  -utc_timing_url 'https://time.akamai.com/?iso'
  -f dash "${output}/${name}/index.mpd"
)

mkdir -p "${output}/${name}"

function cleanup {
  pkill -TERM -P $$
  rm -rf "${output}/${name}"
}

trap 'cleanup' INT TERM EXIT

/usr/bin/ffmpeg \
  "${ffmpeg_args[@]}" \
  "${input_args[@]}" \
  "${encode_args[@]}" \
  -map '0:v:0' -map '0:a?:0' -map '0:v:0' -map '0:a?:0' -map '0:v:0' -map '0:a?:0' \
  -filter:v:0 scale=-2:480  -b:v:0 600k  -maxrate:v:0 700k  -bufsize:v:0 1050k -b:a:0 96k \
  -filter:v:1 scale=-2:720  -b:v:1 1200k -maxrate:v:1 1400k -bufsize:v:1 2100k -b:a:1 128k \
  -filter:v:2 scale=-2:1080 -b:v:2 3900k -maxrate:v:2 4200k -bufsize:v:2 6300k -b:a:2 256k \
  "${output_args[@]}" \
  & wait
