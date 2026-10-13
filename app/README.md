# food_app

The customer app for the food-ordering marketplace (Flutter + Riverpod). It talks to the API in `../backend`.

How to run it and its tests: see [../README.md](../README.md).

Code layout: `lib/core/` holds what every feature shares (API client, errors, money formatting), and `lib/features/<feature>/` has `data/` (models, repository), `state/` (Riverpod providers) and `ui/` (screens).
