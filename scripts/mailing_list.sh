#!/usr/bin/env bash

report=$(cat) # cat reads from stdin when no filename is provided. let's us use piping | 
                #It doesn't matter whether that input comes from a pipe, redirection, or another source.

if [ -z "$report" ]; then
    echo "ERROR: No report received!" >&2
    exit 1
fi

SEND_DISCORD=1
SEND_EMAIL=0




# Discord reporting system
# Discord reporting system
if (( SEND_DISCORD )); then

    # Load the existing webhook configuration, locally inside the if statement
    source /etc/monitor.env
    # Assume formatting in .env is: DISCORD_WEBHOOK_URL="https://discord.com/api/webhooks/..."
    echo "Sending report to Discord..."

    # Send report as a text file attachment, the report is to large to be sent as a message. so we turn it into a txt file
    if printf '%s\n' "$report" | curl -fsS --max-time 30 \
        -o /dev/null \
        -F 'payload_json={"content":"Server Health Report","allowed_mentions":{"parse":[]}}' \
        -F 'files[0]=@-;filename=server_health.txt;type=text/plain' \
        "$DISCORD_WEBHOOK_URL"; then # The @- above ^ tells curl to read the file contents from stdin. Which is our report.

        echo "$(date -Is) Discord: Report sent successfully!"
    else
        echo "$(date -Is) ERROR: Discord notification failed!" >&2
    fi

else
    echo "Not sending report to Discord."
fi


if (( SEND_EMAIL )); then
    #Source email recipients from:
    source /etc/mailing_list.env
    #EMAIL_RECIPIENTS=(
    #    "person1@example.com"
    #    "person2@example.com"
    #    "person3@example.com"
    #)

    # Send the same report to each email recipient
    echo "Sending report to email recipients!"
    for email in "${EMAIL_RECIPIENTS[@]}"; do
        printf '%s\n' "$report" | mail -s "Server Health Report" "$email" #MUST HAVE msmtp INSTALLED!!!
    done
else
    echo "Not sending report to email list."
fi