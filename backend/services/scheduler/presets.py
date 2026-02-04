"""Schedule presets for Telegram and frontend"""

TELEGRAM_SCHEDULE_PRESETS = {
    "1": {"label": "Daily", "cron": "0 {H} * * *", "desc": "Every day"},
    "2": {"label": "Weekdays", "cron": "0 {H} * * 1-5", "desc": "Mon-Fri"},
    "3": {"label": "Weekly Monday", "cron": "0 {H} * * 1", "desc": "Every Monday"},
    "4": {"label": "Weekly Friday", "cron": "0 {H} * * 5", "desc": "Every Friday"},
    "5": {"label": "Monthly", "cron": "0 {H} 1 * *", "desc": "1st of month"},
    "6": {"label": "Once (in 1 hour)", "cron": None, "desc": "One-time"},
}
