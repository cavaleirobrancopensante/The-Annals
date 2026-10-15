#!/usr/bin/env python3
"""Builds the road map of Ireland: places, roads, rivers, heights, lakes and bogs.

Coordinates are real (latitude, longitude) and approximate to a few kilometres. The map
is normalised to the bounding box, so x runs 0..1 west to east and y runs 0..1 north to south.
Writes data/road/map.json, the pt_BR and es copies, and assets/art/map/geography.svg.

Run from the project root: python3 tools/map/make_map.py
"""
import heapq
import json
import math
import os

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

LON_W, LON_E = -10.60, -5.30
LAT_S, LAT_N = 51.30, 55.45
COS = math.cos(math.radians(53.4))
WT = (LON_E - LON_W) * COS
HT = LAT_N - LAT_S
ROAD_KM_PER_WEEK = 120.0
MOUNTAIN_M = 300.0

FACTIONS = {
    "tollmaster": {"name": "the Pale", "desc": "The English-held lands about Dublin. Its men hold the bridges and charge a toll on every road."},
    "glen_lords": {"name": "the Gaelic lords", "desc": "The Irish lordships of the hills, the glens and the western shores. They meet at their hills to divide the cattle."},
    "church": {"name": "the holy places", "desc": "The bishops, the abbeys and the shrines. They receive the house as a sister."},
    "fishers": {"name": "the port towns", "desc": "The harbour towns and fishing coasts, where the boats come and go with the tide."},
    "bog": {"name": "the bog folk", "desc": "The people of the midland bogs, who cut turf and keep to themselves."},
}

