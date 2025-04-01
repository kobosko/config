
# Stealthy VM 

![fkhsjdf](/img/screenshot.png)
It Looks like a terminal on your Mac but scales to a fully working i3 desktop.

Since I develop for Linux systems, I need a reliable Linux VM on my Mac. I also want it to support GUI apps, since I want to be able to use it as my primary development platform, not just a text based terminal.
However, Since I already have a great graphical environment on my Mac, with a highly optimized web browser and Visual Studio code running, I want to be able to use all of that together with my guest VM without introducing
yet another graphical desktop running inside of my regular desktop. I dont want to have to move files back and forth between the Host and VM. They should optimally just be there, in my home directory like on the Mac.
What if we could seamlessly integrate a fully functioning i3 desktop into my Mac workflow that by default just behaves like the built-in Terminal.app but
that can run X11 applications such as a full web browser? Optimally, it should just boot up really quick and look like I just started a terminal right on my Mac. 

This is how I solved it:

## Configuration of Debian Machine
### Sudo
To enable the default user to run `sudo` in Debian, you need to add the user to the `sudo` group. Here's how you can do it:

1. Boot up your machine and log in as your `your_username`

1. Run the following command to add the user to the `sudo` group and configure sudo to execute without the need for a password:
    ```bash
    su -
    apt update
    apt install -y sudo
    /sbin/usermod -aG sudo your_username
    echo "your_username ALL=(ALL) NOPASSWD:ALL" | tee -a /etc/sudoers
    exit
    ```
    Replace `your_username` with the actual username of the user.
1. Enter the `root` password when prompted.
1. Once the command completes successfully, the user will have the necessary privileges to run `sudo` commands without entering a password.

## Autologin to Console
To automatically log in to your user account during boot, you can configure the agetty service. Here's how you can do it:

1. Edit the agetty service configuration file using a text editor:
    ```bash
    sudo vi /etc/systemd/system/getty.target.wants/getty@tty1.service
    ```
2. Add an empty ExecStart= and an ExecStart that autologins `your_username` lines to the file:
    ```plaintext
    [Service]
    ExecStart=
    ExecStart=-/sbin/agetty --autologin your_username --noclear - $TERM
    ```
    Replace `your_username` with the actual username of the user.
3. Save the file and exit the text editor.
4. Reload the systemd daemon to apply the changes:
    ```bash
    sudo systemctl daemon-reload
    ```
5. Reboot your Debian machine.
6. Your user account will now be automatically logged in during boot.

# Guest $HOME in the VM
## Installing host filesystem drivers (virtio-fs)
In Linux, the Virtio drivers play a crucial role in enhancing the performance of virtual machines by providing efficient communication between the guest operating system and the underlying hypervisor. To install Virtio drivers in Debian, we need to ensure that the necessary modules are included in the initial ramdisk (initramfs) to enable proper device recognition during the boot process.

### Editing the Initramfs Modules File
The `modules` file located at `/etc/initramfs-tools/modules` contains a list of modules that are included in the initramfs. To add Virtio drivers, follow these steps:

1. Open the `modules` file using your preferred text editor. In this example, we'll use `vi`:

    ```bash
    sudo vi /etc/initramfs-tools/modules
    ```

2. Add the Virtio modules to the file. Include the following lines if they are not already present:

    ```bash
    # List of modules that you want to include in your initramfs.
    # They will be loaded at boot time in the order below.
    #
    # Syntax:  module_name [args ...]
    #
    # You must run update-initramfs(8) to effect this change.
    #
    # Examples:
    #
    # raid1
    # sd_mod
    virtio_pci
    virtio_blk
    virtio_net
    ```
## Mounting on boot
1. Edit the `/etc/fstab` file using a text editor such as `vi` or `vim`:
    ```bash
    sudo vi /etc/fstab
    ```
1. Add the following line to the end of the file:
    ```plaintext
    share /home virtiofs rw,nofail, 0   0
    ```

1. Save the file and exit the text editor.
1. Mount the host VM home directory to the guest home directory by running the following command:
    ```bash
    sudo mount -a
    ```
Now, the host VM home directory will be mounted to the guest home directory using Virtiofs. You can access and modify the files in the host VM home directory from within the guest VM.

## Test: Reboot to mount $HOME
1. Now reboot your machine. 
   ```bash 
   sudo reboot
   ```
1. Now, whenever editing any files under the user $HOME directory, just open them on the Host machine instead of on the Guest. All the paths relative the user $HOME should now be
the same as the ones relative to your host $HOME directory. In this way, you can use copy-paste to not have to punch
every line in manually. This is important, since we won't have native copy-paste support before almost the end of this document.

