#!/usr/bin/env python3
"""CPU geometry audit only; this does not prove GPU publication or progress."""
import json

def check(tokens):
    assert tokens > 0 and tokens % 16 == 0
    tiles = tokens // 16
    producers = {tile: set() for tile in range(tiles)}
    for group in range(tokens):
        tile, column = divmod(group, 16)
        producers[tile].update(range(column * 64, (column + 1) * 64))
    assert all(columns == set(range(1024)) for columns in producers.values())
    groups = (tiles + 4) // 5
    consumers = [0] * tiles
    dead = 0
    for part in range(3):
        for group in range(groups * 32):
            for wave in range(5):
                tile = (group // 32) * 5 + wave
                if tile < tiles:
                    assert tile in producers
                    consumers[tile] += 1
                else:
                    dead += 1
    assert consumers == [96] * tiles
    return dict(tokens=tokens, token_tiles=tiles, producer_groups=tokens,
                producer_groups_per_tile=16, consumer_groups=groups*32*3,
                live_consumer_waves_per_tile=96, dead_consumer_waves=dead)

print(json.dumps({"scope": "CPU geometry only", "cases": [check(n) for n in (624, 640, 656)]}, indent=2))