# id, name, kind, faction, lat, lon, [being]
PLACES = [
    # The house and the old places the cards already name (ids kept).
    ("inishkeel", "Inishkeel", "shrine", "church", 54.50, -8.42),
    ("three_wells", "Three Wells", "shrine", "church", 54.00, -7.37),
    ("lough_dearg", "Lough Dearg", "hermitage", "church", 54.61, -8.02),
    ("knockmore", "Knockmore", "hold", "glen_lords", 53.86, -9.31),
    ("slieve_bloom", "Slieve Bloom", "hold", "glen_lords", 53.00, -7.65, "chimera"),
    ("ballyhale", "Ballyhale", "town", "tollmaster", 52.59, -7.23),
    ("kilcullen", "Kilcullen", "town", "tollmaster", 53.09, -6.71),
    ("bog_of_allen", "the Bog of Allen", "ruin", "bog", 53.20, -7.00, "engine"),
    ("glen_of_imaal", "the Glen of Imaal", "village", "glen_lords", 53.00, -6.48),
    ("kilmore_quay", "Kilmore Quay", "coast", "fishers", 52.17, -6.58),
    ("clare_cliffs", "the Clare cliffs", "ruin", "fishers", 52.97, -9.43),
    # The Pale: Dublin and the country about it.
    ("dublin", "Dublin", "town", "tollmaster", 53.35, -6.26),
    ("drogheda", "Drogheda", "town", "tollmaster", 53.72, -6.35),
    ("navan", "Navan", "town", "tollmaster", 53.65, -6.68),
    ("trim", "Trim", "town", "tollmaster", 53.55, -6.79),
    ("mellifont", "Mellifont", "church", "church", 53.75, -6.46),
    ("monasterboice", "Monasterboice", "church", "church", 53.81, -6.42),
    ("slane", "Slane", "hold", "tollmaster", 53.71, -6.55),
    ("tara", "the Hill of Tara", "hold", "tollmaster", 53.58, -6.61),
    ("clonard", "Clonard", "church", "church", 53.46, -6.76),
    ("kells", "Kells", "church", "church", 53.72, -6.88),
    ("naas", "Naas", "town", "tollmaster", 53.22, -6.66),
    ("maynooth", "Maynooth", "town", "tollmaster", 53.38, -6.59),
    ("celbridge", "Celbridge", "village", "tollmaster", 53.34, -6.53),
    ("swords", "Swords", "village", "tollmaster", 53.46, -6.22),
    ("malahide", "Malahide", "coast", "tollmaster", 53.45, -6.15),
    ("balbriggan", "Balbriggan", "coast", "tollmaster", 53.61, -6.18),
    ("ardee", "Ardee", "village", "tollmaster", 53.87, -6.54),
    ("kildare", "Kildare", "church", "church", 53.16, -6.91),
    ("athy", "Athy", "town", "tollmaster", 52.99, -6.99),
    ("glendalough", "Glendalough", "hermitage", "church", 53.01, -6.32),
    ("bray", "Bray", "village", "tollmaster", 53.20, -6.10),
    ("dun_laoghaire", "Dun Laoghaire", "coast", "tollmaster", 53.29, -6.13),
    ("wicklow", "Wicklow", "coast", "tollmaster", 52.98, -6.04),
    ("arklow", "Arklow", "coast", "fishers", 52.80, -6.15),
    ("lugnaquilla", "Lugnaquilla", "hold", "glen_lords", 52.95, -6.46),
    ("edenderry", "Edenderry", "village", "bog", 53.35, -7.05),
    # The midlands and the bog.
    ("lough_boora", "Lough Boora", "village", "bog", 53.15, -7.67),
    ("tullamore", "Tullamore", "town", "bog", 53.27, -7.49),
    ("mullingar", "Mullingar", "town", "tollmaster", 53.52, -7.34),
    ("athlone", "Athlone", "town", "tollmaster", 53.42, -7.94),
    ("longford", "Longford", "town", "glen_lords", 53.73, -7.80),
    ("cavan", "Cavan", "town", "glen_lords", 53.99, -7.36),
    ("portlaoise", "Portlaoise", "town", "glen_lords", 53.03, -7.30),
    ("dunamase", "Dunamase", "ruin", "glen_lords", 53.00, -7.29),
    ("durrow", "Durrow", "church", "church", 53.15, -7.36),
    ("clonmacnoise", "Clonmacnoise", "church", "church", 53.33, -7.98),
    ("clonfert", "Clonfert", "church", "church", 53.25, -8.00),
    ("birr", "Birr", "town", "glen_lords", 53.09, -7.91),
    ("roscrea", "Roscrea", "town", "glen_lords", 52.95, -7.80),
    ("carlow", "Carlow", "town", "glen_lords", 52.84, -6.93),
    ("kilkenny", "Kilkenny", "town", "glen_lords", 52.65, -7.25),
    ("enniscorthy", "Enniscorthy", "town", "glen_lords", 52.50, -6.56),
    ("new_ross", "New Ross", "town", "fishers", 52.39, -6.94),
    ("wexford", "Wexford", "coast", "fishers", 52.33, -6.46),
    ("rosslare", "Rosslare", "coast", "fishers", 52.25, -6.38),
    ("waterford", "Waterford", "coast", "fishers", 52.26, -7.11),
    ("cashel", "Cashel", "shrine", "church", 52.52, -7.89),
    ("holycross", "Holy Cross", "shrine", "church", 52.61, -7.97),
    ("lismore", "Lismore", "church", "church", 52.14, -7.93),
    ("clonmel", "Clonmel", "town", "glen_lords", 52.35, -7.70),
    ("cahir", "Cahir", "village", "glen_lords", 52.37, -7.93),
    ("comeraghs", "the Comeraghs", "hold", "glen_lords", 52.31, -7.61),
    ("knockmealdown", "the Knockmealdowns", "hold", "glen_lords", 52.25, -7.95),
    ("dungarvan", "Dungarvan", "coast", "fishers", 52.09, -7.62),
    ("youghal", "Youghal", "coast", "fishers", 51.95, -7.85),
    ("tipperary", "Tipperary", "town", "glen_lords", 52.47, -8.16),
    ("nenagh", "Nenagh", "town", "glen_lords", 52.86, -8.20),
    ("killaloe", "Killaloe", "church", "church", 52.80, -8.45),
    ("portumna", "Portumna", "village", "glen_lords", 53.10, -8.22),
    ("galtymore", "Galtymore", "hold", "glen_lords", 52.35, -8.20),
    ("limerick", "Limerick", "town", "glen_lords", 52.66, -8.63),
    ("mallow", "Mallow", "village", "glen_lords", 52.13, -8.65),
    ("fermoy", "Fermoy", "town", "glen_lords", 52.14, -8.27),
    ("cork", "Cork", "town", "glen_lords", 51.90, -8.47),
    ("kinsale", "Kinsale", "coast", "fishers", 51.71, -8.52),
    ("ballycotton", "Ballycotton", "coast", "fishers", 51.83, -8.00),
    ("bantry", "Bantry", "coast", "fishers", 51.68, -9.45),
    ("skibbereen", "Skibbereen", "town", "glen_lords", 51.55, -9.26),
    ("mizen", "Mizen Head", "coast", "fishers", 51.44, -9.82),
    ("kenmare", "Kenmare", "town", "glen_lords", 51.88, -9.58),
    ("killarney", "Killarney", "village", "glen_lords", 52.06, -9.51),
    ("tralee", "Tralee", "town", "glen_lords", 52.27, -9.70),
    ("dingle", "Dingle", "coast", "fishers", 52.14, -10.27),
    ("valentia", "Valentia", "coast", "fishers", 51.93, -10.36),
    ("skellig", "Skellig Michael", "hermitage", "church", 51.77, -10.54),
    ("carrantuohil", "Carrantuohil", "hold", "glen_lords", 52.00, -9.74),
    ("kilrush", "Kilrush", "coast", "fishers", 52.64, -9.49),
    ("scattery", "Scattery Island", "church", "church", 52.63, -9.56),
    ("ennis", "Ennis", "town", "glen_lords", 52.84, -8.98),
    ("kilkee", "Kilkee", "coast", "fishers", 52.68, -9.65),
    ("aran", "Inishmore", "shrine", "church", 53.12, -9.72),
    ("galway", "Galway", "town", "fishers", 53.27, -9.05),
    ("tuam", "Tuam", "church", "church", 53.51, -8.85),
    ("clifden", "Clifden", "coast", "fishers", 53.49, -10.02),
    ("mweelrea", "Mweelrea", "hold", "glen_lords", 53.61, -9.75, "marred"),
    ("croagh_patrick", "Croagh Patrick", "shrine", "church", 53.76, -9.65),
    ("knock", "Knock", "shrine", "church", 53.80, -8.91),
    ("westport", "Westport", "town", "glen_lords", 53.80, -9.52),
    ("rathcroghan", "Rathcroghan", "ruin", "glen_lords", 53.78, -8.36),
    ("boyle", "Boyle", "church", "church", 53.97, -8.29),
    ("ballina", "Ballina", "town", "glen_lords", 54.12, -9.16),
    ("killala", "Killala", "church", "church", 54.21, -9.21),
    ("nephin", "Nephin", "hold", "glen_lords", 54.10, -9.35),
    ("sligo", "Sligo", "town", "glen_lords", 54.27, -8.47),
    ("benbulben", "Benbulben", "hold", "glen_lords", 54.30, -8.48),
    ("longford_west", "Ballymote", "village", "glen_lords", 54.09, -8.52),
    ("bundoran", "Bundoran", "coast", "fishers", 54.48, -8.28),
    ("ballyshannon", "Ballyshannon", "town", "glen_lords", 54.50, -8.18),
    ("donegal", "Donegal", "town", "glen_lords", 54.65, -8.11),
    ("slieve_league", "Slieve League", "hold", "glen_lords", 54.66, -8.62),
    ("errigal", "Errigal", "hold", "glen_lords", 55.03, -8.10),
    ("dunfanaghy", "Dunfanaghy", "coast", "fishers", 55.18, -7.97),
    ("letterkenny", "Letterkenny", "town", "glen_lords", 54.95, -7.73),
    ("malin_head", "Malin Head", "coast", "fishers", 55.38, -7.34),
    ("derry", "Derry", "town", "fishers", 55.00, -7.32),
    ("omagh", "Omagh", "town", "glen_lords", 54.60, -7.30),
    ("enniskillen", "Enniskillen", "town", "glen_lords", 54.34, -7.64),
    ("monaghan", "Monaghan", "town", "glen_lords", 54.25, -6.97),
    ("armagh", "Armagh", "church", "church", 54.35, -6.65),
    ("dundalk", "Dundalk", "town", "glen_lords", 54.00, -6.40),
    ("newry", "Newry", "town", "glen_lords", 54.18, -6.34),
    ("slieve_donard", "Slieve Donard", "hold", "glen_lords", 54.18, -5.92),
    ("downpatrick", "Downpatrick", "church", "church", 54.33, -5.72),
    ("newcastle", "Newcastle", "coast", "fishers", 54.22, -5.89),
    ("belfast", "Belfast", "town", "fishers", 54.60, -5.93),
    ("bangor", "Bangor", "church", "church", 54.66, -5.67),
    ("carrickfergus", "Carrickfergus", "coast", "fishers", 54.72, -5.80),
    ("antrim", "Antrim", "town", "glen_lords", 54.72, -6.21),
    ("lisburn", "Lisburn", "town", "glen_lords", 54.52, -6.04),
    ("toome", "Toome", "village", "bog", 54.68, -6.42),
    ("ballymena", "Ballymena", "town", "glen_lords", 54.86, -6.28),
    ("coleraine", "Coleraine", "coast", "fishers", 55.13, -6.67),
    ("sawel", "Sawel", "hold", "glen_lords", 54.80, -6.95),
    ("mourne_gap", "Mourne Gap", "village", "glen_lords", 54.14, -6.02),
    ("dunluce", "Dunluce", "ruin", "fishers", 55.20, -6.56),
]

