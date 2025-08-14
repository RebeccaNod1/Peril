pipeline {
    agent any
    
    environment {
        LSL_TOOLS_PATH = '/opt/lsl-tools'
        PROJECT_NAME = 'peril'
        // NOTIFICATION_WEBHOOK = credentials('discord-webhook') // Optional - commented out until configured
    }
    
    triggers {
        githubPush() // Trigger on GitHub push
        pollSCM('H/5 * * * *') // Poll every 5 minutes as fallback
    }
    
    stages {
        stage('Checkout') {
            steps {
                echo "🔍 Checking out LSL project: ${PROJECT_NAME}"
                checkout scm
            }
        }
        
        stage('Clean Workspace') {
            steps {
                echo "🧹 Cleaning up processed files from previous builds..."
                sh '''
                    # Remove any processed files from previous builds
                    rm -f processed_*.lsl
                    echo "Workspace cleaned of processed files"
                '''
            }
        }
        
        stage('LSL Validation') {
            steps {
                echo "🔧 Validating LSL syntax..."
                sh '''
                    python3 ${LSL_TOOLS_PATH}/lsl_validator.py .
                '''
            }
            post {
                failure {
                    echo "❌ LSL validation failed!"
                }
                success {
                    echo "✅ LSL validation passed!"
                }
            }
        }
        
        stage('Preprocess Scripts') {
            when {
                anyOf {
                    environment name: 'GIT_BRANCH', value: 'origin/main'
                    environment name: 'GIT_BRANCH', value: 'origin/develop'
                    environment name: 'GIT_BRANCH', value: 'main'
                    environment name: 'GIT_BRANCH', value: 'develop'
                }
            }
            steps {
                echo "🔄 Preprocessing LSL files..."
                sh '''
                    # Only process original source files, not already-processed ones
                    for file in *.lsl; do
                        if [ -f "$file" ] && [ "${file#processed_}" = "$file" ]; then
                            echo "Processing $file..."
                            python3 ${LSL_TOOLS_PATH}/lsl_preprocessor.py "$file" "processed_$file"
                        fi
                    done
                '''
            }
        }
        
        stage('Generate Release Package') {
            when {
                anyOf {
                    environment name: 'GIT_BRANCH', value: 'origin/main'
                    environment name: 'GIT_BRANCH', value: 'main'
                }
            }
            steps {
                echo "📦 Creating release package..."
                sh '''
                    # Get version from git tag or use build number
                    VERSION=$(git describe --tags --abbrev=0 2>/dev/null || echo "v2.6.${BUILD_NUMBER}")
                    echo "Creating release ${VERSION}"
                    
                    # Create release directory
                    mkdir -p releases/${VERSION}
                    
                    # Copy LSL files
                    cp *.lsl releases/${VERSION}/
                    
                    # Copy documentation
                    cp README.md CHANGELOG.md releases/${VERSION}/ 2>/dev/null || true
                    
                    # Create deployment notes
                    echo "Peril Game ${VERSION}" > releases/${VERSION}/DEPLOYMENT_NOTES.txt
                    echo "Build: ${BUILD_NUMBER}" >> releases/${VERSION}/DEPLOYMENT_NOTES.txt
                    echo "Date: $(date)" >> releases/${VERSION}/DEPLOYMENT_NOTES.txt
                    echo "Commit: ${GIT_COMMIT}" >> releases/${VERSION}/DEPLOYMENT_NOTES.txt
                    
                    # Create zip for easy download
                    cd releases
                    zip -r "${VERSION}.zip" ${VERSION}/
                '''
                
                // Archive the release
                archiveArtifacts artifacts: 'releases/**/*', followSymlinks: false
                
                // Create GitHub release (if using GitHub plugin)
                script {
                    def version = sh(script: "git describe --tags --abbrev=0 2>/dev/null || echo 'v2.6.${BUILD_NUMBER}'", returnStdout: true).trim()
                    echo "Release ${version} created successfully!"
                }
            }
        }
        
        stage('Update Documentation') {
            when {
                anyOf {
                    environment name: 'GIT_BRANCH', value: 'origin/main'
                    environment name: 'GIT_BRANCH', value: 'main'
                }
            }
            steps {
                echo "📚 Updating project documentation..."
                sh '''
                    # Generate function list from original LSL files only
                    echo "# Project Functions" > FUNCTIONS.md
                    echo "" >> FUNCTIONS.md
                    echo "Auto-generated list of functions in this project:" >> FUNCTIONS.md
                    echo "" >> FUNCTIONS.md
                    
                    for file in *.lsl; do
                        if [ -f "$file" ] && [ "${file#processed_}" = "$file" ]; then
                            echo "## $file" >> FUNCTIONS.md
                            echo "" >> FUNCTIONS.md
                            grep -n "^[a-zA-Z_][a-zA-Z0-9_]*(" "$file" | head -20 >> FUNCTIONS.md || true
                            echo "" >> FUNCTIONS.md
                        fi
                    done
                '''
            }
        }
        
        stage('Notify Success') {
            when {
                anyOf {
                    environment name: 'GIT_BRANCH', value: 'origin/main'
                    environment name: 'GIT_BRANCH', value: 'main'
                }
            }
            steps {
                echo "🎉 Build completed successfully!"
                script {
                    // Optional: Send Discord/Slack notification
                    // Only if webhook is configured
                    if (env.NOTIFICATION_WEBHOOK) {
                        sh '''
                            curl -X POST ${NOTIFICATION_WEBHOOK} \
                            -H "Content-Type: application/json" \
                            -d "{\\"content\\": \\"✅ Peril LSL project build #${BUILD_NUMBER} completed successfully! New release ready for deployment.\\"}"
                        '''
                    }
                }
            }
        }
    }
    
    post {
        always {
            echo "🧹 Pipeline completed"
            // cleanWs moved to individual stages if needed
        }
        
        failure {
            echo "💥 Build failed! Check the logs above."
            script {
                if (env.NOTIFICATION_WEBHOOK) {
                    sh '''
                        curl -X POST ${NOTIFICATION_WEBHOOK} \
                        -H "Content-Type: application/json" \
                        -d "{\\"content\\": \\"❌ Peril LSL project build #${BUILD_NUMBER} failed! Check Jenkins for details.\\"}"
                    '''
                }
            }
        }
        
        success {
            echo "🎯 Build completed successfully!"
        }
    }
}
