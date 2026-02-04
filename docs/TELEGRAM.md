# Telegram Bot Setup

Control your WA Scheduler remotely via Telegram.

## Create Your Bot

1. Open Telegram and search for [@BotFather](https://t.me/BotFather)
2. Send `/newbot`
3. Follow the prompts to name your bot
4. Copy the **bot token** (looks like `123456789:ABCdefGHIjklMNOpqrSTUvwxYZ`)

## Configure in WA Scheduler

1. Open the web dashboard: http://localhost:3000
2. Go to **Settings**
3. Paste your bot token
4. Click **Test** to verify
5. Enable the toggle
6. Click **Save**

## Initialize the Bot

1. Open your new bot in Telegram
2. Send `/start`
3. The bot will save your Chat ID automatically

## Available Commands

| Command | Description |
|---------|-------------|
| `/start` | Initialize bot and save chat ID |
| `/help` | Show available commands |
| `/status` | Check WhatsApp connection status |
| `/contacts` | List all saved contacts |
| `/schedules` | List active message schedules |
| `/logs` | Show recent message history |
| `/send <name> <message>` | Send a WhatsApp message immediately |

## Examples

```
/send John Hey, don't forget our meeting tomorrow!
/send Mom Happy birthday! 🎂
```

The contact name can be a partial match (case-insensitive).

## Notifications

When enabled, the bot will notify you about:
- ✅ Successfully sent messages
- ❌ Failed message deliveries
- ⚠️ WhatsApp disconnection events
- 🔄 Service restart events

## Security Notes

- Keep your bot token private
- Only you should have access to your bot
- The Chat ID ensures messages only go to you
- Consider using a private bot (don't share the link)

## Troubleshooting

### Bot not responding
1. Check if Telegram is enabled in Settings
2. Verify the bot token is correct
3. Make sure you sent `/start` to the bot
4. Check if the backend service is running

### Commands not working
1. Ensure WhatsApp is connected
2. Check the backend logs for errors
3. Try restarting the backend service