HOUSE = ("the Burren", 53.08, -9.12)

# Lakes: name, centre lat, centre lon, radius lat, radius lon (degrees).
LAKES = [
    ("Lough Neagh", 54.60, -6.30, 0.15, 0.17), ("Lough Erne", 54.30, -7.65, 0.22, 0.10),
    ("Lough Ree", 53.55, -7.95, 0.14, 0.07), ("Lough Derg", 52.90, -8.35, 0.16, 0.08),
    ("Lough Corrib", 53.35, -9.22, 0.20, 0.07), ("Lough Mask", 53.61, -9.33, 0.10, 0.05),
    ("Lough Conn", 54.00, -9.25, 0.10, 0.06), ("Lough Allen", 54.17, -8.08, 0.05, 0.05),
    ("Lough Gill", 54.20, -8.40, 0.04, 0.05),
]

# Rivers as lists of (lat, lon). The mouth is the last point.
RIVERS = {
    "Shannon": [(54.23, -7.90), (53.95, -8.09), (53.42, -7.94), (53.10, -8.22), (52.66, -8.63), (52.61, -9.11), (52.58, -9.45)],
    "Barrow": [(53.13, -7.20), (53.14, -6.91), (52.84, -6.93), (52.55, -7.00), (52.39, -6.94), (52.20, -6.95)],
    "Nore": [(52.88, -7.52), (52.65, -7.25), (52.50, -7.00), (52.39, -6.94)],
    "Suir": [(52.70, -7.99), (52.52, -7.89), (52.35, -7.70), (52.35, -7.40), (52.26, -7.11)],
    "Blackwater": [(52.12, -8.65), (52.14, -8.27), (52.08, -7.92), (51.95, -7.85)],
    "Lee": [(51.90, -9.05), (51.90, -8.47), (51.82, -8.30)],
    "Liffey": [(53.18, -6.37), (53.34, -6.53), (53.35, -6.26)],
    "Boyne": [(53.22, -7.03), (53.65, -6.68), (53.72, -6.35)],
    "Slaney": [(52.82, -6.55), (52.50, -6.56), (52.33, -6.46)],
    "Erne": [(54.10, -7.45), (54.34, -7.64), (54.50, -8.18)],
    "Bann": [(54.68, -6.42), (55.13, -6.67)],
    "Moy": [(54.08, -9.25), (54.12, -9.16), (54.20, -9.25)],
    "Corrib": [(53.45, -9.20), (53.27, -9.05)],
    "Foyle": [(54.80, -7.53), (55.00, -7.32)],
    "Fergus": [(52.84, -8.98), (52.66, -9.13), (52.61, -9.11)],
}