# Graphical Desktop
## Installing Neccessary packages
1. Install the X11 server, xterm, and i3 window manager by running the following command:
    ```bash
    sudo apt install -y xorg xterm i3
    ```
1. Make sure that no display manager is installed. By default, Debian installs the `lightdm` display manager with `Xorg`:
    ```bash
    sudo apt remove -y lightdm
    ```
1. Once the installation is complete, you can start using X11 and i3 window manager on your Debian machine.

## Enabling Copy-Paste Between Host and VM (X11)
1. Install the Spice package by running the following command:
    ```bash
    sudo apt install -y spice-vdagent
    ```
1. Once your X11 session is up and running, you will now have copy+paste support between your terminal and the host machine.

## Always one Xterm running
No matter what, we want at least one instance of `xterm` running in full screen mode. This is what makes our VM window look like a terminal on your host thanks to the borderless settings for I3. To implement this behaviour, we are going to use a systemd user service called `xterm.service` which will be explicitly started by i3 wm:

1. If it does not exist yet, create the directory `~/.config/systemd/user` 
1. Edit the file `.config/systemd/user/xterm.service` and make sure it contains:
   ```ini
   [Unit]
   Description=xterm Service
   
   [Service]
   Type=simple
   Restart=always
   RestartMode=direct
   RestartSec=0
   Environment=DISPLAY=:0
   ExecStart=xterm
   StartLimitInterval=0 
   
   [Install]
   WantedBy=default.target
   ```
 1. Reload the user configuration
    ```bash
    systemctl --user daemon-reload
    ```

## Window Manager configuration
The i3 window manager is highly customizable. You can adjust the appearance and behavior of windows by editing the i3 configuration file. Here is a minimal configuration I created that supports window tiling and two separate workspaces (1 and 2) but not much else. It is also stripped of any status bar or other typically default visual elements of a standard i3 setup such as window borders.

1. Create or replace any pre-existing config for i3 at `~/.config/i3/config` using the following minimal configuration:
1. Paste the following
    ```plaintext
    set $mod Mod4
    font pango:noto mono 20
    exec --no-startup-id dex --autostart --environment i3
    set $refresh_i3status killall -SIGUSR1 i3status
    bindsym XF86AudioRaiseVolume exec --no-startup-id pactl set-sink-volume @DEFAULT_SINK@ +10% && $refresh_i3status
    bindsym XF86AudioLowerVolume exec --no-startup-id pactl set-sink-volume @DEFAULT_SINK@ -10% && $refresh_i3status
    bindsym XF86AudioMute exec --no-startup-id pactl set-sink-mute @DEFAULT_SINK@ toggle && $refresh_i3status
    bindsym XF86AudioMicMute exec --no-startup-id pactl set-source-mute @DEFAULT_SOURCE@ toggle && $refresh_i3status

    floating_modifier $mod
    tiling_drag modifier titlebar
    bindsym $mod+Return exec xterm
    bindsym $mod+Shift+q kill
    bindcode $mod+40 exec "rofi -modi drun,run -show drun"
    bindsym $mod+j focus left
    bindsym $mod+k focus down
    bindsym $mod+l focus up
    bindsym $mod+semicolon focus right
    bindsym $mod+Left focus left
    bindsym $mod+Down focus down
    bindsym $mod+Up focus up
    bindsym $mod+Right focus right
    bindsym $mod+Shift+j move left
    bindsym $mod+Shift+k move down
    bindsym $mod+Shift+l move up
    bindsym $mod+Shift+semicolon move right
    bindsym $mod+Shift+Left move left
    bindsym $mod+Shift+Down move down
    bindsym $mod+Shift+Up move up
    bindsym $mod+Shift+Right move right
    bindsym $mod+h split h
    bindsym $mod+Shift+h split v
    set $ws1 "1"
    set $ws2 "2"
    
    bindsym $mod+1 workspace number $ws1
    bindsym $mod+2 workspace number $ws2
    
    bindsym $mod+Shift+1 move container to workspace number $ws1
    bindsym $mod+Shift+2 move container to workspace number $ws2
    
    bindsym $mod+Shift+c reload
    bindsym $mod+Shift+r restart
    
    mode "resize" {
            bindsym j resize shrink width 10 px or 10 ppt
            bindsym k resize grow height 10 px or 10 ppt
            bindsym l resize shrink height 10 px or 10 ppt
            bindsym semicolon resize grow width 10 px or 10 ppt
    
            bindsym Left resize shrink width 10 px or 10 ppt
            bindsym Down resize grow height 10 px or 10 ppt
            bindsym Up resize shrink height 10 px or 10 ppt
            bindsym Right resize grow width 10 px or 10 ppt
    
            bindsym Return mode "default"
            bindsym Escape mode "default"
            bindsym $mod+r mode "default"
    }
    
    bindsym $mod+r mode "resize"
    gaps inner 5
    gaps outer -5
    smart_gaps on
    default_border pixel 0
    ```
    1. As the last line in that file, add the starting of the `xterm` user service, so that we always have at least one xterm instance running:
    ```bash
    exec systemctl --user start xterm
    ```
