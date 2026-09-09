# Optional local models

No machine-learning model binaries are distributed with LifeHub Open. The
original development model had no release-ready provenance record, so it is
excluded from this repository.

The face-identity experiment is optional and degrades safely when its model is
unavailable. If you enable it in a private deployment, obtain a model with a
compatible license, keep its source and license notice, and place it at the
path expected by the feature. Do not commit the binary or any face gallery.