# Heights: name, lat, lon, metres.
PEAKS = [
    ("Carrauntoohil", 52.00, -9.74, 1038), ("Lugnaquilla", 52.95, -6.46, 925), ("Galtymore", 52.35, -8.20, 918),
    ("Slieve Donard", 54.18, -5.92, 850), ("Comeraghs", 52.31, -7.61, 792), ("Mweelrea", 53.61, -9.75, 814),
    ("Nephin", 54.10, -9.35, 806), ("Errigal", 55.03, -8.10, 751), ("Croagh Patrick", 53.76, -9.65, 764),
    ("Knockmealdowns", 52.25, -7.95, 798), ("Sawel", 54.80, -6.95, 678), ("Slieve Bloom", 53.00, -7.65, 528),
    ("Benbulben", 54.30, -8.48, 526), ("Slieve League", 54.66, -8.62, 601), ("Blackstairs", 52.60, -6.80, 382),
    ("Slieve Gullion", 54.10, -6.45, 573), ("Maamturks", 53.50, -9.70, 700),
]

# Bogs: name, lat, lon, radius lat, radius lon.
BOGS = [
    ("Bog of Allen", 53.20, -7.00, 0.13, 0.20), ("Lough Boora bog", 53.15, -7.67, 0.08, 0.12),
    ("Bog of the Shannon", 53.25, -8.10, 0.12, 0.10), ("Mayo bogs", 53.90, -9.45, 0.12, 0.18),
]

