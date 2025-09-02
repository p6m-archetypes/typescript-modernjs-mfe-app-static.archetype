#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
CONTAINERIZED_PROJECT_NAME="test-modernjs-app"  # project directory name for containerized mode
HOSTED_PROJECT_NAME="test-modernjs-app"  # project directory name for hosted mode
MAX_STARTUP_TIME=120 # 2 minutes in seconds
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMP_DIR="$(mktemp -d)"
VALIDATION_LOG="$TEMP_DIR/validation.log"

# Test mode variables (will be set during execution)
CURRENT_TEST_MODE=""
CURRENT_PROJECT_NAME=""
CURRENT_ANSWERS_FILE=""

# Cleanup function - DISABLED FOR DEBUGGING
cleanup() {
    echo -e "${BLUE}NOT cleaning up for debugging...${NC}"
    echo -e "${YELLOW}Generated project directories in: $TEMP_DIR${NC}"
    
    # Check both test mode subdirectories
    for mode in "containerized" "hosted"; do
        local mode_dir="$TEMP_DIR/$mode-test"
        if [ -d "$mode_dir" ]; then
            echo -e "${YELLOW}  - $mode_dir/${NC}"
            # Check for project within the mode directory
            if [ "$mode" = "containerized" ]; then
                local project_path="$mode_dir/$CONTAINERIZED_PROJECT_NAME"
            else
                local project_path="$mode_dir/$HOSTED_PROJECT_NAME"
            fi
            
            if [ -d "$project_path" ]; then
                echo -e "${YELLOW}    └── $project_path${NC}"
                if [ -f "$project_path/docker-compose.yml" ] || [ -f "$project_path/Dockerfile" ]; then
                    echo -e "${YELLOW}To manually clean up Docker resources later, run:${NC}"
                    echo -e "${YELLOW}cd $project_path && docker-compose down --volumes --remove-orphans 2>/dev/null || true${NC}"
                fi
            fi
        fi
    done
    echo -e "${YELLOW}To remove all generated files: rm -rf $TEMP_DIR${NC}"
    # rm -rf "$TEMP_DIR"  # DISABLED
}

# Trap cleanup on exit
trap cleanup EXIT

# Logging function
log() {
    echo -e "$1" | tee -a "$VALIDATION_LOG"
}

# Success/Failure tracking
TESTS_PASSED=0
TESTS_FAILED=0

