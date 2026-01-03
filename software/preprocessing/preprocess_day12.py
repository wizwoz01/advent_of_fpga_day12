#!/usr/bin/env python3
"""
preprocess_day12.py

Preprocessing script for Advent of Code 2025 Day 12.
Reads AoC input (text) and writes a compact binary representation suitable for FPGA consumption.

Input format:
- Shapes defined with index: followed by grid of # and .
- Regions defined as WxH: followed by quantities for each shape

Output format (little-endian 32-bit words):
- Header: [num_shapes (16b), reserved (16b)]
- For each shape:
  - [width (8b), height (8b), num_cells (8b), reserved (8b)]
  - [cell positions as bitmask: x0(4b), y0(4b), x1(4b), y1(4b), ...]
- For each region:
  - [width (16b), height (16b)]
  - [quantities: q0(8b), q1(8b), q2(8b), q3(8b), q4(8b), q5(8b), reserved (16b)]

Usage:
  python3 preprocess_day12.py input.txt output.bin
"""

import sys
import struct
import re

def generate_rotations_and_flips(shape_grid):
    """Generate all 8 transformations (4 rotations × 2 flips) of a shape."""
    def rotate_90(grid):
        """Rotate grid 90 degrees clockwise."""
        if not grid:
            return []
        rows = len(grid)
        cols = len(grid[0])
        rotated = [['.' for _ in range(rows)] for _ in range(cols)]
        for r in range(rows):
            for c in range(cols):
                rotated[c][rows - 1 - r] = grid[r][c]
        return rotated
    
    def flip_horizontal(grid):
        """Flip grid horizontally."""
        return [row[::-1] for row in grid]
    
    def grid_to_cells(grid):
        """Convert grid to list of (x, y) cell positions."""
        cells = []
        for y, row in enumerate(grid):
            for x, cell in enumerate(row):
                if cell == '#':
                    cells.append((x, y))
        return cells
    
    def normalize_shape(cells):
        """Normalize shape by translating to origin."""
        if not cells:
            return []
        min_x = min(x for x, y in cells)
        min_y = min(y for x, y in cells)
        return [(x - min_x, y - min_y) for x, y in cells]
    
    # Generate all transformations
    transformations = set()
    current = shape_grid
    
    # 4 rotations
    for _ in range(4):
        cells = normalize_shape(grid_to_cells(current))
        if cells:
            # Store as tuple of tuples for hashing
            transformations.add(tuple(sorted(cells)))
        current = rotate_90(current)
    
    # Flip and rotate again
    current = flip_horizontal(shape_grid)
    for _ in range(4):
        cells = normalize_shape(grid_to_cells(current))
        if cells:
            transformations.add(tuple(sorted(cells)))
        current = rotate_90(current)
    
    # Return unique shapes (as list of lists)
    unique_shapes = []
    for shape_tuple in transformations:
        unique_shapes.append(list(shape_tuple))
    
    return unique_shapes

def parse_shapes(lines):
    """Parse shape definitions from input."""
    shapes = []
    i = 0
    while i < len(lines):
        line = lines[i].strip()
        # Check for shape header: "N:"
        match = re.match(r'^(\d+):$', line)
        if match:
            shape_idx = int(match.group(1))
            shape_grid = []
            i += 1
            # Read shape grid until empty line or next shape
            while i < len(lines) and lines[i].strip() and not re.match(r'^\d+:', lines[i].strip()):
                shape_grid.append(list(lines[i].strip()))
                i += 1
            
            if shape_grid:
                # Generate all rotations/flips and store unique ones
                unique_transforms = generate_rotations_and_flips(shape_grid)
                # Store the first (canonical) representation
                shapes.append({
                    'index': shape_idx,
                    'grid': shape_grid,
                    'transforms': unique_transforms
                })
        else:
            i += 1
    
    return shapes

def parse_regions(lines):
    """Parse region definitions from input."""
    regions = []
    for line in lines:
        line = line.strip()
        if not line:
            continue
        # Format: "WxH: q0 q1 q2 q3 q4 q5"
        match = re.match(r'^(\d+)x(\d+):\s*(.+)$', line)
        if match:
            width = int(match.group(1))
            height = int(match.group(2))
            quantities = [int(x) for x in match.group(3).split()]
            regions.append({
                'width': width,
                'height': height,
                'quantities': quantities
            })
    return regions

def main():
    if len(sys.argv) != 3:
        print("Usage: preprocess_day12.py input.txt output.bin")
        sys.exit(2)

    in_path = sys.argv[1]
    out_path = sys.argv[2]

    # Read input file
    with open(in_path, 'r') as f:
        lines = f.readlines()
    
    # Parse shapes and regions
    shapes = parse_shapes(lines)
    regions = parse_regions(lines)
    
    print(f"Parsed {len(shapes)} shapes and {len(regions)} regions")
    
    # Write binary output
    with open(out_path, 'wb') as out:
        # Header: num_shapes (16b), num_regions (16b)
        out.write(struct.pack('<HH', len(shapes), len(regions)))
        
        # Write shapes
        for shape in shapes:
            grid = shape['grid']
            height = len(grid)
            width = max(len(row) for row in grid) if grid else 0
            
            # Count cells
            num_cells = sum(row.count('#') for row in grid)
            
            # Write shape header: width, height, num_cells, reserved
            out.write(struct.pack('<BBBB', width, height, num_cells, 0))
            
            # Write cell positions (normalized to origin)
            cells = []
            for y, row in enumerate(grid):
                for x, cell in enumerate(row):
                    if cell == '#':
                        cells.append((x, y))
            
            # Normalize to origin
            if cells:
                min_x = min(x for x, y in cells)
                min_y = min(y for x, y in cells)
                normalized = [(x - min_x, y - min_y) for x, y in cells]
            else:
                normalized = []
            
            # Write cells (4 cells per 32-bit word)
            # Format per byte: x(4b), y(4b) - so 4 cells per word
            for i in range(0, len(normalized), 4):
                word = 0
                for j in range(4):
                    if i + j < len(normalized):
                        x, y = normalized[i + j]
                        # Pack as: byte = x(4b) | (y(4b) << 4)
                        word |= ((x & 0xF) | ((y & 0xF) << 4)) << (j * 8)
                out.write(struct.pack('<I', word))
        
        # Write regions
        for region in regions:
            # Write region header: width (16b), height (16b)
            out.write(struct.pack('<HH', region['width'], region['height']))
            
            # Write quantities (up to 6 shapes, pad to 8 bytes = 2 words)
            quantities = region['quantities']
            qty_bytes = [q & 0xFF for q in quantities[:6]]
            while len(qty_bytes) < 6:
                qty_bytes.append(0)
            # Pack as: q0, q1, q2, q3, q4, q5, reserved (2 bytes)
            # Format: 8 bytes total = 2 words
            # Word 1: q0, q1, q2, q3 (little-endian)
            # Word 2: q4, q5, reserved byte 1, reserved byte 2
            out.write(struct.pack('<BBBB', *qty_bytes[0:4]))  # First word: q0-q3
            out.write(struct.pack('<BBBB', *qty_bytes[4:6], 0, 0))  # Second word: q4, q5, reserved
    
    print(f"Wrote binary data to {out_path}")
    print(f"  Shapes: {len(shapes)}")
    print(f"  Regions: {len(regions)}")

if __name__ == "__main__":
    main()
