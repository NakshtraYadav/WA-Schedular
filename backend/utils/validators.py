"""Input validators"""


def validate_phone(phone: str) -> str:
    """Validate and clean phone number"""
    cleaned = phone.strip()
    if not cleaned:
        raise ValueError('Phone number is required')
    if cleaned[0] == '+':
        digits = cleaned[1:]
    else:
        digits = cleaned
    if not digits.replace(' ', '').replace('-', '').isdigit():
        raise ValueError('Phone number must contain only digits')
    return cleaned
