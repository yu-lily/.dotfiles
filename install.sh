#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$HOME/.dotfiles"
DOTFILES_REPO="https://github.com/yu-lily/.dotfiles.git"

# --- Symlink helper ---
# Walks a package directory and creates symlinks in the target,
# replicating GNU stow behavior without requiring stow.
link_package() {
    local src_dir="$1"
    local target_dir="$2"

    for item in "$src_dir"* "$src_dir".*; do
        local base
        base="$(basename "$item")"
        case "$base" in
            .|..) continue ;;
        esac
        [ -e "$item" ] || continue

        local target="$target_dir/$base"

        if [ -d "$item" ]; then
            mkdir -p "$target"
            link_package "$item/" "$target"
        else
            if [ -L "$target" ]; then
                rm "$target"
            elif [ -e "$target" ]; then
                echo "  Backing up $target -> ${target}.bak"
                mv "$target" "${target}.bak"
            fi
            ln -s "$item" "$target"
            echo "  Linked $target -> $item"
        fi
    done
}

# --- 1. Clone or update repo ---
if [ ! -d "$DOTFILES_DIR/.git" ]; then
    echo "Cloning dotfiles..."
    git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
else
    echo "Dotfiles repo already exists, pulling latest..."
    git -C "$DOTFILES_DIR" pull
fi

# --- 2. Install uv ---
echo "Installing uv..."
curl -LsSf https://astral.sh/uv/install.sh | sh

# --- 3. Install Claude Code ---
echo "Installing Claude Code..."
curl -fsSL https://claude.ai/install.sh | sh

# --- 4. Symlink config packages ---
echo "Linking config files..."
for package_dir in "$DOTFILES_DIR"/*/; do
    package_name="$(basename "$package_dir")"
    echo "  Package: $package_name"
    link_package "$package_dir" "$HOME"
done

# --- 5. Append shell aliases ---
ALIAS_LINE="alias python=python3"

for rc_file in "$HOME/.bashrc" "$HOME/.zshrc"; do
    if [ -f "$rc_file" ]; then
        if ! grep -qF "$ALIAS_LINE" "$rc_file"; then
            echo "$ALIAS_LINE" >> "$rc_file"
            echo "  Appended alias to $rc_file"
        else
            echo "  Alias already in $rc_file, skipping"
        fi
    else
        echo "$ALIAS_LINE" > "$rc_file"
        echo "  Created $rc_file with alias"
    fi
done

echo "Done! Restart your shell to apply changes."
