#!/bin/bash
while true; do
    LC_ALL=C xev -root -event randr |
    while read -r line; do
        if [[ $line == "RRScreenChangeNotify event"* ]]; then
            exec ~/bin/refresh.sh
        fi
    done
done
