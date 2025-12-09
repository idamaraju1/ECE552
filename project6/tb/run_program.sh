#!/bin/bash

# Script to copy a program from ../programs/ and run the simulation
# Usage: ./run_program.sh [program_name] [options]
# 
# If no program is specified, all programs will be run sequentially
#
# Options:
#   --no-compile      : Skip compilation step (compile once at start for all programs)
#   --copy-only       : Only copy the program, don't compile or run
#   --stop-on-error   : Stop iteration if any program fails
#   --list            : List all available programs and exit
#   --help, -h        : Show this help message

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default options
COMPILE=true
RUN=true
STOP_ON_ERROR=false
RUN_ALL=false
PROGRAM_NAME=""

# Parse arguments
while [ $# -gt 0 ]; do
    case $1 in
        --no-compile)
            COMPILE=false
            shift
            ;;
        --copy-only)
            COMPILE=false
            RUN=false
            shift
            ;;
        --stop-on-error)
            STOP_ON_ERROR=true
            shift
            ;;
        --list|-l)
            echo -e "${CYAN}Available programs in ../programs/:${NC}"
            echo -e "${CYAN}═══════════════════════════════════════${NC}"
            ls -1 ../programs/*.mem 2>/dev/null | while read -r prog; do
                basename "$prog"
            done | nl -w2 -s'. '
            echo ""
            echo -e "${BLUE}Usage: ./run_program.sh [program_name] [options]${NC}"
            echo -e "${BLUE}       ./run_program.sh              ${NC}${GREEN}# Run all programs${NC}"
            echo -e "${BLUE}       ./run_program.sh 01add       ${NC}${GREEN}# Run single program${NC}"
            echo -e "${BLUE}       ./run_program.sh --list      ${NC}${GREEN}# Show this list${NC}"
            exit 0
            ;;
        --help|-h)
            echo "Usage: $0 [program_name] [options]"
            echo ""
            echo "If no program is specified, all programs will be run sequentially."
            echo ""
            echo "Options:"
            echo "  --no-compile      : Skip compilation step"
            echo "  --copy-only       : Only copy the program, don't compile or run"
            echo "  --stop-on-error   : Stop iteration if any program fails"
            echo "  --list, -l        : List all available programs"
            echo "  --help, -h        : Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0                  # Run all programs"
            echo "  $0 01add            # Run single program"
            echo "  $0 --list           # List all programs"
            echo "  $0 --stop-on-error  # Run all, stop on first error"
            exit 0
            ;;
        -*)
            echo -e "${RED}Unknown option: $1${NC}"
            echo "Use --help for usage information"
            exit 1
            ;;
        *)
            PROGRAM_NAME=$1
            shift
            ;;
    esac
done

# If no program specified, run all programs
if [ -z "$PROGRAM_NAME" ]; then
    RUN_ALL=true
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║  Running ALL programs in ../programs/                     ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Compile once at the beginning
    if [ "$COMPILE" = true ]; then
        echo -e "${BLUE}Compiling testbench (one-time)...${NC}"
        iverilog -o simv_student ../rtl/*.v tb.v tb_memory.v
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ Compilation successful${NC}"
            echo ""
        else
            echo -e "${RED}✗ Compilation failed${NC}"
            exit 1
        fi
    fi
    
    # Get list of programs
    PROGRAMS=(../programs/*.mem)
    TOTAL=${#PROGRAMS[@]}
    PASSED=0
    FAILED=0
    COUNT=0
    
    for PROG_PATH in "${PROGRAMS[@]}"; do
        COUNT=$((COUNT + 1))
        PROG_NAME=$(basename "$PROG_PATH")
        
        echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${MAGENTA}[$COUNT/$TOTAL] Running: $PROG_NAME${NC}"
        echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        
        # Copy the program
        cp "$PROG_PATH" program.mem
        if [ $? -ne 0 ]; then
            echo -e "${RED}✗ Failed to copy $PROG_NAME${NC}"
            FAILED=$((FAILED + 1))
            if [ "$STOP_ON_ERROR" = true ]; then
                exit 1
            fi
            echo ""
            continue
        fi
        
        # Run if requested
        if [ "$RUN" = true ]; then
            vvp simv_student 2>&1 | tail -n 20
            if [ ${PIPESTATUS[0]} -eq 0 ]; then
                echo -e "${GREEN}✓ $PROG_NAME completed successfully${NC}"
                PASSED=$((PASSED + 1))
            else
                echo -e "${RED}✗ $PROG_NAME failed${NC}"
                FAILED=$((FAILED + 1))
                if [ "$STOP_ON_ERROR" = true ]; then
                    exit 1
                fi
            fi
        fi
        echo ""
    done
    
    # Summary
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║  SUMMARY                                                   ║${NC}"
    echo -e "${CYAN}╠════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC}  Total programs: $TOTAL"
    echo -e "${GREEN}║${NC}  Passed: $PASSED"
    if [ $FAILED -gt 0 ]; then
        echo -e "${RED}║${NC}  Failed: $FAILED"
    else
        echo -e "${CYAN}║${NC}  Failed: $FAILED"
    fi
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
    
    if [ $FAILED -gt 0 ]; then
        exit 1
    fi
    exit 0
fi

# Single program mode
echo -e "${CYAN}Running single program: $PROGRAM_NAME${NC}"
echo ""

# Add .mem extension if not present
if [[ ! "$PROGRAM_NAME" == *.mem ]]; then
    PROGRAM_NAME="${PROGRAM_NAME}.mem"
fi

# Check if program exists
PROGRAM_PATH="../programs/${PROGRAM_NAME}"
if [ ! -f "$PROGRAM_PATH" ]; then
    echo -e "${RED}Error: Program '$PROGRAM_NAME' not found in ../programs/${NC}"
    echo ""
    echo "Available programs:"
    ls -1 ../programs/ | sed 's/^/  /'
    echo ""
    echo "Use --list to see all available programs"
    exit 1
fi

# Copy the program
echo -e "${BLUE}Copying $PROGRAM_NAME to program.mem...${NC}"
cp "$PROGRAM_PATH" program.mem
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Program copied successfully${NC}"
else
    echo -e "${RED}✗ Failed to copy program${NC}"
    exit 1
fi

# Compile if requested
if [ "$COMPILE" = true ]; then
    echo -e "${BLUE}Compiling...${NC}"
    iverilog -o simv_student ../rtl/*.v tb.v tb_memory.v
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Compilation successful${NC}"
    else
        echo -e "${RED}✗ Compilation failed${NC}"
        exit 1
    fi
fi

# Run if requested
if [ "$RUN" = true ]; then
    echo -e "${BLUE}Running simulation with $PROGRAM_NAME...${NC}"
    echo -e "${YELLOW}========================================${NC}"
    vvp simv_student
    EXIT_CODE=$?
    echo -e "${YELLOW}========================================${NC}"
    if [ $EXIT_CODE -eq 0 ]; then
        echo -e "${GREEN}✓ Simulation completed${NC}"
    else
        echo -e "${RED}✗ Simulation failed${NC}"
        exit 1
    fi
fi

echo -e "${GREEN}Done!${NC}"

