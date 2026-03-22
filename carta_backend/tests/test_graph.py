"""Tests for the LangGraph pipeline components."""

from app.graph.state import ParsedIntent, EventResult, PlaceResult, ItineraryOutput, ItineraryStop


def test_parsed_intent_defaults():
    """ParsedIntent should accept minimal valid data."""
    intent = ParsedIntent(
        parsed_date="2026-03-28",
        parsed_time_of_day="evening",
        parsed_budget=1500,
    )
    assert intent.parsed_constraints == []
    assert intent.parsed_budget == 1500


def test_event_result_serialization():
    """EventResult should serialize cleanly."""
    event = EventResult(
        id="ev1",
        name="Jazz Night at Savera",
        type="music",
        venue="Savera Hotel",
        address="RK Salai, Chennai",
        lat=13.05,
        lng=80.25,
        start_time="8:00 PM",
        price=500,
        booking_url="https://example.com/book",
    )
    data = event.model_dump()
    assert data["source"] == "predicthq"
    assert data["name"] == "Jazz Night at Savera"


def test_place_result_optional_fields():
    """PlaceResult should handle optional rating/price_level."""
    place = PlaceResult(
        name="Madras Fuel Station",
        place_type="fuel",
        address="Anna Salai",
        lat=13.06,
        lng=80.26,
        source="overpass",
    )
    assert place.rating is None
    assert place.price_level is None


def test_itinerary_output_structure():
    """ItineraryOutput should assemble correctly."""
    itinerary = ItineraryOutput(
        title="Biryani and Jazz Evening",
        date="2026-03-28",
        total_cost_estimate=1400,
        summary="A flavorful dinner followed by live jazz.",
        stops=[
            ItineraryStop(
                time="7:00 PM",
                stop_type="meal",
                name="Buhari Hotel",
                address="Anna Salai",
                lat=13.06,
                lng=80.26,
                cost_estimate=600,
                duration_mins=90,
            ),
            ItineraryStop(
                time="9:00 PM",
                stop_type="event",
                name="Jazz Night",
                address="Savera Hotel",
                lat=13.05,
                lng=80.25,
                cost_estimate=500,
                duration_mins=120,
            ),
        ],
    )
    assert len(itinerary.stops) == 2
    assert itinerary.stops[0].stop_type == "meal"
    assert itinerary.total_cost_estimate == 1400
