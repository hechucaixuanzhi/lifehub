"""Deliberately empty moment seed module.

The open-source distribution never fetches, mirrors, or ships third-party
social-media posts or images.  Moments are created locally by the user.
"""

from sqlalchemy.orm import Session


def seed_public_moments(_: Session) -> None:
    """No-op by design."""
