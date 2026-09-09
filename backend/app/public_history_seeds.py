"""Deliberately empty public-history seed module.

LifeHub Open ships no imported biographies, social-media timelines, sources, or
claims about real people.  Users can add their own character lore and public
history through the application after checking they have the required rights.
"""

from sqlalchemy.orm import Session


COMPANION_PUBLIC_HISTORY_SUMMARY = ""


def seed_public_history(_: Session) -> None:
    """No-op by design: public content must be supplied by deployment owners."""
