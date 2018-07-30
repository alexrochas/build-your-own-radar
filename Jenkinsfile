properties([parameters([string(defaultValue: '1', description: 'Número do build para atualizar os parametros.', name: 'buildRefresh'), string(defaultValue: 'governanca.ti@agibank.com.br', description: 'Email GMUD', name: 'email'), string(defaultValue: '1', description: '', name: 'replicas'), booleanParam(defaultValue: false, description: '', name: 'ssl')]), pipelineTriggers([])])

node {
    if (params.buildRefresh == BUILD_NUMBER) {
        stage('Refreshing parameters') {
        }
    } else {
        def envType,appName, gitUrl, applicationPort, namespace, tag, cluster, access

        try {
			stage('Evaluating env') {
					if (env.BRANCH_NAME == 'master') envType = 'prd'
					else if (env.BRANCH_NAME != 'qa' && env.BRANCH_NAME != 'hlg') envType = 'dev'
					else envType = env.BRANCH_NAME

					appName = "cartoes-tech-radar"
					gitUrl = "agiplan-gitlab.bancoagiplan.com.br/core/cartoes/tech-radar.git"
					applicationPort = 8080
					namespace = "cartoes"
					tag = "$envType-$BUILD_NUMBER"
					cluster = "k8s.\"${envType}\".bancoagiplan.com.br"
					access = "internal"
			}

            stage('Checking') {
                echo 'Checking Branch Build: ' +env.BRANCH_NAME
                checkout scm
            }

            stage('Building') {
                sh "docker build --build-arg KETTLE_ENVIRONMENT=$envType -t agiplan/$appName:$tag ."
            }

            stage('Tagging') {
                sh "docker tag agiplan/$appName:$tag agiplan/$appName:$envType-latest"
            }

			stage('Pushing') {
				sh "docker push agiplan/$appName:$tag"
				sh "docker push agiplan/$appName:$envType-latest"
			}

			stage('Deploying') {
				sh "kubectl --context=$cluster create deployment $appName --image=agiplan/$appName:$tag -n $namespace | true"
				sh "kubectl --context=$cluster scale deployment/$appName --replicas=$params.replicas -n $namespace"
				sh "kubectl --context=$cluster set image deployment/$appName $appName=agiplan/$appName:$tag --all -n $namespace"
			}

			stage('Exposing') {
				sh "if [[ `kubectl --context=$cluster get svc $appName -n $namespace | grep $appName | wc -l` -eq 0 ]]; then echo true > result; else echo false > result; fi"
				def result = readFile 'result'
				if (result.trim().equals("true")) {
					svcCreation(appName, cluster, namespace, access, applicationPort, params.ssl)
					endpoint(appName, cluster, namespace, envType, params.ssl)
				} else {
					endpoint(appName, cluster, namespace, envType, params.ssl)
				}
			}

        } catch (err) {
            currentBuild.result = "FAILURE"

            if (envType == 'prd') {
                stage('Sending Failure Email') {
                    def body = "Erro no Release de Produção ${env.BUILD_URL}"
                    sendReleaseEmail(params.email, namespace, env.JOB_NAME, env.BUILD_NUMBER, body.toString())
                }
            }

            throw err
        }
    }
}

def sendReleaseEmail(email, namespace, jobName, buildNumber, body) {
    mail(to: email,
            subject: "Release Produção $namespace $jobName ($buildNumber)",
            body: body)
}

def svcCreation(appName, cluster, namespace, access, applicationPort, ssl) {
    if (ssl) {
        sh "cp /var/lib/jenkins/svc-ssl_default.txt $appName-svc-ssl.txt"
        sh "kubectl --context=$cluster expose deployment $appName --type=LoadBalancer  --target-port=$applicationPort --port=80 --dry-run=true -o yaml -n $namespace > $appName-svc-ssl.yaml"
        sh "sed -e 's/APPNAME/$appName/' -e 's/ACCESS/$access/' -e 's/APPPORT/$applicationPort/' $appName-svc-ssl.txt > $appName-svc-ssl.yaml"
        sh "kubectl --context=$cluster create -f $appName-svc-ssl.yaml -n $namespace && sleep 15"
    } else {
        sh " kubectl --context=$cluster expose deployment $appName --type=LoadBalancer  --target-port=$applicationPort --port=80 --dry-run=true -o yaml -n $namespace > $appName-svc.yaml"
        sh "sed -i \"s/.*metadata:.*/&\\n  annotations: \\n    service.beta.kubernetes.io\\/aws-load-balancer-$access: 0.0.0.0\\/0/\" $appName-svc.yaml"
        sh "kubectl --context=$cluster create -f $appName-svc.yaml -n $namespace && sleep 15"
    }
}

def endpoint(appName, cluster, namespace, envType, ssl) {
    sh "cp /var/lib/jenkins/route53_default.txt $appName-svc-route53.txt"
    sh "sed -e 's/APPNAME/$appName/' -e 's/ENV/$envType/' -e s/VALUE/\$(kubectl --context=$cluster describe svc $appName -n $namespace | grep \"LoadBalancer Ingress\" | awk '{print \$3}')/ -e 's/$envType/\\L&/g' $appName-svc-route53.txt > $appName-svc-route53.json"
    sh "aws route53 change-resource-record-sets --hosted-zone-id Z2L3QNNPNCQRWL --change-batch file://$appName-svc-route53.json > /dev/null"

    if (ssl) {
        sh "set +x && echo \"URL ELB: https://`kubectl --context=$cluster describe svc $appName -n $namespace | grep \"LoadBalancer Ingress\" | awk '{print \$3}'`\""
        sh "set +x && echo \"URL DNS: https://\"$appName\".k8s.\"$envType\".bancoagiplan.com.br \""
    } else {
        sh "set +x && echo \"URL ELB: http://`kubectl --context=$cluster describe svc $appName -n $namespace | grep \"LoadBalancer Ingress\" | awk '{print \$3}'`\""
        sh "set +x && echo \"URL DNS: http://\"$appName\".k8s.\"$envType\".bancoagiplan.com.br \""
    }
}
