# What is swap memory?

swap memory is basically converting part of the storage into virtual memory in order to better mitigate the risks of memory leaks and/or running out of memory.

## How it works in our case:

assume that we have a 2GB RAM server with 32GB storage. The script below will take 2GB from the 32GB storage and create 2GB virtual memory effectively giving us:

2GB actual RAM + 2 GB virtual RAM = 4GB

## The manual way to set it up:

first check if it exists:

`free -h`

could show:

```
               total        used        free
Mem:           1.9Gi       650Mi       900Mi
Swap:             0B          0B          0B
```

Then using:

`swapon --show`

This should display nothing if no swap files are made. If no such file exists, we then create one using:

`sudo fallocate -l 2G /swapfile`

`sudo chmod 600 /swapfile`

Then we start it using:

`sudo mkswap /swapfile`

and verify that it exist using:

`ls -lh /swapfile`

expecting something like:

`-rw------- 1 root root 2.0G Nov 11 22:10 /swapfile`

`swapon --show`


```
NAME      TYPE  SIZE USED PRIO
/swapfile file    2G   0B   -2
```

# ###  Making swap persistent across reboots:

First check:

grep -nE '^[[:space:]]*/swapfile[[:space:]]' /etc/fstab

if no existing entry is already there, then we can use:

`echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab`

# ==========================================

# Configure Swap Memory

# ==========================================

setup_swap() {
    local SWAP_SIZE="2G"
    local SWAP_FILE="/swapfile"

    echo "Checking swap memory..."

    # Skip if swap is already active
    if [[-n "$(swapon --noheadings --show)"]]; then
        echo "Swap is already active. Skipping setup."
        return 0
    fi

    # Create swapfile if it doesn't already exist
    if [[! -e "$SWAP_FILE"]]; then
        echo "Creating $SWAP_SIZE swapfile..."

        fallocate -l "$SWAP_SIZE" "$SWAP_FILE"
        chmod 600 "$SWAP_FILE"
        mkswap "$SWAP_FILE"
    fi

    # Ensure correct permissions and activate swap
    chmod 600 "$SWAP_FILE"
    swapon "$SWAP_FILE"

    # Make swap persistent across reboots
    if ! grep -qE "^[[:space:]]*${SWAP_FILE}[[:space:]]" /etc/fstab; then
        echo "$SWAP_FILE none swap sw 0 0" >> /etc/fstab
    fi

    echo "Swap successfully configured!"
    swapon --show
}

# Run the function

setup_swap
