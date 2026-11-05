if status is-interactive
    # Starship custom prompt
    command -v starship &> /dev/null && starship init fish | source

    # Direnv + Zoxide
    command -v direnv &> /dev/null && direnv hook fish | source
    command -v zoxide &> /dev/null && zoxide init fish --cmd cd | source

    # Better ls
    command -v eza &> /dev/null && alias ls='eza --icons --group-directories-first -1'

    # Abbrs
    abbr lg 'lazygit'
    abbr gd 'git diff'
    abbr ga 'git add .'
    abbr gc 'git commit -am'
    abbr gl 'git log'
    abbr gs 'git status'
    abbr gst 'git stash'
    abbr gsp 'git stash pop'
    abbr gp 'git push'
    abbr gpl 'git pull'
    abbr gsw 'git switch'
    abbr gsm 'git switch main'
    abbr gb 'git branch'
    abbr gbd 'git branch -d'
    abbr gco 'git checkout'
    abbr gsh 'git show'

    abbr l 'ls'
    abbr ll 'ls -l'
    abbr la 'ls -a'
    abbr lla 'ls -la'

    # Claude and terminal shortcuts
    abbr c 'clear'
    abbr cc 'CLAUDE_CONFIG_DIR=~/.claude-b claude'
    abbr ccb 'claude'

    # Volume boost (1.0 = 100%)
    abbr upp 'wpctl set-volume @DEFAULT_AUDIO_SINK@ 1.3'
    abbr norm 'wpctl set-volume @DEFAULT_AUDIO_SINK@ 1.0'

    # Custom colours
    cat ~/.local/state/caelestia/sequences.txt 2> /dev/null

    # For jumping between prompts in foot terminal
    function mark_prompt_start --on-event fish_prompt
        echo -en "\e]133;A\e\\"
    end

    # Custom fish config
    set -q XDG_CONFIG_HOME && set -l cConf $XDG_CONFIG_HOME/caelestia || set -l cConf $HOME/.config/caelestia
    source $cConf/user-config.fish 2> /dev/null
end


# Added by Antigravity CLI installer
set -gx TZ "Africa/Addis_Ababa"
set -gx PATH "/home/yeab/.local/bin" $PATH
set -gx PATH "$HOME/.npm-global/bin" $PATH

# Android SDK + JDK 17 (for the Android emulator / Expo builds)
set -gx JAVA_HOME "$HOME/.local/share/jdk/jdk-17.0.20.1+1"
set -gx ANDROID_HOME "$HOME/Android/Sdk"
set -gx ANDROID_AVD_HOME "$HOME/.config/.android/avd"
fish_add_path -g $JAVA_HOME/bin $ANDROID_HOME/cmdline-tools/latest/bin $ANDROID_HOME/platform-tools $ANDROID_HOME/emulator

# Dotfiles repo (bare, work tree = $HOME). Use like git: dot status, dot add, dot commit, dot push
alias dot 'git --git-dir=$HOME/.dotfiles --work-tree=$HOME'
