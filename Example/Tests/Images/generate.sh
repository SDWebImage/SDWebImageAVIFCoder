#!/usr/bin/env bash
set -e

ORIGS="white.png black.png gray.png blue.png red.png green.png e47a8c.png"
MASK="mask.png"
if [ -z "$CAVIF" ]; then
  CAVIF="cavif"
fi

echo "CAVIF=${CAVIF}"

function calc-profile-flag() {
  local bpc=$1
  local fmt=$2
  local color=$3

  if [[ ($bpc == 8 || $bpc == 10) && $fmt == "yuv420" ]]; then
    echo -n "--profile 0"
  elif [[ ($bpc == 8 || $bpc == 10) && $color == "color" && $fmt == "yuv444" ]]; then
    echo -n "--profile 1"
  elif [[ ($bpc == 8 || $bpc == 10) && $fmt == "yuv422" ]]; then
    echo -n "--profile 2"
  elif [[ ($bpc == 12) ]]; then
    echo -n "--profile 2"
  fi
}

function generate-masks() {
  local orig=$1
  local base=${orig%.png}
  convert original/${orig} -resize 256x256! "${base}.256x256.png"
  convert original/${orig} -resize 256x255! "${base}.256x255.png"
  convert original/${orig} -resize 255x256! "${base}.255x256.png"
  convert original/${orig} -resize 255x255! "${base}.255x255.png"

  local flag
  local profileFlag
  local fmt="yuv420"

  for bpc in 8 10 12; do
    for range in full limited; do
      for size in 256x256 256x255 255x256 255x255; do
        profileFlag=$(calc-profile-flag $bpc $fmt $color)
        if [[ ${profileFlag} == "" ]]; then
          echo "[Assertion Error] Cannot calculate profile: $bpc $fmt $color"
          exit -1
        fi
        flag="--lossless --pix-fmt ${fmt} --bit-depth ${bpc} --monochrome ${profileFlag}"
        if [[ $range == "full" ]]; then
          flag="${flag} --enable-full-color-range"
        else
          flag="${flag} --disable-full-color-range"
        fi
        ${CAVIF} -i "${base}.${size}.png" -o "${base}.${size}.${bpc}bpc.${range}.avif" ${flag}
      done
    done
  done
}

function generate() {
  local orig=$1
  local base=${orig%.png}
  convert original/${orig} -resize 256x256! "${base}.256x256.png"
  convert original/${orig} -resize 256x255! "${base}.256x255.png"
  convert original/${orig} -resize 255x256! "${base}.255x256.png"
  convert original/${orig} -resize 255x255! "${base}.255x255.png"

  local flag
  local profileFlag
  # TODO(ledyba-z): Add more loops for:
  # - with thumbnail / without thumbnail
  # - matrix coefficients, color primaries, transfer characteristics
  for bpc in 8 10 12; do
    for fmt in yuv420 yuv422 yuv444; do
      for range in full limited; do
        for color in color mono; do
          for size in 256x256 256x255 255x256 255x255; do
            for alpha in with-alpha without-alpha; do
              flag="--crf 10 --pix-fmt ${fmt} --bit-depth ${bpc}"
              profileFlag=$(calc-profile-flag $bpc $fmt $color)
              if [[ ${profileFlag} == "" ]]; then
                continue
              else
                flag="${flag} ${profileFlag}"
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
              if [[ $alpha == "with-alpha" ]]; then
                #TODO(ledyba-z): Try alpha images with different range/bpc/size!
                # See: https://github.com/AOMediaCodec/av1-avif/issues/68
                flag="${flag} --attach-alpha mask.${size}.${bpc}bpc.${range}.avif"
              fi
              local outFilename="${base}.${size}.${bpc}bpc.${fmt}.${color}.${range}.${alpha}.avif"
              ${CAVIF} -i "${base}.${size}.png" -o ${outFilename} ${flag}
              echo "${base}.${size}.png" "${outFilename}" >> image-list.tsv
            done
          done
        done
      done
    done
  done
}

rm -f image-list.tsv

generate-masks ${MASK}
for orig in ${ORIGS}; do
  generate ${orig}
done