test_result() {
    if [ $1 -eq 0 ]; then
        log "${GREEN}✅ $2${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        log "${RED}❌ $2${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
check_prerequisites() {
    log "${BLUE}Checking prerequisites...${NC}"
    
    local missing_deps=()
    
    if ! command_exists archetect; then
        missing_deps+=("archetect")
    fi
    
    if ! command_exists node; then
        missing_deps+=("node")
    fi
    
    if ! command_exists npm; then
        missing_deps+=("npm")
    fi
    
    if ! command_exists docker; then
        missing_deps+=("docker")
    fi
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        log "${RED}Missing required dependencies: ${missing_deps[*]}${NC}"
        log "${YELLOW}Please install the missing dependencies and try again.${NC}"
        log "${YELLOW}Required: archetect, node, npm, docker${NC}"
        exit 1
    fi
    
    # Check Node.js version (should be >= 18)
    local node_version=$(node --version | grep -o '[0-9]\+' | head -1)
    if [ "$node_version" -lt 18 ]; then
        log "${RED}Node.js version $node_version is too old. Please install Node.js 18 or later.${NC}"
        exit 1
    fi
    
    test_result 0 "All prerequisites available (Node.js $node_version)"
}

# Generate test project from archetype
generate_test_project() {
    local mode="$1"  # "containerized" or "hosted"
    log "\n${BLUE}Generating $mode test project from archetype...${NC}"
    
    # We're already in the correct subdirectory, no need to cd
    
    # Set mode-specific variables
    if [ "$mode" = "containerized" ]; then
        CURRENT_TEST_MODE="containerized"
        CURRENT_PROJECT_NAME="$CONTAINERIZED_PROJECT_NAME"
        CURRENT_ANSWERS_FILE="test_answers_containerized.yaml"
    elif [ "$mode" = "hosted" ]; then
        CURRENT_TEST_MODE="hosted"
        CURRENT_PROJECT_NAME="$HOSTED_PROJECT_NAME"
        CURRENT_ANSWERS_FILE="test_answers_hosted.yaml"
    else
        log "${RED}Invalid mode: $mode${NC}"
        return 1
    fi
    
    # Use the appropriate answers file
    if [ -f "$SCRIPT_DIR/$CURRENT_ANSWERS_FILE" ]; then
        cp "$SCRIPT_DIR/$CURRENT_ANSWERS_FILE" "$CURRENT_ANSWERS_FILE"
        log "${GREEN}Using $CURRENT_ANSWERS_FILE for $mode mode${NC}"
    else
        log "${RED}$CURRENT_ANSWERS_FILE not found in $SCRIPT_DIR${NC}"
        return 1
    fi
    
    # Generate the project using render command
    log "${YELLOW}Running: archetect render $SCRIPT_DIR --answer-file $CURRENT_ANSWERS_FILE${NC}"
    if archetect render "$SCRIPT_DIR" --answer-file "$CURRENT_ANSWERS_FILE" >> "$VALIDATION_LOG" 2>&1; then
        test_result 0 "Archetype generation successful ($mode mode)"
    else
        test_result 1 "Archetype generation failed ($mode mode)"
        log "${RED}Check validation log: $VALIDATION_LOG${NC}"
        return 1
    fi
    
    # Verify the generated structure
    if [ -d "$CURRENT_PROJECT_NAME" ]; then
        test_result 0 "Generated project directory exists ($CURRENT_PROJECT_NAME)"
    else
        test_result 1 "Generated project directory missing ($CURRENT_PROJECT_NAME)"
        return 1
    fi
}

# Validate template substitution
validate_template_substitution() {
    log "\n${BLUE}Validating template variable substitution ($CURRENT_TEST_MODE mode)...${NC}"
    
    cd "$CURRENT_PROJECT_NAME"
    
    local substitution_errors=0
    
    # Check for unreplaced template variables
    log "${YELLOW}Checking for unreplaced template variables...${NC}"
    if grep -r "{{ project-" . --exclude-dir=node_modules --exclude-dir=.git 2>/dev/null; then
        log "${RED}Found unreplaced template variables!${NC}"
        substitution_errors=1
    else
        log "${GREEN}No unreplaced template variables found${NC}"
    fi
    
    # Check that project name was substituted correctly
    if [ -f "package.json" ]; then
        if grep -q "\"name\": \"$CURRENT_PROJECT_NAME\"" package.json; then
            log "${GREEN}Project name correctly substituted in package.json${NC}"
        else
            log "${RED}Project name not correctly substituted in package.json${NC}"
            substitution_errors=1
        fi
    else
        log "${RED}package.json not found${NC}"
        substitution_errors=1
    fi
    
    # Check that content exists in pages/page.tsx
    if [ -f "src/pages/page.tsx" ]; then
        if grep -q "Content" src/pages/page.tsx; then
            log "${GREEN}Content component correctly referenced in pages/page.tsx${NC}"
        else
            log "${RED}Content component not correctly referenced in pages/page.tsx${NC}"
            substitution_errors=1
        fi
    else
        log "${RED}src/pages/page.tsx not found${NC}"
        substitution_errors=1
    fi
    
    test_result $substitution_errors "Template variable substitution ($CURRENT_TEST_MODE mode)"
}

# Validate deployment mode specific files
validate_deployment_mode() {
    log "\n${BLUE}Validating $CURRENT_TEST_MODE deployment mode specifics...${NC}"
    
    cd "$CURRENT_PROJECT_NAME"
    
    local mode_errors=0
    
    if [ "$CURRENT_TEST_MODE" = "containerized" ]; then
        # Containerized mode should have Dockerfile
        if [ -f "Dockerfile" ]; then
            if ! grep -q "NOTE: This Dockerfile is not used" Dockerfile; then
                log "${GREEN}Dockerfile exists for containerized deployment${NC}"
            else
                log "${RED}Dockerfile has host repository warning (should not in containerized mode)${NC}"
                mode_errors=1
            fi
        else
            log "${RED}Dockerfile missing for containerized deployment${NC}"
            mode_errors=1
        fi
        
        # Should have docker-related workflow steps
        if [ -f ".github/workflows/build-main.yaml" ]; then
            if grep -q "docker-build:" .github/workflows/build-main.yaml; then
                log "${GREEN}Docker build steps present in workflow${NC}"
            else
                log "${RED}Docker build steps missing from workflow${NC}"
                mode_errors=1
            fi
        fi
        
    elif [ "$CURRENT_TEST_MODE" = "hosted" ]; then
        # Hosted mode should have Dockerfile with warning comment
        if [ -f "Dockerfile" ]; then
            if grep -q "NOTE: This Dockerfile is not used" Dockerfile; then
                log "${GREEN}Dockerfile has appropriate host repository warning${NC}"
            else
                log "${RED}Dockerfile missing host repository warning${NC}"
                mode_errors=1
            fi
        else
            log "${RED}Dockerfile missing (should exist with warning)${NC}"
            mode_errors=1
        fi
        
        # Should have publish steps but not docker steps
        if [ -f ".github/workflows/build-main.yaml" ]; then
            if grep -q "Publish .output" .github/workflows/build-main.yaml; then
                log "${GREEN}Publish steps present in workflow${NC}"
            else
                log "${RED}Publish steps missing from workflow${NC}"
                mode_errors=1
            fi
            
            if ! grep -q "docker-build:" .github/workflows/build-main.yaml; then
                log "${GREEN}Docker build steps correctly excluded from workflow${NC}"
            else
                log "${RED}Docker build steps should not be present in hosted mode${NC}"
                mode_errors=1
            fi
        fi
        
        # Should not have port configuration
        if [ -f "modern.config.ts" ]; then
            if ! grep -q "dev.port" modern.config.ts; then
                log "${GREEN}Port configuration correctly excluded in hosted mode${NC}"
            else
                log "${RED}Port configuration should not be present in hosted mode${NC}"
                mode_errors=1
            fi
        fi
    fi
    
    test_result $mode_errors "Deployment mode validation ($CURRENT_TEST_MODE)"
}

# Validate project structure
validate_project_structure() {
    log "\n${BLUE}Validating project structure ($CURRENT_TEST_MODE mode)...${NC}"
    
    cd "$CURRENT_PROJECT_NAME"
    
    local structure_errors=0
    
    # Check essential files
    local required_files=(
        "package.json"
        "modern.config.ts"
        "tsconfig.json"
        "Dockerfile"
        "src/App.tsx"
        "src/pages/page.tsx"
    )
    
    for file in "${required_files[@]}"; do
        if [ -f "$file" ]; then
            log "${GREEN}  ✅ $file exists${NC}"
        else
            log "${RED}  ❌ $file missing${NC}"
            structure_errors=1
        fi
    done
    
    # Check essential directories
    local required_dirs=(
        "src"
        "src/pages"
        "src/components"
    )
    
    for dir in "${required_dirs[@]}"; do
        if [ -d "$dir" ]; then
            log "${GREEN}  ✅ $dir/ exists${NC}"
        else
            log "${RED}  ❌ $dir/ missing${NC}"
            structure_errors=1
        fi
    done
    
    # Check that old Next.js files are NOT present
    local forbidden_files=(
        "next.config.js"
        "open-next.config.js"
    )
    
    for file in "${forbidden_files[@]}"; do
        if [ -e "$file" ]; then
            log "${RED}  ❌ Found legacy file/directory: $file${NC}"
            structure_errors=1
        else
            log "${GREEN}  ✅ No legacy $file found${NC}"
        fi
    done
    
    test_result $structure_errors "Project structure validation"
}

# Test dependency installation
test_dependency_installation() {
    log "\n${BLUE}Testing dependency installation...${NC}"
    
    cd "$CURRENT_PROJECT_NAME"
    
    log "${YELLOW}Running: npm install${NC}"
    if npm install >> "$VALIDATION_LOG" 2>&1; then
        test_result 0 "Dependencies installed successfully"
    else
        test_result 1 "Dependency installation failed"
        return 1
    fi
    
    # Check for Modern.js specific dependencies
    if [ -f "node_modules/@modern-js/app-tools/package.json" ]; then
        test_result 0 "Modern.js app-tools installed"
    else
        test_result 1 "Modern.js app-tools not found"
    fi
    
    if [ -f "node_modules/@modern-js/runtime/package.json" ]; then
        test_result 0 "Modern.js runtime installed"
    else
        test_result 1 "Modern.js runtime not found"
    fi
}

# Test linting - DISABLED to focus on core functionality
# test_linting() {
#     log "\n${BLUE}Testing Biome configuration...${NC}"
#     
#     cd "$TEMP_DIR/$TEST_PROJECT_NAME"
#     
#     log "${YELLOW}Running: npm run lint${NC}"
#     if npm run lint >> "$VALIDATION_LOG" 2>&1; then
#         test_result 0 "Biome passed"
#     else
#         test_result 1 "Biome failed"
#         return 1
#     fi
# }

# Test project build
test_project_build() {
    log "\n${BLUE}Testing project build...${NC}"
    
    cd "$CURRENT_PROJECT_NAME"
    
    local build_start_time=$(date +%s)
    
    log "${YELLOW}Running: npm run build${NC}"
    if npm run build >> "$VALIDATION_LOG" 2>&1; then
        local build_end_time=$(date +%s)
        local build_time=$((build_end_time - build_start_time))
        test_result 0 "Project build successful ($build_time seconds)"
        
        # Check build output
        if [ -d "dist" ]; then
            test_result 0 "Build output directory (dist) created"
        else
            test_result 1 "Build output directory (dist) not found"
        fi
    else
        test_result 1 "Project build failed"
        return 1
    fi
}



# Test Docker build
test_docker_build() {
    log "\n${BLUE}Testing Docker build...${NC}"
    
    cd "$CURRENT_PROJECT_NAME"
    
    local docker_start_time=$(date +%s)
    
    log "${YELLOW}Running: docker build -t $TEST_PROJECT_NAME .${NC}"
    if docker build -t "$TEST_PROJECT_NAME" . >> "$VALIDATION_LOG" 2>&1; then
        local docker_end_time=$(date +%s)
        local docker_time=$((docker_end_time - docker_start_time))
        test_result 0 "Docker build successful ($docker_time seconds)"
        
        # Clean up any existing container with the same name first
        docker stop "${TEST_PROJECT_NAME}-test" 2>/dev/null || true
        docker rm "${TEST_PROJECT_NAME}-test" 2>/dev/null || true
        
        # Test running the container
        log "${YELLOW}Testing Docker container startup...${NC}"
        if docker run -d --name "${TEST_PROJECT_NAME}-test" -p 3000:80 "$TEST_PROJECT_NAME" >> "$VALIDATION_LOG" 2>&1; then
            
            # Wait for container to be ready
            local max_wait=30
            local waited=0
            
            while [ $waited -lt $max_wait ]; do
                if curl -s --connect-timeout 5 --max-time 5 http://localhost:3000 >/dev/null 2>&1; then
                    test_result 0 "Docker container started and accessible"
                    break
                fi
                sleep 2
                waited=$((waited + 2))
            done
            
            if [ $waited -lt $max_wait ]; then
                # Test container homepage content
                log "${YELLOW}Validating Docker container homepage content...${NC}"
                local container_content=$(curl -s --connect-timeout 5 --max-time 10 http://localhost:3000 2>/dev/null)
                local container_errors=0
                
                # Check for expected content in container
                if echo "$container_content" | grep -q -i "modern\|application\|test" || echo "$container_content" | grep -q "<title>"; then
                    test_result 0 "Docker container homepage contains expected content"
                else
                    test_result 1 "Docker container homepage missing expected content"
                    container_errors=1
                fi
                
                if [ ${#container_content} -gt 100 ]; then
                    test_result 0 "Docker container homepage has substantial content (${#container_content} characters)"
                else
                    test_result 1 "Docker container homepage content too minimal (${#container_content} characters)"
                    container_errors=1
                fi
                
                docker stop "${TEST_PROJECT_NAME}-test" >> "$VALIDATION_LOG" 2>&1
                docker rm "${TEST_PROJECT_NAME}-test" >> "$VALIDATION_LOG" 2>&1
                
                if [ $container_errors -eq 0 ]; then
                    return 0
                else
                    return 1
                fi
            else
                test_result 1 "Docker container not accessible"
                docker stop "${TEST_PROJECT_NAME}-test" >> "$VALIDATION_LOG" 2>&1 || true
                docker rm "${TEST_PROJECT_NAME}-test" >> "$VALIDATION_LOG" 2>&1 || true
                return 1
            fi
        else
            test_result 1 "Docker container failed to start"
        fi
    else
        test_result 1 "Docker build failed"
        return 1
    fi
}

# Run validation for a single mode
run_single_mode_validation() {
    local mode="$1"
    local generate_only="$2"
    
    log "\n${BLUE}========================================${NC}"
    log "${BLUE}Testing $mode deployment mode${NC}"
    log "${BLUE}========================================${NC}"
    
    # Create a subdirectory for this mode to avoid conflicts
    mkdir -p "$TEMP_DIR/$mode-test"
    cd "$TEMP_DIR/$mode-test"
    
    # Generate and validate the project
    generate_test_project "$mode" || return 1
    validate_template_substitution || return 1
    validate_deployment_mode || return 1
    validate_project_structure || return 1
    
    # Check if we should stop after generation for debugging
    if [ "$generate_only" = "true" ]; then
        log "\n${YELLOW}Stopping after generation as requested for $mode mode${NC}"
        return 0
    fi
    
    log "\n${BLUE}Starting comprehensive testing for $mode mode...${NC}"
    
    # Update the remaining test functions to use CURRENT_PROJECT_NAME
    cd "$CURRENT_PROJECT_NAME"
    
    # Run dependency installation
    log "${YELLOW}Running: npm install${NC}"
    if npm install >> "$VALIDATION_LOG" 2>&1; then
        test_result 0 "Dependencies installed successfully ($mode mode)"
    else
        test_result 1 "Dependency installation failed ($mode mode)"
        return 1
    fi
    
    # Run build test
    log "${YELLOW}Running: npm run build${NC}"
    if npm run build >> "$VALIDATION_LOG" 2>&1; then
        test_result 0 "Project build successful ($mode mode)"
        if [ -d "dist" ]; then
            test_result 0 "Build output directory (dist) created ($mode mode)"
        else
            test_result 1 "Build output directory (dist) not found ($mode mode)"
        fi
    else
        test_result 1 "Project build failed ($mode mode)"
        return 1
    fi
    
    # Only run Docker test for containerized mode
    if [ "$mode" = "containerized" ]; then
        log "${YELLOW}Running: docker build -t $CURRENT_PROJECT_NAME .${NC}"
        if docker build -t "$CURRENT_PROJECT_NAME" . >> "$VALIDATION_LOG" 2>&1; then
            test_result 0 "Docker build successful ($mode mode)"
            
            # Clean up any existing container with the same name first
            docker stop "${CURRENT_PROJECT_NAME}-test" 2>/dev/null || true
            docker rm "${CURRENT_PROJECT_NAME}-test" 2>/dev/null || true
            
            # Test running the container
            if docker run -d --name "${CURRENT_PROJECT_NAME}-test" -p 3000:80 "$CURRENT_PROJECT_NAME" >> "$VALIDATION_LOG" 2>&1; then
                # Wait for container to be ready
                local max_wait=30
                local waited=0
                
                while [ $waited -lt $max_wait ]; do
                    if curl -s --connect-timeout 5 --max-time 5 http://localhost:3000 >/dev/null 2>&1; then
                        test_result 0 "Docker container started and accessible ($mode mode)"
                        break
                    fi
                    sleep 2
                    waited=$((waited + 2))
                done
                
                docker stop "${CURRENT_PROJECT_NAME}-test" >> "$VALIDATION_LOG" 2>&1 || true
                docker rm "${CURRENT_PROJECT_NAME}-test" >> "$VALIDATION_LOG" 2>&1 || true
            else
                test_result 1 "Docker container failed to start ($mode mode)"
            fi
        else
            test_result 1 "Docker build failed ($mode mode)"
        fi
    else
        log "${YELLOW}Skipping Docker test for hosted mode${NC}"
    fi
    
    return 0
}

# Main validation workflow
main() {
    log "${BLUE}==============================================${NC}"
    log "${BLUE}Modern.js Archetype Dual-Mode Validation${NC}"
    log "${BLUE}==============================================${NC}"
    log "Validation log: $VALIDATION_LOG"
    log "Temp directory: $TEMP_DIR"
    
    local overall_start_time=$(date +%s)
    local generate_only="false"
    
    # Check if we should stop after generation for debugging
    if [ "$1" = "--generate-only" ]; then
        generate_only="true"
    fi
    
    # Run prerequisites check once
    check_prerequisites || exit 1
    
    # Test both deployment modes
    log "\n${BLUE}Testing both containerized and hosted deployment modes...${NC}"
    
    # Test containerized mode
    run_single_mode_validation "containerized" "$generate_only" || exit 1
    
    # Test hosted mode  
    run_single_mode_validation "hosted" "$generate_only" || exit 1
    
    if [ "$generate_only" = "true" ]; then
        log "\n${YELLOW}Stopping after generation as requested.${NC}"
        log "${YELLOW}Projects generated at:${NC}"
        log "${YELLOW}  - Containerized: $TEMP_DIR/containerized-test/$CONTAINERIZED_PROJECT_NAME${NC}"
        log "${YELLOW}  - Hosted: $TEMP_DIR/hosted-test/$HOSTED_PROJECT_NAME${NC}"
        return 0
    fi
    
    local overall_end_time=$(date +%s)
    local total_time=$((overall_end_time - overall_start_time))
    
    # Final summary
    log "\n${BLUE}==============================================${NC}"
    log "${BLUE}Dual-Mode Validation Summary${NC}"
    log "${BLUE}==============================================${NC}"
    log "Total tests: $((TESTS_PASSED + TESTS_FAILED))"
    log "${GREEN}Passed: $TESTS_PASSED${NC}"
    log "${RED}Failed: $TESTS_FAILED${NC}"
    log "Total validation time: $total_time seconds"
    
    if [ $TESTS_FAILED -eq 0 ]; then
        log "\n${GREEN}🎉 ALL DUAL-MODE VALIDATION TESTS PASSED! ARCHETYPE IS BOSS-LEVEL READY! 🚀${NC}"
        log "${YELLOW}Generated projects preserved at:${NC}"
        log "${YELLOW}  - Containerized: $TEMP_DIR/containerized-test/$CONTAINERIZED_PROJECT_NAME${NC}"
        log "${YELLOW}  - Hosted: $TEMP_DIR/hosted-test/$HOSTED_PROJECT_NAME${NC}"
        return 0
    else
        log "\n${RED}❌ Validation failed. Please check the issues above.${NC}"
        log "${YELLOW}Validation log available at: $VALIDATION_LOG${NC}"
        log "${YELLOW}Generated projects preserved at:${NC}"
        log "${YELLOW}  - Containerized: $TEMP_DIR/containerized-test/$CONTAINERIZED_PROJECT_NAME${NC}"
        log "${YELLOW}  - Hosted: $TEMP_DIR/hosted-test/$HOSTED_PROJECT_NAME${NC}"
        return 1
    fi
}

# Run main function
main "$@"