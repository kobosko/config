#[[ -f ~/.Xmodmap ]] && xmodmap ~/.Xmodmap
exec xrdb -load ~/.Xresources&
exec spice-vdagent&
exec ~/bin/autorefresh.sh&
exec i3


