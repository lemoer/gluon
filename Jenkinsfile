pipeline {
    agent any
    environment {
        GLUON_SITEDIR = "contrib/ci/minimal-site"
        GLUON_TARGET = "x86-generic"
        BUILD_LOG = "1"
    }
    stages {
        stage('build') {
            steps {
                sh 'ls -la'
                sh 'make update'
                sh 'make'
            }
        }
    }
}