1. Save and close the file.
1. To make the changes take effect, you need to restart i3. You can do this by pressing `Mod+Shift+R`.

### Start X11 on boot
1. Create a new systemd unit file. For example:

    ```bash
    sudo vi /etc/systemd/system/startx.service
    ```
1. In the text editor, add the following content to the `startx.service` file:

    ```ini
    [Unit]
    Description=Stealth Mode VM Xorg
    After=graphical.target systemd-user-sessions.service
    
    [Service]
    User=<YOUR_USERNAME>
    WorkingDirectory=/home/<YOUR_USERNAME>
    PAMName=login
    Environment=XDG_SESSION_TYPE=x11
    TTYPath=/dev/tty8
    StandardInput=tty
    UnsetEnvironment=TERM
    UtmpIdentifier=tty8
    UtmpMode=user
    StandardOutput=journal
    ExecStartPre=/usr/bin/chvt 8
    ExecStart=/usr/bin/startx -- vt8 -keeptty -verbose 3 -logfile /dev/null 
    Restart=always
    
    [Install]
    WantedBy=graphical.target

    ```
    Replace `<YOUR_USERNAME>` with the actual username for which you want xterm to start. This will start X11 using the `startx` script on VTY 8 replacing the usual login mechanism

1. Reload the systemd manager configuration to recognize the new unit file:

    ```bash
    sudo systemctl daemon-reload
    ```

1. Set the `graphical.target` as the default target for systemd on boot:
    ```bash
    sudo systemctl set-default graphical.target
    ```


## Autoresize of Host window
### Creating the ~/bin Folder
First, create the `~/bin` folder. Here, we will have all our local executable scripts. Follow these steps:
1. Run the following command to create the `~/bin` folder:
    ```bash
    mkdir ~/bin
    ```
1. Add the folder to your $PATH
    ```bash
    echo "export PATH=/home/your_username/bin:$PATH" | tee -a ~/.bashrc
    ```
    and replace `your_username` with the correct username

### Creating the refresh.sh Script
The `~/bin/refresh.sh` script is used to adjust the screen resolution when the VM window is resized. It should be placed in the `~/bin` directory. Here are the steps to create this script:
1. Make sure that the contents of the file is:
    ```bash
    #!/bin/bash
    xrandr --output Virtual-1 --auto
    ```
1. Save and close the file.
1. Make the script executable by running the following command:
    ```bash
    chmod +x ~/bin/refresh.sh
    ```

### Resizing the VM window automatically
1. Add this content to the script `~/bin/autorefresh.sh`:
    ```bash
    #!/bin/bash
    while true; do
        LC_ALL=C xev -root -event randr |
        while read -r line; do
            if [[ $line == "RRScreenChangeNotify event"* ]]; then
                exec ~/bin/refresh.sh
            fi
        done
    done
    ```
1. Save the file as `autorefresh.sh` in the `~/bin` folder.
1. Make the script executable by running the following command:
    ```bash
    chmod +x ~/bin/autorefresh.sh
    ```
## Copy-Paste Keyboard Shortcuts
To add keyboard shortcuts for copy and paste operations in X11 applications, you can configure the `.Xresources` file. This guide will show you how to set Command+C for copy and Command+V for paste.

1. Edit the `.Xresources` file. If the file does not exist, this command will create it. Add the following lines to the file to set the copy and paste shortcuts:
    ```bash
    *metaSendsEscape: true
    *selectToClipboard: true
    *VT100.Translations: #override \
       Super <Key>c: copy-selection(CLIPBOARD) \n\
       Super <Key>v: insert-selection(CLIPBOARD)

    *VT100.selectToClipboard: true
    *trimSelection: true
    *cutNewLine: false
    *cutToBeginningOfLine: false

    ```
