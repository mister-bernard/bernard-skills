# Flight Search + Hidden City Fare Finder

Russian-compatible flight search using Travelpayouts/Aviasales cached price API.
Works where western search engines (Google Flights, Skyscanner, Kayak) don't — especially for Russia-origin routes.

## Quick Start

```bash
# Direct search
python3 skills/flight-search/scripts/search.py MOW SZX 2026-03-06

# Hidden city fare finder (checks if booking BEYOND your destination is cheaper)
python3 skills/flight-search/scripts/search.py MOW SZX 2026-03-06 --hidden-city

# Flexible dates (+/- 3 days)
python3 skills/flight-search/scripts/search.py MOW SZX 2026-03-06 --flexible 3

# Cheapest in month
python3 skills/flight-search/scripts/search.py MOW SZX 2026-03 --month

# JSON output
python3 skills/flight-search/scripts/search.py MOW SZX 2026-03-06 --json
```

## How Hidden City Works

1. You want to fly A→B
2. Sometimes A→C (where C is beyond B) is cheaper, connecting through B
3. You book A→C, get off at B, skip the last leg
4. Rules: carry-on only, no checked bags (they go to C), one-way only (return gets cancelled)

## API Details

- **Provider:** Travelpayouts (Aviasales affiliate API)
- **Token:** Demo token (cached prices from last 48h, no auth needed)
- **Rate limit:** None documented for cached endpoint
- **Data:** Prices from Russian OTAs (City.Travel, etc.) — often 50-70% cheaper than western engines for Russia-origin flights
- **Limitation:** Cached prices, not real-time. May be slightly stale. Always verify on aviasales.com before booking.

## Supported Airports

Any IATA code works. Common Russian origins: MOW (Moscow all), SVO, DME, VKO, LED (St. Petersburg), KZN, SVX, OVB, KJA.

## Notes

- Western sanctions mean Google Flights / Skyscanner / Kayak have limited Russia inventory
- Aviasales (via Travelpayouts) is the primary Russian flight metasearch
- Trip.com also works for Russian bookings
- For real-time pricing, always confirm on aviasales.com — cached prices can expire
