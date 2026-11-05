#!/usr/bin/env bash
# Helper for the gshot Quickshell screenshot UI.
set -u

shots_dir="$(xdg-user-dir PICTURES 2>/dev/null || echo "$HOME/Pictures")/Screenshots"
casts_dir="$(xdg-user-dir VIDEOS 2>/dev/null || echo "$HOME/Videos")/Screencasts"

notify_open() { # file title body
    (
        act=$(notify-send -a "Screenshot" -i "$1" -A default=Open -A folder="Show in Files" "$2" "$3")
        case "$act" in
            default) xdg-open "$1" ;;
            folder) xdg-open "$(dirname "$1")" ;;
        esac
    ) >/dev/null 2>&1 &
    disown
}

case "${1:-}" in
    # grab DIR STAMP: freeze every monitor (with and without cursor), print monitor/client JSON
    grab)
        dir=$2 stamp=$3
        mkdir -p "$dir" && rm -f "$dir"/*.png
        monitors=$(hyprctl -j monitors)
        for name in $(jq -r '.[].name' <<<"$monitors"); do
            grim -o "$name" "$dir/$stamp-$name.png" &
            grim -c -o "$name" "$dir/$stamp-$name-c.png" &
        done
        wait
        jq -cn --argjson m "$monitors" --argjson c "$(hyprctl -j clients)" '{monitors: $m, clients: $c}'
        ;;
    # shot SRC X Y W H: crop (physical px), save, copy, notify
    shot)
        mkdir -p "$shots_dir"
        out="$shots_dir/Screenshot From $(date '+%Y-%m-%d %H-%M-%S').png"
        magick "$2" -crop "${5}x${6}+${3}+${4}" +repage "$out" || exit 1
        wl-copy --type image/png <"$out"
        notify_open "$out" "Screenshot captured" "You can paste the image from the clipboard."
        ;;
    castfile)
        mkdir -p "$casts_dir"
        echo "$casts_dir/Screencast From $(date '+%Y-%m-%d %H-%M-%S').mp4"
        ;;
    castdone)
        [ -s "$2" ] && notify_open "$2" "Screencast recorded" "The recording has been saved in $casts_dir"
        ;;
esac
