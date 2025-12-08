#!/bin/bash

# Script to list all available programs

echo "Available programs in ../programs/:"
echo "======================================"
ls -1 ../programs/ | nl -w2 -s'. '
echo ""
echo "Usage: ./run_program.sh <program_name>"

