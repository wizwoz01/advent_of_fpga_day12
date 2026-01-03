#!/usr/bin/env python3
"""
bin_to_hex.py

Converts binary file from preprocess_day12.py to hex format for Verilog $readmemh
Each line contains one 32-bit word in hexadecimal format

Usage:
  python3 bin_to_hex.py input.bin output.hex
"""

import sys
import struct

def main():
    if len(sys.argv) != 3:
        print("Usage: bin_to_hex.py input.bin output.hex")
        sys.exit(2)

    in_path = sys.argv[1]
    out_path = sys.argv[2]

    # Read binary file and convert to hex
    with open(in_path, 'rb') as f_in:
        with open(out_path, 'w') as f_out:
            # Read 32-bit words (4 bytes each)
            while True:
                chunk = f_in.read(4)
                if not chunk:
                    break
                
                # Pad if needed (shouldn't happen for proper format)
                if len(chunk) < 4:
                    chunk = chunk + b'\x00' * (4 - len(chunk))
                
                # Unpack as little-endian 32-bit unsigned int
                word = struct.unpack('<I', chunk)[0]
                
                # Write as 8-character hex string (lowercase, no 0x prefix)
                f_out.write(f"{word:08x}\n")
    
    print(f"Converted {in_path} to {out_path}")
    print(f"Format: One 32-bit hex word per line (little-endian)")

if __name__ == "__main__":
    main()

