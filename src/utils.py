def format_item(name: str) -> str:
    return name.strip().lower().replace(" ", "-")


def get_version() -> str:
    return "1.0.0"
