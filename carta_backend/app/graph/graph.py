"""LangGraph StateGraph — wires all 5 nodes together.

Flow:
    intent_parser → parallel(event_search, map_scraper) → planner → profile_updater
"""

from __future__ import annotations

from langgraph.graph import StateGraph, START, END

from app.graph.state import GraphState
from app.graph.nodes.intent_parser import intent_parser
from app.graph.nodes.event_search import event_search
from app.graph.nodes.map_scraper import map_scraper
from app.graph.nodes.planner import planner
from app.graph.nodes.profile_updater import profile_updater


def build_graph():
    """Construct and compile the Carta planning graph."""

    graph = StateGraph(GraphState)

    # --- Add nodes ---
    graph.add_node("intent_parser", intent_parser)
    graph.add_node("event_search", event_search)
    graph.add_node("map_scraper", map_scraper)
    graph.add_node("planner", planner)
    graph.add_node("profile_updater", profile_updater)

    # --- Define edges ---
    # 1. Start → intent_parser
    graph.add_edge(START, "intent_parser")

    # 2. intent_parser → fan-out to event_search AND map_scraper (parallel)
    graph.add_edge("intent_parser", "event_search")
    graph.add_edge("intent_parser", "map_scraper")

    # 3. Both parallel nodes → planner (fan-in)
    graph.add_edge("event_search", "planner")
    graph.add_edge("map_scraper", "planner")

    # 4. planner → profile_updater
    graph.add_edge("planner", "profile_updater")

    # 5. profile_updater → END
    graph.add_edge("profile_updater", END)

    return graph.compile()


# Module-level singleton so we don't rebuild on every request
carta_graph = build_graph()