# The coast of Ireland, clockwise from Malin Head.
COAST = [
    (55.38, -7.34), (55.15, -6.95), (55.19, -6.66), (55.24, -6.51), (55.20, -6.25), (55.22, -6.12),
    (54.97, -5.96), (54.85, -5.80), (54.66, -5.67), (54.40, -5.50), (54.22, -5.89), (54.04, -6.18),
    (53.98, -6.25), (53.85, -6.19), (53.72, -6.20), (53.40, -6.10), (53.29, -6.13), (52.98, -6.03),
    (52.80, -6.15), (52.33, -6.37), (52.17, -6.37), (52.15, -6.90), (52.08, -7.60), (51.95, -7.85),
    (51.83, -8.00), (51.60, -8.52), (51.55, -8.95), (51.44, -9.82), (51.59, -10.20), (51.80, -10.35),
    (51.93, -10.36), (52.09, -10.46), (52.27, -10.23), (52.30, -9.95), (52.56, -9.93), (52.68, -9.65),
    (52.88, -9.43), (53.10, -9.45), (53.27, -9.05), (53.40, -10.25), (53.49, -10.02), (53.60, -10.10),
    (53.95, -10.15), (54.22, -9.99), (54.22, -9.22), (54.27, -8.60), (54.48, -8.45), (54.66, -8.62),
    (55.09, -8.25), (55.18, -7.97), (55.38, -7.34),
]


def xy(lat, lon):
    return ((lon - LON_W) * COS / WT, (LAT_N - lat) / HT)


def haversine_km(a, b):
    r = 6371.0
    la1, lo1, la2, lo2 = map(math.radians, (a[0], a[1], b[0], b[1]))
    d = math.sin((la2 - la1) / 2) ** 2 + math.cos(la1) * math.cos(la2) * math.sin((lo2 - lo1) / 2) ** 2
    return 2 * r * math.asin(math.sqrt(d))


def segments_cross(p1, p2, q1, q2):
    def ccw(a, b, c):
        return (c[1] - a[1]) * (b[0] - a[0]) - (b[1] - a[1]) * (c[0] - a[0])
    d1 = ccw(q1, q2, p1)
    d2 = ccw(q1, q2, p2)
    d3 = ccw(p1, p2, q1)
    d4 = ccw(p1, p2, q2)
    return (d1 * d2 < 0) and (d3 * d4 < 0)


def crosses_coast(a, b):
    ring = COAST + [COAST[0]]
    for i in range(len(ring) - 1):
        if segments_cross(a, b, ring[i], ring[i + 1]):
            return True
    return False


def crosses_river(a, b):
    for pts in RIVERS.values():
        for i in range(len(pts) - 1):
            if segments_cross(a, b, pts[i], pts[i + 1]):
                return True
    return False


