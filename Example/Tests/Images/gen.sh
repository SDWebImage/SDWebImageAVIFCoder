#!/usr/bin/env bash
set -e

ORIGS="white.png black.png gray.png blue.png red.png green.png e47a8c.png"
if [ -z "$CAVIF" ]; then
  CAVIF="cavif"
fi

echo "CAVIF=${CAVIF}"

function generate() {
  local orig=$1
  local base=${orig%.png}
  convert ${orig} -resize 256x256! "${base}.256x256.png"
  convert ${orig} -resize 256x255! "${base}.256x255.png"
  convert ${orig} -resize 255x256! "${base}.255x256.png"
  convert ${orig} -resize 255x255! "${base}.255x255.png"

  local flag
  for bpc in 8 10 12; do
    for fmt in yuv420 yuv422 yuv444; do
      for range in full limited; do
        for color in color mono; do
          for size in 256x256 256x255 255x256 255x255; do
            flag="--crf 10 --pix-fmt ${fmt} --bit-depth ${bpc}"
            if [[ ($bpc == 8 || $bpc == 10) && $fmt == "yuv420" ]]; then
              flag="${flag} --profile 0"
            elif [[ ($bpc == 8 || $bpc == 10) && $color == "color" && $fmt == "yuv444" ]]; then
              flag="${flag} --profile 1"
            elif [[ ($bpc == 8 || $bpc == 10) && $fmt == "yuv422" ]]; then
              flag="${flag} --profile 2"
            elif [[ ($bpc == 12) ]]; then
              flag="${flag} --profile 2"
            else
              continue
            fi
            if [[ $range == "full" ]]; then
              flag="${flag} --enable-full-color-range"
            else
              flag="${flag} --disable-full-color-range"
            fi
            if [[ $color == "color" ]]; then
              flag="${flag}"
            else
              flag="${flag} --monochrome"
            fi
            ${CAVIF} -i "${base}.${size}.png" -o "${base}.${size}.${bpc}bpc.${fmt}.${color}.${range}.avif" ${flag}
            echo "${base}.${size}.png	${base}.${size}.${bpc}bpc.${fmt}.${color}.${range}.avif" >> image-list.tsv
          done
        done
      done
    done
  done
}

rm -f image-list.tsv
for orig in ${ORIGS}; do
  generate ${orig}
done