1. Save and close the file.
1. To make the changes take effect, you need to merge the `.Xresources` file with your current resources. Run the following command:
    ```bash
    xrdb -merge ~/.Xresources
    ```
1. The changes should now be in effect.

Note: These changes will only take effect in X11 applications that use the standard X11 copy and paste mechanism. Some applications, like certain terminal emulators or text editors, may use their own copy-paste mechanism and may not respect these settings.

## X11 Startup configuration
The `.xinitrc` file is a shell script read by `xinit` and `startx`. Use it to start the i3 window manager, the `spice-vdagent` and the `autorefresh.sh` script that we created earlier:
1. Edit the `.xinitrc` file. This file is located in your home directory:
    ```bash
    exec xrdb -load ~/.Xresources &
    exec spice-vdagent &
    exec ~/bin/autorefresh.sh &
    exec i3
    ```
1. Save and close the file.

## Test: Reboot the VM 
Now, you should reboot the VM to test whether it starts up correctly, into a single `xterm` instance running on Xorg.
```bash
sudo reboot
```
Once this works, you can now rely on copy-paste for the rest of the document.

# Styling X11
## Font Rendering
You can customize the appearance of X applications by setting various X resources. Here are some settings that you can use to adjust the font rendering and cursor size:

1. Add these lines to the top of .Xresources to provide for a proper font rendering for modern hidpi displays. Make sure to set the dpi value below to match your current monitor.
    ```bash
    Xft.dpi: 140
    Xft.antialias: true
    Xft.hinting: true
    Xft.rgba: none
    Xft.autohint: true
    Xft.hintstyle: hintslight
    Xft.lcdfilter: lcddefault
    ```
## Mouse Cursor
The default mouse cursor is ugly and small. Let's make it a bit bigger and nicer to match the Host VM better.
1. Install the Bibata cursor theme package using the `apt` command:
    ```bash
    sudo apt install bibata-cursor-theme
    ```
1. Add the Bibata mouse cursor theme that we installed earlier to your `~/.Xresources` file:   
    ```bash
    Xcursor.size: 32
    Xcursor.theme: Bibata
    ```
## Colors
1. Add a color theme to hipsterize your terminal. The default colors make it look awful. Choose a nice theme and export into your clipboard. I choose the default theme from http://www.terminal.sexy.   
    ```bash
    ! special
    *.foreground:   #c5c8c6
    *.background:   #1d1f21
    *.cursorColor:  #c5c8c6
    
    ! black
    *.color0:       #282a2e
    *.color8:       #373b41
    
    ! red
    *.color1:       #a54242
    *.color9:       #cc6666
    
    ! green
    *.color2:       #8c9440
    *.color10:      #b5bd68
    
    ! yellow
    *.color3:       #de935f
    *.color11:      #f0c674
    
    ! blue
    *.color4:       #5f819d
    *.color12:      #81a2be
    
    ! magenta
    *.color5:       #85678f
    *.color13:      #b294bb
    
    ! cyan
    *.color6:       #5e8d87
    *.color14:      #8abeb7
    
    ! white
    *.color7:       #707880
    *.color15:      #c5c8c6

    ```
1. Save and close the file.
1. To make the changes take effect, you need to merge the `.Xresources` file with your current resources. Run the following command:
    ```bash
    xrdb -merge ~/.Xresources
    ```
1. The changes should now be in effect.

## Font
### Downloading and Installing Overpass Mono Font
Overpass Mono is a monospace font that is suitable for terminal applications and coding. Here are the steps to download and install it:
1. Download the Overpass Mono font from its GitHub repository from the release page at `https://github.com/RedHatBrand/Overpass/releases`
1. The unzipped folder contains the Overpass Mono font files. On my machine, It ended up in `~/Downloads/Overpass-3.0.5/desktop-fonts/overpass-mono`
    ```bash
    mkdir -p ~/.local/share/fonts
    cd ~/Downloads/Overpass-3.0.5/desktop-fonts/overpass-mono
    mv overpass-mono* ~/.local/share/fonts
    ```
1. Update the font cache to make the new font available:
    ```bash
    fc-cache -fv
    ```
1. The Overpass Mono font should now be installed and available for use.

### Add font settings to .Xresources
1. Edit the `.Xresources` file. Add the following lines to the file to set your custom Xterm settings:
    ```bash
    xterm.vt100.faceName: xft:Overpass Mono
    xterm*faceSize: 14
    ```
1. Save and close the file.
1. To make the changes take effect, you need to merge the `.Xresources` file with your current resources. Run the following command:
    ```bash
    xrdb -merge ~/.Xresources
    ```
