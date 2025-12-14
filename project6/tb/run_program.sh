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
#   --compare         : Compare output with reference dumps in ../reference/
#   --save-output     : Save outputs to ../output/ directory
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
COMPARE_OUTPUT=false
SAVE_OUTPUT=false
REFERENCE_DIR="../reference"
OUTPUT_DIR="../output"

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
        --compare)
            COMPARE_OUTPUT=true
            shift
            ;;
        --save-output)
            SAVE_OUTPUT=true
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
            echo -e "${BLUE}       ./run_program.sh --compare   ${NC}${GREEN}# Compare with reference${NC}"
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
            echo "  --compare         : Compare output with reference dumps"
            echo "  --save-output     : Save outputs to ../output/ directory"
            echo "  --list, -l        : List all available programs"
            echo "  --help, -h        : Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0                       # Run all programs"
            echo "  $0 01add                 # Run single program"
            echo "  $0 --compare             # Run all and compare with reference"
            echo "  $0 01add --compare       # Run one and compare"
            echo "  $0 --stop-on-error       # Run all, stop on first error"
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

# Function to compare outputs
compare_output() {
    local prog_name=$1
    local output_file=$2
    local base_name="${prog_name%.mem}"
    local ref_file="${REFERENCE_DIR}/${base_name}.txt"
    
    if [ ! -f "$ref_file" ]; then
        echo -e "${YELLOW}⚠ No reference file found: $ref_file${NC}"
        return 2
    fi
    
    # Extract only the trace lines (skip header/footer)
    grep "^\[" "$output_file" > /tmp/student_trace.txt 2>/dev/null
    grep "^\[" "$ref_file" > /tmp/reference_trace.txt 2>/dev/null
    
    if diff -q /tmp/student_trace.txt /tmp/reference_trace.txt > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Output matches reference!${NC}"
        return 0
    else
        echo -e "${RED}✗ Output differs from reference${NC}"
        echo -e "${YELLOW}Showing first difference:${NC}"
        diff -u /tmp/reference_trace.txt /tmp/student_trace.txt | head -20
        echo ""
        echo -e "${YELLOW}Full diff saved to: diff_${base_name}.txt${NC}"
        diff -u /tmp/reference_trace.txt /tmp/student_trace.txt > "diff_${base_name}.txt"
        return 1
    fi
}

# Create output directory if saving
if [ "$SAVE_OUTPUT" = true ]; then
    mkdir -p "$OUTPUT_DIR"
fi

# If no program specified, run all programs
if [ -z "$PROGRAM_NAME" ]; then
    RUN_ALL=true
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║  Running ALL programs in ../programs/                     ║${NC}"
    if [ "$COMPARE_OUTPUT" = true ]; then
        echo -e "${CYAN}║  Comparing with reference dumps                           ║${NC}"
    fi
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
    MATCH=0
    MISMATCH=0
    NO_REF=0
    COUNT=0
    
    for PROG_PATH in "${PROGRAMS[@]}"; do
        COUNT=$((COUNT + 1))
        PROG_NAME=$(basename "$PROG_PATH")
        BASE_NAME="${PROG_NAME%.mem}"
        
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
            OUTPUT_FILE="/tmp/output_${BASE_NAME}.txt"
            vvp simv_student > "$OUTPUT_FILE" 2>&1
            EXIT_CODE=${PIPESTATUS[0]}
            
            # Show last 20 lines
            tail -n 20 "$OUTPUT_FILE"
            
            if [ $EXIT_CODE -eq 0 ]; then
                echo -e "${GREEN}✓ $PROG_NAME completed successfully${NC}"
                PASSED=$((PASSED + 1))
                
                # Compare if requested
                if [ "$COMPARE_OUTPUT" = true ]; then
                    compare_output "$PROG_NAME" "$OUTPUT_FILE"
                    COMPARE_RESULT=$?
                    if [ $COMPARE_RESULT -eq 0 ]; then
                        MATCH=$((MATCH + 1))
                    elif [ $COMPARE_RESULT -eq 1 ]; then
                        MISMATCH=$((MISMATCH + 1))
                    else
                        NO_REF=$((NO_REF + 1))
                    fi
                fi
                
                # Save output if requested
                if [ "$SAVE_OUTPUT" = true ]; then
                    cp "$OUTPUT_FILE" "${OUTPUT_DIR}/${BASE_NAME}.txt"
                fi
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
    
    if [ "$COMPARE_OUTPUT" = true ]; then
        echo -e "${CYAN}╠════════════════════════════════════════════════════════════╣${NC}"
        echo -e "${CYAN}║  COMPARISON RESULTS                                        ║${NC}"
        echo -e "${CYAN}╠════════════════════════════════════════════════════════════╣${NC}"
        echo -e "${GREEN}║${NC}  Matching: $MATCH"
        if [ $MISMATCH -gt 0 ]; then
            echo -e "${RED}║${NC}  Mismatched: $MISMATCH"
        else
            echo -e "${CYAN}║${NC}  Mismatched: $MISMATCH"
        fi
        if [ $NO_REF -gt 0 ]; then
            echo -e "${YELLOW}║${NC}  No reference: $NO_REF"
        fi
    fi
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
    
    if [ $FAILED -gt 0 ] || [ $MISMATCH -gt 0 ]; then
        exit 1
    fi
    exit 0
fi

# Single program mode
echo -e "${CYAN}Running single program: $PROGRAM_NAME${NC}"
if [ "$COMPARE_OUTPUT" = true ]; then
    echo -e "${CYAN}Will compare with reference${NC}"
fi
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

BASE_NAME="${PROGRAM_NAME%.mem}"

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
    
    OUTPUT_FILE="/tmp/output_${BASE_NAME}.txt"
    vvp simv_student | tee "$OUTPUT_FILE"
    EXIT_CODE=${PIPESTATUS[0]}
    
    echo -e "${YELLOW}========================================${NC}"
    if [ $EXIT_CODE -eq 0 ]; then
        echo -e "${GREEN}✓ Simulation completed${NC}"
        
        # Compare if requested
        if [ "$COMPARE_OUTPUT" = true ]; then
            echo ""
            compare_output "$PROGRAM_NAME" "$OUTPUT_FILE"
            COMPARE_RESULT=$?
            if [ $COMPARE_RESULT -eq 1 ]; then
                EXIT_CODE=1
            fi
        fi
        
        # Save output if requested
        if [ "$SAVE_OUTPUT" = true ]; then
            mkdir -p "$OUTPUT_DIR"
            cp "$OUTPUT_FILE" "${OUTPUT_DIR}/${BASE_NAME}.txt"
            echo -e "${GREEN}✓ Output saved to ${OUTPUT_DIR}/${BASE_NAME}.txt${NC}"
        fi
    else
        echo -e "${RED}✗ Simulation failed${NC}"
        exit 1
    fi
fi

if [ $EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}Done!${NC}"
else
    exit 1
fi