def height_at(lat, lon):
    best = 0.0
    for _, la, lo, h in PEAKS:
        d = math.hypot(la - lat, (lo - lon) * COS)
        best = max(best, h * math.exp(-(d / 0.22) ** 2))
    return best


def mountain_on(a, b):
    steps = 12
    for i in range(steps + 1):
        t = i / steps
        lat = a[0] + (b[0] - a[0]) * t
        lon = a[1] + (b[1] - a[1]) * t
        if height_at(lat, lon) > MOUNTAIN_M:
            return True
    return False


def build():
    nodes = [("house", HOUSE[0], HOUSE[1], HOUSE[2])] + [(p[0], p[1], p[4], p[5]) for p in PLACES]
    pos = {n[0]: (n[2], n[3]) for n in nodes}
    names = {p[0]: p for p in PLACES}
    ids = [n[0] for n in nodes]

    # Candidate roads: each place to its three nearest neighbours, never across the sea.
    edges = {}
    for a in ids:
        near = sorted((b for b in ids if b != a), key=lambda b: haversine_km(pos[a], pos[b]))
        added = 0
        for b in near:
            if added >= 3:
                break
            if crosses_coast(pos[a], pos[b]):
                continue
            key = tuple(sorted((a, b)))
            edges[key] = True
            added += 1
    # Join any island or island-like place to the mainland, even across water.
    parent = {i: i for i in ids}

    def find(i):
        while parent[i] != i:
            parent[i] = parent[parent[i]]
            i = parent[i]
        return i
    for a, b in edges:
        parent[find(a)] = find(b)
    while len({find(i) for i in ids}) > 1:
        best = None
        for a in ids:
            for b in ids:
                if find(a) != find(b):
                    d = haversine_km(pos[a], pos[b])
                    if best is None or d < best[0]:
                        best = (d, a, b)
        _, a, b = best
        edges[tuple(sorted((a, b)))] = True
        parent[find(a)] = find(b)

    # Weeks along each road: distance, plus a week for a river crossing and for a mountain pass.
    weights = {}
    road_list = []
    for a, b in sorted(edges):
        km = haversine_km(pos[a], pos[b])
        weeks = max(1, round(km / ROAD_KM_PER_WEEK))
        if crosses_river(pos[a], pos[b]):
            weeks += 1
        if mountain_on(pos[a], pos[b]):
            weeks += 1
        weights.setdefault(a, []).append((b, weeks))
        weights.setdefault(b, []).append((a, weeks))
        road_list.append([a, b, weeks])

    dist = {"house": 0}
    heap = [(0, "house")]
    while heap:
        d, u = heapq.heappop(heap)
        if d > dist.get(u, 1e9):
            continue
        for v, w in weights.get(u, []):
            nd = d + w
            if nd < dist.get(v, 1e9):
                dist[v] = nd
                heapq.heappush(heap, (nd, v))
    return nodes, names, road_list, dist


def node_entry(n, names, dist):
    pid = n[0]
    p = names[pid]
    faction = p[3]
    entry = {"id": pid, "name": p[1], "kind": p[2], "faction": faction,
             "distance": dist.get(pid, 1), "x": round(xy(p[4], p[5])[0], 4), "y": round(xy(p[4], p[5])[1], 4)}
    if len(p) > 6:
        entry["being"] = p[6]
    return entry


def write_json(path, data):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write("\n")


def map_data(lang_factions, house_name, names_by_id=None):
    nodes, names, roads, dist = build()
    out_nodes = [node_entry(n, names, dist) for n in nodes if n[0] != "house"]
    house_x, house_y = xy(HOUSE[1], HOUSE[2])
    return {
        "bounds": {"width": round(WT / HT, 4), "height": 1.0},
        "factions": {k: {"name": v[0], "desc": v[1]} for k, v in lang_factions.items()},
        "house": {"name": house_name, "x": round(house_x, 4), "y": round(house_y, 4)},
        "nodes": out_nodes,
        "roads": roads,
    }


def svg_path(points):
    coords = []
    for lat, lon in points:
        x, y = xy(lat, lon)
        coords.append("%.1f,%.1f" % (x * 1000, y * 1000))
    return " ".join(coords)


def write_svg(path):
    # Normalised coordinates: x and y both run 0 to 1 over the map. The game draws the square
    # into a rectangle WT/HT wide, which gives the true shape of the island.
    out = ['<svg xmlns="http://www.w3.org/2000/svg" width="1400" height="1400" viewBox="0 0 1000 1000">',
           '<rect width="1000" height="1000" fill="#1c2226"/>',
           '<polygon points="%s" fill="#3d3a2a" stroke="#6b5f3e" stroke-width="5"/>' % svg_path(COAST)]
    for name, la, lo, rla, rlo in BOGS:
        x, y = xy(la, lo)
        out.append('<ellipse cx="%.1f" cy="%.1f" rx="%.1f" ry="%.1f" fill="#5c4f30" fill-opacity="0.7"/>' % (x * 1000, y * 1000, rlo / WT * 1000, rla / HT * 1000))
    for name, la, lo, rla, rlo in LAKES:
        x, y = xy(la, lo)
        out.append('<ellipse cx="%.1f" cy="%.1f" rx="%.1f" ry="%.1f" fill="#2f5d70" stroke="#4f8196" stroke-width="3"/>' % (x * 1000, y * 1000, rlo / WT * 1000, rla / HT * 1000))
    for name, pts in RIVERS.items():
        out.append('<polyline points="%s" fill="none" stroke="#4f8196" stroke-width="%d" stroke-linejoin="round"/>' % (svg_path(pts), 5 if name in ("Shannon", "Barrow", "Erne", "Bann", "Boyne", "Foyle") else 3))
    for name, la, lo, h in PEAKS:
        x, y = xy(la, lo)
        r = 10 + h / 60.0
        out.append('<polygon points="%.1f,%.1f %.1f,%.1f %.1f,%.1f" fill="#6e5d42" stroke="#9a8760" stroke-width="2"/>' % (
            x * 1000 - r, y * 1000 + r * 0.7, x * 1000, y * 1000 - r, x * 1000 + r, y * 1000 + r * 0.7))
    out.append("</svg>")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(out) + "\n")


def main():
    en = map_data({k: (v["name"], v["desc"]) for k, v in FACTIONS.items()}, "the Burren")
    write_json(os.path.join(ROOT, "data/road/map.json"), en)
    pt_factions = {
        "tollmaster": ("o Pale", "As terras inglesas em volta de Dublin. Os seus homens guardam as pontes e cobram portagem em todas as estradas."),
        "glen_lords": ("os senhores gaélicos", "Os senhorios irlandeses das colinas, dos vales e das costas do oeste. Reúnem-se nas suas colinas para repartir o gado."),
        "church": ("os lugares santos", "Os bispos, as abadias e os santuários. Recebem a casa como irmã."),
        "fishers": ("as cidades portuárias", "As cidades de porto e as costas de pesca, onde os barcos entram e saem com a maré."),
        "bog": ("o povo do pântano", "O povo dos pântanos do centro, que corta turfa e se mantém à parte."),
    }
    es_factions = {
        "tollmaster": ("el Pale", "Las tierras inglesas alrededor de Dublín. Sus hombres guardan los puentes y cobran peaje en cada camino."),
        "glen_lords": ("los señores gaélicos", "Los señoríos irlandeses de las colinas, los valles y las costas del oeste. Se reúnen en sus montes para repartir el ganado."),
        "church": ("los lugares santos", "Los obispos, las abadías y los santuarios. Reciben a la casa como a una hermana."),
        "fishers": ("las ciudades portuarias", "Las ciudades de puerto y las costas de pesca, donde los barcos entran y salen con la marea."),
        "bog": ("el pueblo del pantano", "El pueblo de los pantanos del centro, que corta turba y se mantiene aparte."),
    }
    write_json(os.path.join(ROOT, "data/i18n/pt_BR/road/map.json"), map_data(pt_factions, "o Burren"))
    write_json(os.path.join(ROOT, "data/i18n/es/road/map.json"), map_data(es_factions, "el Burren"))
    write_svg(os.path.join(ROOT, "assets/art/map/geography.svg"))
    print("places %d, roads %d" % (len(en["nodes"]), len(en["roads"])))


if __name__ == "__main__":
    main()
